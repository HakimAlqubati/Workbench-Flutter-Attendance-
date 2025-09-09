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

/// -------- القيم الافتراضية --------
const _kDefaultCountdownSeconds       = 5;
const _kDefaultScreensaverSeconds     = 59;
const _kDefaultOvalRxPct              = kDefaultOvalRxPct;
const _kDefaultOvalRyPct              = kDefaultOvalRyPct;
const _kDefaultEnableFaceRecognition  = false;
const _kDefaultShowSwitchCameraButton = false;

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
  final String? updatedAtIso; // من السيرفر (اختياري)

  const AppSettings({
    required this.countdownSeconds,
    required this.screensaverSeconds,
    required this.ovalRxPct,
    required this.ovalRyPct,
    required this.enableFaceRecognition,
    required this.showSwitchCameraButton,
    this.updatedAtIso,
  });

  AppSettings copyWith({
    int? countdownSeconds,
    int? screensaverSeconds,
    double? ovalRxPct,
    double? ovalRyPct,
    bool? enableFaceRecognition,
    bool? showSwitchCameraButton,
    String? updatedAtIso,
  }) {
    return AppSettings(
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      screensaverSeconds: screensaverSeconds ?? this.screensaverSeconds,
      ovalRxPct: ovalRxPct ?? this.ovalRxPct,
      ovalRyPct: ovalRyPct ?? this.ovalRyPct,
      enableFaceRecognition: enableFaceRecognition ?? this.enableFaceRecognition,
      showSwitchCameraButton:
      showSwitchCameraButton ?? this.showSwitchCameraButton,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  /// إنشاء من JSON القادم من السيرفر
  factory AppSettings.fromServerJson(
      Map<String, dynamic> json, {
        required AppSettings fallback,
      }) {
    return fallback.copyWith(
      // إذا أرسلت حقول إضافية من السيرفر لاحقًا، أضفها هنا بنفس النمط
      showSwitchCameraButton:
      (json['showSwitchCameraButton'] as bool?) ??
          fallback.showSwitchCameraButton,
      updatedAtIso: (json['updatedAt'] as String?) ?? fallback.updatedAtIso,
    );
  }

  /// إنشاء من التخزين المحلي
  factory AppSettings.fromPrefs(SharedPreferences prefs) {
    return AppSettings(
      countdownSeconds:
      prefs.getInt(_kKeyCountdownSeconds) ?? _kDefaultCountdownSeconds,
      screensaverSeconds:
      prefs.getInt(_kKeyScreensaverSeconds) ?? _kDefaultScreensaverSeconds,
      ovalRxPct: prefs.getDouble(_kKeyOvalRxPct) ?? _kDefaultOvalRxPct,
      ovalRyPct: prefs.getDouble(_kKeyOvalRyPct) ?? _kDefaultOvalRyPct,
      enableFaceRecognition:
      prefs.getBool(_kKeyEnableFaceRecognition) ?? _kDefaultEnableFaceRecognition,
      showSwitchCameraButton:
      prefs.getBool(_kKeyShowSwitchCameraButton) ?? _kDefaultShowSwitchCameraButton,
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

  /// تحديث من السيرفر (يمكن استدعاؤها من Settings screen لإعادة التحميل)
  Future<void> refreshFromServer({bool silent = false}) async {
    try {
      final res = await http.get(
        Uri.parse(_kSettingsApiUrl),
        headers: const {
          'Accept': 'application/json',
          // إذا عندك توكن/هيدر أضفه هنا
        },
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        // ابدأ من القيمة الحالية (أو من prefs)، ثم حدّث حقول السيرفر
        final merged = AppSettings.fromServerJson(
          data,
          fallback: value,
        );

        notifier.value = merged;
        await merged.saveToPrefs(_prefs!);
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

  /// إظهار/إخفاء زر تبديل الكاميرا (محليًا)
  /// ملاحظة: هذا لا يكتب للسيرفر، إذا أردت الكتابة للسيرفر وفّر Endpoint PUT/POST.
  Future<void> setShowSwitchCameraButton(bool show) async {
    final next = value.copyWith(showSwitchCameraButton: show);
    notifier.value = next;
    await next.saveToPrefs(_prefs!);
  }
}
