import 'package:flutter/foundation.dart';
import 'package:my_app/features/face_liveness/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مفاتيح SharedPreferences
const _kKeyCountdownSeconds   = 'settings.countdown_seconds';
const _kKeyScreensaverSeconds = 'settings.screensaver_seconds';
const _kKeyOvalRxPct          = 'settings.oval_rx_pct';
const _kKeyOvalRyPct          = 'settings.oval_ry_pct';
const _kKeyEnableFaceRecognition = 'settings.enable_face_recognition';

/// القيم الافتراضية
const _kDefaultCountdownSeconds   = 5;
const _kDefaultScreensaverSeconds = 300;
const _kDefaultOvalRxPct = kDefaultOvalRxPct;
const _kDefaultOvalRyPct = kDefaultOvalRyPct;
const _kDefaultEnableFaceRecognition = false;
/// موديل الإعدادات
class AppSettings {
  final int countdownSeconds;
  final int screensaverSeconds;
  final double ovalRxPct;
  final double ovalRyPct;
  final bool enableFaceRecognition;

  const AppSettings({
    required this.countdownSeconds,
    required this.screensaverSeconds,
    required this.ovalRxPct,
    required this.ovalRyPct,
    required this.enableFaceRecognition,
  });

  AppSettings copyWith({
    int? countdownSeconds,
    int? screensaverSeconds,
    double? ovalRxPct,
    double? ovalRyPct,
    bool? enableFaceRecognition,
  }) {
    return AppSettings(
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      screensaverSeconds: screensaverSeconds ?? this.screensaverSeconds,
      ovalRxPct: ovalRxPct ?? this.ovalRxPct,
      ovalRyPct: ovalRyPct ?? this.ovalRyPct,
      enableFaceRecognition: enableFaceRecognition ?? this.enableFaceRecognition,

    );
  }
}

/// مخزن الإعدادات
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
    ),
  );

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();

    final countdown = _prefs!.getInt(_kKeyCountdownSeconds) ?? _kDefaultCountdownSeconds;
    final saver     = _prefs!.getInt(_kKeyScreensaverSeconds) ?? _kDefaultScreensaverSeconds;
    final rx        = _prefs!.getDouble(_kKeyOvalRxPct) ?? _kDefaultOvalRxPct;
    final ry        = _prefs!.getDouble(_kKeyOvalRyPct) ?? _kDefaultOvalRyPct;
    final faceRec   = _prefs!.getBool(_kKeyEnableFaceRecognition) ?? _kDefaultEnableFaceRecognition;

    notifier.value = AppSettings(
      countdownSeconds: countdown,
      screensaverSeconds: saver,
      ovalRxPct: rx,
      ovalRyPct: ry,
      enableFaceRecognition: faceRec,

    );
  }

  AppSettings get value => notifier.value;

  Future<void> setCountdownSeconds(int seconds) async {
    await _prefs?.setInt(_kKeyCountdownSeconds, seconds);
    notifier.value = notifier.value.copyWith(countdownSeconds: seconds);
  }

  Future<void> setEnableFaceRecognition(bool enabled) async {
    await _prefs?.setBool(_kKeyEnableFaceRecognition, enabled);
    notifier.value = notifier.value.copyWith(enableFaceRecognition: enabled);
  }

  Future<void> setScreensaverSeconds(int seconds) async {
    await _prefs?.setInt(_kKeyScreensaverSeconds, seconds);
    notifier.value = notifier.value.copyWith(screensaverSeconds: seconds);
  }

  Future<void> setOvalRxPct(double rx) async {
    await _prefs?.setDouble(_kKeyOvalRxPct, rx);
    notifier.value = notifier.value.copyWith(ovalRxPct: rx);
  }

  Future<void> setOvalRyPct(double ry) async {
    await _prefs?.setDouble(_kKeyOvalRyPct, ry);
    notifier.value = notifier.value.copyWith(ovalRyPct: ry);
  }
}
