// lib/core/device_id_manager.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:platform_device_id_plus/platform_device_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdManager {
  static const _prefsKey = 'device_id';
  static String? _cached; // كاش بالذاكرة لتقليل قراءات الـ I/O

  /// يُرجع deviceId من الكاش/SharedPrefs، وإن لم يوجد يجلبه ويخزّنه ويرجعه.
  static Future<String?> ensureDeviceId() async {
    // كاش بالذاكرة
    if (_cached != null && _cached!.isNotEmpty) return _cached;

    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty) {
      _cached = saved;
      return _cached;
    }

    // جلب جديد ثم حفظ
    final fresh = await _resolveDeviceIdSafe();
    if (fresh != null && fresh.isNotEmpty) {
      await p.setString(_prefsKey, fresh);
      _cached = fresh;
    }
    return _cached;
  }

  /// يُعيد ما هو محفوظ فقط (بدون محاولة جلب جديد).
  static Future<String?> getSavedDeviceId() async {
    if (_cached != null) return _cached;
    final p = await SharedPreferences.getInstance();
    _cached = p.getString(_prefsKey);
    return _cached;
  }

  /// يجبر إعادة الجلب من النظام وتحديث المحفوظ.
  static Future<String?> refreshDeviceId() async {
    final fresh = await _resolveDeviceIdSafe();
    if (fresh != null && fresh.isNotEmpty) {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, fresh);
      _cached = fresh;
    }
    return _cached;
  }

  /// منطق الجلب الفعلي مع حماية للأخطاء.
  static Future<String?> _resolveDeviceIdSafe() async {
    try {
      if (Platform.isAndroid) {
        final info = await PlatformDeviceId.deviceInfoPlugin.androidInfo;

        // نفضّل serial للأجهزة القديمة لو كان معروف
        if (info.version.sdkInt <= 28 &&
            info.serialNumber.isNotEmpty &&
            info.serialNumber.toLowerCase() != 'unknown') {
          return info.serialNumber.replaceAll('.', '');
        }

        // للأحدث: معرّف آمن من الباكيج
        final id = await PlatformDeviceId.getDeviceId;
        return id;
      } else if (Platform.isIOS) {
        // عادة يكون IdentifierForVendor عبر الباكيج
        final id = await PlatformDeviceId.getDeviceId;
        return id;
      } else {
        // منصّات أخرى (Web/Desktop...) إن لزم
        final id = await PlatformDeviceId.getDeviceId;
        return id;
      }
    } catch (e) {
      debugPrint('DeviceIdManager._resolveDeviceIdSafe error: $e');
      return null;
    }
  }
}
