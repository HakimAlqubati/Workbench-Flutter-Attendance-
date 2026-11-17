import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:my_app/features/face_liveness/services/auth_service.dart';
import '../constants.dart';

class LivenessNetworkService {
  HttpClient _newHttpClient() {
    final client = HttpClient();
    if (kAllowInsecureHttps) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    }
    return client;
  }

  // ==================== دوال الطباعة والتتبع (Logging) ====================

  /// طباعة تفاصيل الطلب قبل إرساله إلى السيرفر
  void _logRequest(String tag, http.MultipartRequest req) {
    debugPrint('╔════════════════════ [HTTP REQUEST: $tag] ════════════════════');
    debugPrint('║ ➡️ Method:   ${req.method}');
    debugPrint('║ 🌐 URL:      ${req.url}');
    debugPrint('║ ⏰ Time:     ${DateTime.now().toIso8601String()}');
    debugPrint('║ 📋 Headers:');
    if (req.headers.isEmpty) {
      debugPrint('║    (none)');
    } else {
      req.headers.forEach((k, v) => debugPrint('║    $k: $v'));
    }
    if (req.fields.isNotEmpty) {
      debugPrint('║ 📝 Fields:');
      req.fields.forEach((k, v) => debugPrint('║    $k: $v'));
    }
    debugPrint('║ 📁 Files (${req.files.length}):');
    for (final f in req.files) {
      debugPrint('║    field=${f.field}, filename=${f.filename}, length=${f.length} bytes');
    }
    debugPrint('╚══════════════════════════════════════════════════════════════════');
  }

  /// طباعة تفاصيل الرد بعد استلامه من السيرفر
  void _logResponse(String tag, http.Response res) {
    final isHtml = res.body.trimLeft().startsWith('<');
    debugPrint('╔════════════════════ [HTTP RESPONSE: $tag] ════════════════════');
    debugPrint('║ 📊 Status:       ${res.statusCode} ${res.reasonPhrase ?? ''}');
    debugPrint('║ ⏰ Time:         ${DateTime.now().toIso8601String()}');
    debugPrint('║ 📑 Content-Type: ${res.headers['content-type'] ?? 'unknown'}');
    debugPrint('║ 📦 Body Length:  ${res.body.length} chars');
    if (isHtml) {
      debugPrint('║ ⚠️ تحذير: الرد عبارة عن صفحة HTML وليس كائن JSON!');
      debugPrint('║ 📄 بداية الرد (HTML Preview):');
      final preview = res.body.length > 300 ? '${res.body.substring(0, 300)}...' : res.body;
      debugPrint('║ $preview');
    } else {
      debugPrint('║ 📄 Response Body:');
      debugPrint('║ ${res.body.isEmpty ? '(empty)' : res.body}');
    }
    debugPrint('╚══════════════════════════════════════════════════════════════════');
  }

  /// فك تشفير JSON بأمان دون التسبب في FormatException إذا كان الرد HTML
  Map<String, dynamic>? _safeJsonDecode(String tag, http.Response res) {
    if (res.body.isEmpty) {
      debugPrint('ℹ️ [$tag] Response body is empty.');
      return null;
    }

    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'status': 'ok', 'data': decoded};
    } catch (e) {
      debugPrint('❌ [$tag] Failed to parse JSON: $e');
      return {
        'status': 'error',
        'error': 'Server error (${res.statusCode}): Server returned non-JSON response',
        'statusCode': res.statusCode,
        'raw_body': res.body,
      };
    }
  }

  // ==================== دوال الإرسال ====================

  Future<Map<String, dynamic>?> sendLiveness(String imagePath) async {
    final uri = Uri.parse(kLivenessApiUrl);

    final auth = AuthService();
    final headers = await auth.authHeader();

    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));

    final io = IOClient(_newHttpClient());
    try {
      // 1️⃣ طباعة تفاصيل الطلب قبل الإرسال
      _logRequest('sendLiveness', req);

      final streamed = await io.send(req).timeout(const Duration(seconds: 12));
      final res = await http.Response.fromStream(streamed);

      // 2️⃣ طباعة تفاصيل الرد بعد الاستلام
      _logResponse('sendLiveness', res);

      return _safeJsonDecode('sendLiveness', res);
    } catch (e, stack) {
      debugPrint('❌ [sendLiveness] Request Exception: $e');
      debugPrint('$stack');
      rethrow;
    } finally {
      io.close();
    }
  }

  /// ✅ إرسال صورة للتعرف على الوجه
  Future<Map<String, dynamic>?> sendFaceRecognition(String imagePath) async {
    final uri = Uri.parse(kFaceRecognitionApiUrl);

    // 1️⃣ اجلب الهيدر الذي يحتوي على التوكن
    final auth = AuthService();
    final headers = await auth.authHeader();

    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));

    final io = IOClient(_newHttpClient());
    try {
      // 1️⃣ طباعة تفاصيل الطلب قبل الإرسال
      _logRequest('sendFaceRecognition', req);

      final streamed = await io.send(req).timeout(const Duration(seconds: 12));
      final res = await http.Response.fromStream(streamed);

      // 2️⃣ طباعة تفاصيل الرد بعد الاستلام
      _logResponse('sendFaceRecognition', res);

      if (res.statusCode == 401) {
        debugPrint('❌ Unauthorized (token invalid or expired)');
        return {'error': 'unauthorized', 'status': 401};
      }

      return _safeJsonDecode('sendFaceRecognition', res);
    } catch (e, stack) {
      debugPrint('❌ [sendFaceRecognition] Request Exception: $e');
      debugPrint('$stack');
      rethrow;
    } finally {
      io.close();
    }
  }
}
