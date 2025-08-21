

// =============================
// File: lib/features/face_liveness/services/network_service.dart
// =============================
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
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
    final uri = Uri.parse(kLivenessApiUrl);
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));


    final io = IOClient(_newHttpClient());
    try {
      final streamed = await io.send(req).timeout(const Duration(seconds: 12));
      final res = await http.Response.fromStream(streamed);
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } finally {
      io.close();
    }
  }


  Future<Map<String, dynamic>?> sendFaceRecognition(String imagePath) async {
    final uri = Uri.parse(kFaceRecognitionApiUrl);
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));


    final streamed = await req.send().timeout(const Duration(seconds: 12));
    final res = await http.Response.fromStream(streamed);
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

