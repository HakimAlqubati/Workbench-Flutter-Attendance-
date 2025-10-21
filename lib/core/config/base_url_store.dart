// lib/core/config/base_url_store.dart
import 'package:shared_preferences/shared_preferences.dart';

class BaseUrlStore {
  static const _key = 'base_url';
  static String? _cache;

  static Future<String?> get() async {
    if (_cache != null) return _cache;
    final p = await SharedPreferences.getInstance();
    _cache = p.getString(_key);
    return _cache;
  }

  static Future<void> set(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, url);
    _cache = url;
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
    _cache = null;
  }
}
