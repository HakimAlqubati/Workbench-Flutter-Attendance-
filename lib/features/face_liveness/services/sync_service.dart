import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:my_app/core/database/sync_database.dart';
import 'package:my_app/features/face_liveness/services/network_service.dart';
import 'package:my_app/features/attendance/attendance_service.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  final LivenessNetworkService _networkService = LivenessNetworkService();
  bool _isSyncing = false;

  SyncService._init();

  /// تحفظ الصورة محلياً في مجلد المستندات وتضيف طلباً إلى قاعدة البيانات
  Future<void> enqueueRequest(String originalImagePath, {String? payload}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory(p.join(appDir.path, 'offline_requests'));
      if (!await offlineDir.exists()) {
        await offlineDir.create(recursive: true);
      }

      final fileName = 'face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImagePath = p.join(offlineDir.path, fileName);

      // نسخ الصورة إلى المجلد الدائم
      await File(originalImagePath).copy(savedImagePath);

      // حفظ الاسم فقط (Relative Path) كما طلب المستخدم
      await SyncDatabase.instance.insertRequest(fileName, payload: payload);
      debugPrint('✅ Offline request enqueued: $fileName');
    } catch (e) {
      debugPrint('❌ Failed to enqueue request: $e');
    }
  }

  /// محاولة مزامنة جميع الطلبات المعلقة
  Future<void> syncPendingRequests() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pendingRequests = await SyncDatabase.instance.getPendingRequests();
      if (pendingRequests.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('🔄 Found ${pendingRequests.length} pending offline requests.');

      final appDir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory(p.join(appDir.path, 'offline_requests'));

      for (var request in pendingRequests) {
        final id = request['id'] as int;
        final fileName = request['image_filename'] as String;
        // final payload = request['payload'] as String?;

        final fullImagePath = p.join(offlineDir.path, fileName);
        final file = File(fullImagePath);

        if (!await file.exists()) {
          // إذا اختفت الصورة لأي سبب، نحذف الطلب لتجنب تكرار الفشل
          await SyncDatabase.instance.deleteRequest(id);
          continue;
        }

        try {
          // رفع الصورة. سيتم رمي Exception إذا انقطع الاتصال أو انتهت المهلة
          final response = await _networkService.sendFaceRecognition(fullImagePath);
          debugPrint('🔄 Sync service response for ID $id: $response');

          // إذا وصل الرد بنجاح (سواء كانت النتيجة نجاح أو فشل منطقي من الباكيند)، نحذف الطلب
          if (response != null) {
            
            // محاولة استخراج employee_id كما يحدث في Controller
            dynamic getVal(Map m, List path) {
              dynamic cur = m;
              for (final k in path) {
                if (cur is Map && cur.containsKey(k)) cur = cur[k];
                else return null;
              }
              return cur;
            }
            int? asInt(dynamic v) {
              if (v == null) return null;
              if (v is int) return v;
              if (v is String) return int.tryParse(v);
              if (v is num) return v.toInt();
              return null;
            }

            final employeeId = asInt(
              getVal(response, ['employee_id']) ??
              getVal(response, ['match', 'employee_id']) ??
              getVal(response, ['match', 'employee', 'id']) ??
              getVal(response, ['match', 'employee_data', 'id'])
            );

            final String employeeName = getVal(response, ['match', 'name'])?.toString() ??
                getVal(response, ['employee', 'name'])?.toString() ??
                getVal(response, ['name'])?.toString() ??
                'Unknown Employee';

            bool shouldDelete = true;

            if (employeeId != null) {
              debugPrint('👤 Extracted Employee ID: $employeeId, Name: $employeeName');
              // إرسال الحضور فوراً! تاريخ التقاط الصورة هو وقت الإنشاء
              final String createdAt = request['created_at']; 
              // DateTime ISO 8601 string -> Format required by attendance "YYYY-MM-DD HH:mm:ss"
              final dt = DateTime.parse(createdAt);
              String two(int n) => n.toString().padLeft(2, '0');
              final formattedDate = "${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}";

              // استدعاء خدمة الحضور (نتجاهل النتيجة حالياً لأن العامل أوفلاين ولا يمكنه التفاعل مع shift conflict)
              final apiResult = await AttendanceService.storeByEmployeeId(
                employeeId: employeeId,
                dateTime: formattedDate,
              );
              debugPrint('🔄 Attendance posting result for ID $id: ok=${apiResult.ok}, message=${apiResult.message}');

              if (!apiResult.ok) {
                if (apiResult.message.contains('Network error')) {
                  shouldDelete = false;
                  debugPrint('❌ Attendance posting failed due to network error. Keeping request ID $id to retry later.');
                } else {
                  // Permanent logical error (e.g. shift conflict, duplicate check-in, etc.)
                  await SyncDatabase.instance.insertFailedLog(
                    employeeId,
                    employeeName,
                    apiResult.message,
                  );
                }
              }
            } else {
              debugPrint('⚠️ employeeId NOT found in recognition response for ID $id (e.g. face not recognized or server error).');
              // Log the face mismatch/recognition error
              final String backendMsg = response['message']?.toString() ??
                  response['error']?.toString() ??
                  (response['match'] is Map ? response['match']['message']?.toString() : null) ??
                  'Face not recognized';
              await SyncDatabase.instance.insertFailedLog(
                null,
                'Unknown Employee',
                backendMsg,
              );
            }

            if (shouldDelete) {
              await SyncDatabase.instance.deleteRequest(id);
              try {
                if (await file.exists()) {
                  await file.delete();
                }
              } catch (e) {
                debugPrint('⚠️ Warning: Could not delete local file $fullImagePath: $e');
              }
              debugPrint('✅ Successfully synced and deleted request ID: $id');
            } else {
              // إذا كان هناك خطأ شبكة، نوقف حلقة التكرار ولا نحذف لكي نعاود المحاولة لاحقاً
              break;
            }
          } else {
             // Null يعني أن هناك مشكلة غير متوقعة ولكن لم تسبب Exception
             // سنتعامل معها كفشل ونحتفظ بالطلب للمحاولة القادمة
             debugPrint('⚠️ Sync returned null for ID: $id, keeping request.');
             break; // نتوقف لكي لا نحاول رفع الباقي الآن
          }
        } catch (e) {
          // حدث خطأ في الاتصال (Timeout, SocketException, إلخ)
          debugPrint('❌ Sync failed for ID $id. Error: $e');
          // الخروج من الدائرة وترك الطلبات الباقية في الطابور للمحاولة لاحقاً
          break;
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}
