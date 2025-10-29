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
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    }
    return client;
  }

  Future<Map<String, dynamic>?> sendLiveness(String imagePath) async {
    final uri = Uri.parse('https://workbench.ressystem.com/api/hr/liveness');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));

    final io = IOClient(_newHttpClient());
    try {
      debugPrint('➡️ Request: ${req.method} $uri');
      debugPrint('Headers: ${req.headers}');
      for (var f in req.files) {
        debugPrint('File: field=${f.field}, filename=${f.filename}, length=${f.length}');
      }

      final streamed = await io.send(req).timeout(const Duration(seconds: 12));
      final res = await http.Response.fromStream(streamed);

      if (res.body.isEmpty) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } finally {
      io.close();
    }
  }

  /// ✅ هنا التعديل المهم
  Future<Map<String, dynamic>?> sendFaceRecognition(String imagePath) async {
    final uri = Uri.parse(kFaceRecognitionApiUrl);

    // 1️⃣ اجلب الهيدر الذي يحتوي على التوكن
    final auth = AuthService();
    final headers = await auth.authHeader();

    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers) // ⬅️ إضافة الهيدر هنا
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));

    debugPrint('➡️ FaceRecognition Request to: $uri');
    debugPrint('Headers: ${req.headers}');
    for (var f in req.files) {
      debugPrint('File: field=${f.field}, filename=${f.filename}');
    }

    final streamed = await req.send().timeout(const Duration(seconds: 12));
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 401) {
      debugPrint('❌ Unauthorized (token invalid or expired)');
      return {'error': 'unauthorized', 'status': 401};
    }

    if (res.body.isEmpty) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
