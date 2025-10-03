import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:my_app/features/face_liveness/constants.dart';

/// -------- مفاتيح SharedPreferences --------
const _kKeyCountdownSeconds           = 'settings.countdown_seconds';
const _kKeyScreensaverSeconds         = 'settings.screensaver_seconds';
const _kKeyOvalRxPct                  = 'settings.oval_rx_pct';
const _kKeyOvalRyPct                  = 'settings.oval_ry_pct';
const _kKeyEnableFaceRecognition      = 'settings.enable_face_recognition';
const _kKeyShowSwitchCameraButton     = 'settings.show_switch_camera_button';
const _kKeySettingsUpdatedAt          = 'settings.updated_at_iso';

const _kKeyShowCameraScreen = 'settings.show_camera_screen';
const _kKeyShowKeypadScreen = 'settings.show_keypad_screen';

// 🆕 Face thresholds keys
const _kKeyFaceRawMin                 = 'settings.face_raw_min';
const _kKeyFaceRawIdeal               = 'settings.face_raw_ideal';
const _kKeyFaceRawMax                 = 'settings.face_raw_max';

// 🆕 Crop scale key
const _kKeyCropScale                  = 'settings.crop_scale';

/// -------- القيم الافتراضية --------
const _kDefaultCountdownSeconds       = 2;
const _kDefaultScreensaverSeconds     = 30;
const _kDefaultOvalRxPct              = kDefaultOvalRxPct;
const _kDefaultOvalRyPct              = kDefaultOvalRyPct;
const _kDefaultEnableFaceRecognition  = false;
const _kDefaultShowSwitchCameraButton = false;

const _kDefaultShowCameraScreen = false;
const _kDefaultShowKeypadScreen = false;

// 🆕 Face thresholds defaults
const _kDefaultFaceRawMin             = 0.20;
const _kDefaultFaceRawIdeal           = 0.22;
const _kDefaultFaceRawMax             = 0.50;

// 🆕 Crop scale default
const _kDefaultCropScale              = 0.7;

/// -------- رابط API للإعدادات --------
const _kSettingsApiUrl = '$kApiBaseUrl/api/app/settings';

/// -------- موديل الإعدادات --------
class AppSettings {
  final int countdownSeconds;
  final int screensaverSeconds;
  final double ovalRxPct;
  final double ovalRyPct;
  final bool enableFaceRecognition;
  final bool showSwitchCameraButton;
  final double cropScale;
  final String? updatedAtIso; // من السيرفر (اختياري)

  // 🆕 Face thresholds
  final double faceRawMin;
  final double faceRawIdeal;
  final double faceRawMax;

  final bool showCameraScreen;   // 🆕
  final bool showKeypadScreen;

  const AppSettings({
    required this.countdownSeconds,
    required this.screensaverSeconds,
    required this.ovalRxPct,
    required this.ovalRyPct,
    required this.enableFaceRecognition,
    required this.showSwitchCameraButton,
    required this.faceRawMin,
    required this.faceRawIdeal,
    required this.faceRawMax,
    required this.cropScale,
    required this.showCameraScreen,
    required this.showKeypadScreen,
    this.updatedAtIso,
  });

