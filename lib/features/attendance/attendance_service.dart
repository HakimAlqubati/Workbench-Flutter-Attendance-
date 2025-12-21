import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/features/face_liveness/constants.dart';
import 'package:my_app/features/face_liveness/services/auth_service.dart';

class ApiResult {
  final bool ok;
  final String message;
  final bool needType; // ✅ جديد
  ApiResult({
    required this.ok,
    required this.message,
    this.needType = false,
  });

  // factory ApiResult.fromJson(Map<String, dynamic> j) {
  //   final ok = (j['status'] == true) || (j['success'] == true);
  //
  //   // نحافظ على الرسالة الأصلية للعرض
  //   final messageOriginal = (j['message'] ?? '').toString().trim();
  //
  //   // نستخدم نسخة lower فقط للفحص عن needType
  //   final msgLower = messageOriginal.toLowerCase();
  //
  //   final needType = msgLower.contains('please specify type');
  //
  //   return ApiResult(
  //     ok: ok,
  //     needType: needType,
  //     message: messageOriginal, // نعرض الأصلية
  //   );
  // }

}


bool _needsType(http.Response res) {
  try {
    final json = jsonDecode(res.body);
    final typeRequired = json['type_required'] == true;
    debugPrint('zzz type_required => $typeRequired');
    return typeRequired;
  } catch (e) {
    debugPrint('needsType parse error: $e');
    return false;
  }
}


class AttendanceService {

  static Future<String?> Function()? onRequireType;


  static Future<ApiResult> storeByRfid({
    required String rfid,
    required String dateTime, // "YYYY-MM-DD HH:mm:ss"
    Map<String, String>? headers,
  }) async {
    // 1) أول محاولة بدون type
    final first = await _postAttendance(
      body: {
        "rfid": rfid,
        "date_time": dateTime,
      },
      headers: headers,
    );

    // 2) لو السيرفر طلب النوع → اسأله المستخدم ثم أعد المحاولة
    if (first.needType) {
      final t = (await onRequireType?.call())?.trim().toLowerCase();
      if (t == null) {
        return ApiResult(ok: false, message: "Operation cancelled by user.");
      }

      return _postAttendance(
        body: {
          "rfid": rfid,
          "date_time": dateTime,
          "type": t,
        },
        headers: headers,
      );
    }

    return first;
  }


  static Future<ApiResult> storeByEmployeeId({
    required int employeeId,
    required String dateTime, // "YYYY-MM-DD HH:mm:ss"
    Map<String, String>? headers,
    String? type,
  }) async {
    return _postAttendance(body: {
      "employee_id": employeeId,
      "date_time": dateTime,
      if (type != null) 'type': type,

    }, headers: headers);
  }

  // === مشترك: تنفيذ POST واستخراج الرسالة بشكل ذكي ===
  static Future<ApiResult> _postAttendance({
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(kAttendanceApiUrl);
    final authHeaders = await AuthService().authHeader();
    final mergedHeaders = <String, String>{
      "Content-Type": "application/json",
      "Accept": "application/json",
      ...authHeaders,
      ...?headers,
    };

    http.Response res;
    try {
      res = await http
          .post(uri, headers: mergedHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return ApiResult(ok: false, message: "Network error: $e");
    }

    final raw = utf8.decode(res.bodyBytes);

    String extractMsg(String body) {
      try {
        final d = jsonDecode(body);
        if (d is Map<String, dynamic>) {
          String m = (d["message"] ?? d["msg"] ?? d["error"] ?? "").toString();
          if (m.isEmpty && d["errors"] is Map) {
            final errors = (d["errors"] as Map)
                .values
                .expand((v) => (v as List).map((e) => e.toString()))
                .join(" | ");
            if (errors.isNotEmpty) m = errors;
          }
          return m;
        }
      } catch (_) {}
      return body;
    }

    // ✅ لو السيرفر يطلب type: رجّع needType=true
    if (_needsType(res)) {
      final msg = extractMsg(raw).isNotEmpty ? extractMsg(raw) : "please specify type";
      return ApiResult(ok: false, message: msg, needType: true);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic>) {
          final status =   data["status"] == true ;
          debugPrint('row ${raw}');
          debugPrint(raw);
          var rowDecoded = jsonDecode(raw);
          var msg = rowDecoded['message'];
          return ApiResult(ok: status, message: msg);
        }
        return ApiResult(ok: true, message: "OK");
      } catch (_) {
        return ApiResult(ok: false, message: "Non-JSON response.");
      }
    }

    final serverMsg = extractMsg(raw);
    return ApiResult(ok: false, message: serverMsg.isNotEmpty ? serverMsg : "HTTP ${res.statusCode}");
  }
}

// تنسيق التاريخ: 2025-08-31 23:59:59
String formatDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return "${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}";
}
