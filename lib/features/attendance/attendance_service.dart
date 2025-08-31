import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_app/features/face_liveness/constants.dart';
import 'package:my_app/features/face_liveness/services/auth_service.dart';

class ApiResult {
  final bool ok;
  final String message;
  ApiResult({required this.ok, required this.message});
}

class AttendanceService {
  static Future<ApiResult> storeAttendance({
    required String rfid,
    required String dateTime, // "YYYY-MM-DD HH:mm:ss"
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(kAttendanceApiUrl);
    final body = jsonEncode({"rfid": rfid, "date_time": dateTime});

    // هيدرز المصادقة
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
          .post(uri, headers: mergedHeaders, body: body)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return ApiResult(ok: false, message: "Network error: $e");
    }

    final raw = utf8.decode(res.bodyBytes);

    // حاول دائمًا استخراج رسالة مفهومة من الجسم
    String _extractMessage(String body) {
      try {
        final d = jsonDecode(body);
        if (d is Map<String, dynamic>) {
          // صيغ شائعة
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
      return body; // ليس JSON، أعد النص كما هو
    }

    // 2xx ⇒ نجاح/فشل منطقي حسب JSON
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic>) {
          final status = data["status"] == true || data["success"] == true || data["ok"] == true;
          var msg = _extractMessage(raw);
          if (msg.isEmpty) {
            msg = status ? "Attendance recorded successfully." : "Failed to record attendance.";
          }
          return ApiResult(ok: status, message: msg);
        }
        return ApiResult(ok: true, message: "OK");
      } catch (_) {
        return ApiResult(ok: false, message: "Non-JSON response.");
      }
    }

    // 4xx/5xx ⇒ رجّع الرسالة الحقيقية بدل "HTTP 422…"
    final serverMsg = _extractMessage(raw);
    return ApiResult(ok: false, message: serverMsg.isNotEmpty ? serverMsg : "HTTP ${res.statusCode}");
  }
}

// تنسيق التاريخ: 2025-08-31 23:59:59
String formatDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return "${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}";
}
