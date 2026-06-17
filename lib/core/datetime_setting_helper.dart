import 'dart:io';
import 'package:flutter/services.dart';

class DateTimeSettingHelper {
  static const MethodChannel _channel =
      MethodChannel('com.example.my_app/datetime_setting');

  /// Checks if "Automatic Date & Time" is enabled on the device.
  /// On non-Android platforms (like iOS), it returns true because iOS does not
  /// expose a public API to read this setting.
  static Future<bool> isAutomaticTimeEnabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? isAuto =
          await _channel.invokeMethod<bool>('isAutomaticTimeEnabled');
      return isAuto ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Opens the system Date & Time settings screen on Android.
  static Future<void> openDateTimeSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openDateTimeSettings');
    } on PlatformException catch (_) {
      // Ignore or log error
    }
  }
}
