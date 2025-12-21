import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_app/core/device_id_manager.dart';
import 'package:my_app/core/toast_utils.dart';
import 'package:my_app/features/face_liveness/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

String get kLoginUrl => '$kApiBaseUrl/api/login';

class AuthSession {
  final String token;
  final int id;
  final String name;
  final String email;

  AuthSession({required this.token, required this.id, required this.name, required this.email});

  Map<String, dynamic> toJson() => {
    'token': token,
    'id': id,
    'name': name,
    'email': email,
  };

  static AuthSession? fromPrefs(SharedPreferences p) {
    final token = p.getString('auth_token');
    final name  = p.getString('auth_name');
    final email = p.getString('auth_email');
    final id    = p.getInt('auth_id');
    if (token == null || name == null || email == null || id == null) return null;
    return AuthSession(token: token, id: id, name: name, email: email);
  }
}

class AuthService {
  /// يسجّل الدخول ويرجع الجلسة، ويخزنها محليًا
  Future<AuthSession> login({required String username, required String password}) async {
    // 🔐 اجلب/أضمن وجود الـ deviceId
    final deviceId = await DeviceIdManager.ensureDeviceId();
    final res = await http.post(
      Uri.parse(kLoginUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password,'device_id': deviceId.toString()}),
    );


    if(res.statusCode == 403){
      throw Exception('Not Allowed ');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('(${res.statusCode})');
    }

    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final token = j['token'] as String?;
    final user  = j['user'] as Map<String, dynamic>?;

    if (token == null || user == null) {
      throw Exception('Unexpected response from the server');
    }

    final session = AuthSession(
      token: token,
      id: (user['id'] as num).toInt(),
      name: user['name']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
    );

    await _saveSession(session);
    return session;
  }

  Future<void> _saveSession(AuthSession s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('auth_token', s.token);
    await p.setInt('auth_id', s.id);
    await p.setString('auth_name', s.name);
    await p.setString('auth_email', s.email);
  }

  Future<AuthSession?> getSavedSession() async {
    final p = await SharedPreferences.getInstance();
    return AuthSession.fromPrefs(p);
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('auth_token');
    await p.remove('auth_id');
    await p.remove('auth_name');
    await p.remove('auth_email');
  }

  /// هيدر جاهز للطلبات المحمية مستقبلاً
  Future<Map<String, String>> authHeader() async {
    final s = await getSavedSession();
    if (s == null) return {};
    return {'Authorization': 'Bearer ${s.token}'};
  }
}