  AppSettings copyWith({
    int? countdownSeconds,
    int? screensaverSeconds,
    double? ovalRxPct,
    double? ovalRyPct,
    bool? enableFaceRecognition,
    bool? showSwitchCameraButton,
    double? faceRawMin,
    double? faceRawIdeal,
    double? faceRawMax,
    double? cropScale,
    bool? showCameraScreen,
    bool? showKeypadScreen,
    String? updatedAtIso,
  }) {
    return AppSettings(
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      screensaverSeconds: screensaverSeconds ?? this.screensaverSeconds,
      ovalRxPct: ovalRxPct ?? this.ovalRxPct,
      ovalRyPct: ovalRyPct ?? this.ovalRyPct,
      enableFaceRecognition: enableFaceRecognition ?? this.enableFaceRecognition,
      showSwitchCameraButton: showSwitchCameraButton ?? this.showSwitchCameraButton,
      faceRawMin: faceRawMin ?? this.faceRawMin,
      faceRawIdeal: faceRawIdeal ?? this.faceRawIdeal,
      faceRawMax: faceRawMax ?? this.faceRawMax,
      cropScale: cropScale ?? this.cropScale,
      showCameraScreen: showCameraScreen ?? this.showCameraScreen,
      showKeypadScreen: showKeypadScreen ?? this.showKeypadScreen,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  bool _parseBool(dynamic v, {required bool def}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == '1' || s == 'true' || s == 'yes' || s == 'on';
    }
    return def;
  }

  /// إنشاء من JSON القادم من السيرفر
  factory AppSettings.fromServerJson(
      Map<String, dynamic> json, {
        required AppSettings fallback,
      }) {
    return fallback.copyWith(
      countdownSeconds: json['countdownSeconds'] as int? ?? fallback.countdownSeconds,
      screensaverSeconds: json['screensaverSeconds'] as int? ?? fallback.screensaverSeconds,
      ovalRxPct: (json['ovalRxPct'] as num?)?.toDouble() ?? fallback.ovalRxPct,
      ovalRyPct: (json['ovalRyPct'] as num?)?.toDouble() ?? fallback.ovalRyPct,
      enableFaceRecognition: json['enableFaceRecognition'] as bool? ?? fallback.enableFaceRecognition,
      showSwitchCameraButton: json['showSwitchCameraButton'] as bool? ?? fallback.showSwitchCameraButton,
      faceRawMin: (json['faceRawMin'] as num?)?.toDouble() ?? fallback.faceRawMin,
      faceRawIdeal: (json['faceRawIdeal'] as num?)?.toDouble() ?? fallback.faceRawIdeal,
      faceRawMax: (json['faceRawMax'] as num?)?.toDouble() ?? fallback.faceRawMax,
      cropScale: (json['cropScale'] as num?)?.toDouble() ?? fallback.cropScale,

      updatedAtIso: json['updatedAt'] as String? ?? fallback.updatedAtIso,


    );
  }

  /// إنشاء من التخزين المحلي
  factory AppSettings.fromPrefs(SharedPreferences prefs) {
    return AppSettings(
      countdownSeconds: prefs.getInt(_kKeyCountdownSeconds) ?? _kDefaultCountdownSeconds,
      screensaverSeconds: prefs.getInt(_kKeyScreensaverSeconds) ?? _kDefaultScreensaverSeconds,
      ovalRxPct: prefs.getDouble(_kKeyOvalRxPct) ?? _kDefaultOvalRxPct,
      ovalRyPct: prefs.getDouble(_kKeyOvalRyPct) ?? _kDefaultOvalRyPct,
      enableFaceRecognition: prefs.getBool(_kKeyEnableFaceRecognition) ?? _kDefaultEnableFaceRecognition,
      showSwitchCameraButton: prefs.getBool(_kKeyShowSwitchCameraButton) ?? _kDefaultShowSwitchCameraButton,
      faceRawMin: prefs.getDouble(_kKeyFaceRawMin) ?? _kDefaultFaceRawMin,
      faceRawIdeal: prefs.getDouble(_kKeyFaceRawIdeal) ?? _kDefaultFaceRawIdeal,
      faceRawMax: prefs.getDouble(_kKeyFaceRawMax) ?? _kDefaultFaceRawMax,
      cropScale: prefs.getDouble(_kKeyCropScale) ?? _kDefaultCropScale,
      showCameraScreen: prefs.getBool(_kKeyShowCameraScreen) ?? _kDefaultShowCameraScreen,
      showKeypadScreen: prefs.getBool(_kKeyShowKeypadScreen) ?? _kDefaultShowKeypadScreen,
      updatedAtIso: prefs.getString(_kKeySettingsUpdatedAt),
    );
  }

  /// حفظ في التخزين المحلي
  Future<void> saveToPrefs(SharedPreferences prefs) async {
    await prefs.setInt(_kKeyCountdownSeconds, countdownSeconds);
    await prefs.setInt(_kKeyScreensaverSeconds, screensaverSeconds);
    await prefs.setDouble(_kKeyOvalRxPct, ovalRxPct);
    await prefs.setDouble(_kKeyOvalRyPct, ovalRyPct);
    await prefs.setBool(_kKeyEnableFaceRecognition, enableFaceRecognition);
    await prefs.setBool(_kKeyShowSwitchCameraButton, showSwitchCameraButton);
    await prefs.setDouble(_kKeyFaceRawMin, faceRawMin);
    await prefs.setDouble(_kKeyFaceRawIdeal, faceRawIdeal);
    await prefs.setDouble(_kKeyFaceRawMax, faceRawMax);
    await prefs.setDouble(_kKeyCropScale, cropScale);
    await prefs.setBool(_kKeyShowCameraScreen, showCameraScreen);
    await prefs.setBool(_kKeyShowKeypadScreen, showKeypadScreen);

    if (updatedAtIso != null) {
      await prefs.setString(_kKeySettingsUpdatedAt, updatedAtIso!);
    }
  }
}

/// -------- مخزن الإعدادات (Singleton + ValueNotifier) --------
class SettingsStore {
  SettingsStore._();
  static final SettingsStore I = SettingsStore._();

  final ValueNotifier<AppSettings> notifier = ValueNotifier<AppSettings>(
    const AppSettings(
      countdownSeconds: _kDefaultCountdownSeconds,
      screensaverSeconds: _kDefaultScreensaverSeconds,
      ovalRxPct: _kDefaultOvalRxPct,
      ovalRyPct: _kDefaultOvalRyPct,
      enableFaceRecognition: _kDefaultEnableFaceRecognition,
      showSwitchCameraButton: _kDefaultShowSwitchCameraButton,
      faceRawMin: _kDefaultFaceRawMin,
      faceRawIdeal: _kDefaultFaceRawIdeal,
      faceRawMax: _kDefaultFaceRawMax,
      cropScale: _kDefaultCropScale,
      showCameraScreen: _kDefaultShowCameraScreen,
      showKeypadScreen: _kDefaultShowKeypadScreen,
      updatedAtIso: null,
    ),
  );

  SharedPreferences? _prefs;

  AppSettings get value => notifier.value;

  /// استدعِ هذه في `main()` قبل تشغيل التطبيق
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();

    // 1) حمّل القيم المحلية أولاً (تشغيل سريع/أوفلاين)
    notifier.value = AppSettings.fromPrefs(_prefs!);

    // 2) جرّب تحديثها من السيرفر بصمت (لا يفشل التطبيق إن لم توجد شبكة)
    await refreshFromServer(silent: true);
  }

  Map<String, dynamic>? safeJsonDecode(String src) {
    try {
      return jsonDecode(src) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }


  /// تحديث من السيرفر
  Future<void> refreshFromServer({bool silent = false}) async {
    try {
      final res = await http.get(
        Uri.parse(_kSettingsApiUrl),
        headers: const {
          'Accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = safeJsonDecode(res.body);
        debugPrint('data===>${data}');
        if (data != null) {
          final merged = AppSettings.fromServerJson(data, fallback: value);
          notifier.value = merged;
          await merged.saveToPrefs(_prefs!);
        }

      } else {
        if (!silent) {
          debugPrint('SettingsStore.refreshFromServer: HTTP ${res.statusCode}');
        }
      }
    } catch (e) {
      if (!silent) {
        debugPrint('SettingsStore.refreshFromServer: $e');
      }
    }
  }

  // ----------------- Setters (محلية) -----------------

  Future<void> setCountdownSeconds(int seconds) async {
    final next = value.copyWith(countdownSeconds: seconds);
    notifier.value = next;
    await next.saveToPrefs(_prefs!);
  }

  Future<void> setScreensaverSeconds(int seconds) async {
    final next = value.copyWith(screensaverSeconds: seconds);
    notifier.value = next;
    await next.saveToPrefs(_prefs!);
  }

  Future<void> setOvalRxPct(double rx) async {
    final next = value.copyWith(ovalRxPct: rx);
    notifier.value = next;
    await next.saveToPrefs(_prefs!);
  }

  Future<void> setOvalRyPct(double ry) async {
    final next = value.copyWith(ovalRyPct: ry);
    notifier.value = next;
    await next.saveToPrefs(_prefs!);
  }

  Future<void> setEnableFaceRecognition(bool enabled) async {
    final next = value.copyWith(enableFaceRecognition: enabled);
    notifier.value = next;
    await next.saveToPrefs(_prefs!);
  }

  Future<void> setShowSwitchCameraButton(bool show) async {
    final next = value.copyWith(showSwitchCameraButton: show);
    notifier.value = next;
    await next.saveToPrefs(_prefs!);
  }

  Future<void> setFaceRawMin(double min) async {
    final next = value.copyWith(faceRawMin: min);
    notifier.value = next;
    await next.saveToPrefs(_prefs!);
  }

  Future<void> setFaceRawIdeal(double ideal) async {
    final next = value.copyWith(faceRawIdeal: ideal);
    notifier.value = next;
    await next.saveToPrefs(_prefs!);
  }

  Future<void> setFaceRawMax(double max) async {
    final next = value.copyWith(faceRawMax: max);
    notifier.value = next;
    await next.saveToPrefs(_prefs!);
  }

  Future<void> setCropScale(double scale) async {
    final next = value.copyWith(cropScale: scale);
    notifier.value = next;
    await next.saveToPrefs(_prefs!);
  }

}
