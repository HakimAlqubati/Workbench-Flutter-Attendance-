import 'package:flutter/foundation.dart';
import 'package:my_app/features/settings/settings_store.dart';

/// ------- API endpoints -------
const String kLivenessApiUrl = 'https://54.251.132.76:5000/api/liveness';
const String kFaceRecognitionApiUrl =
    'https://workbench.ressystem.com/api/hr/faceRecognition';

/// ------- Face fit thresholds -------
const double kMinFaceRatio = 0.06;
const double kFitRelaxFactor = 1.30;

/// ------- Ellipse window (screen %) -------
// const double kOvalRxPct = 0.36;
// const double kOvalRyPct = 0.24;
const double kDefaultOvalRxPct = 0.36;
const double kDefaultOvalRyPct = 0.24;
/// Getters dynamic (لو تم حفظ قيم جديدة في SettingsStore → تُستخدم، وإلا fallback على الافتراضي)
double get kOvalRxPct {
  try {
    return SettingsStore.I.value.ovalRxPct;
  } catch (_) {
    return kDefaultOvalRxPct;
  }
}

double get kOvalRyPct {
  try {
    return SettingsStore.I.value.ovalRyPct;
  } catch (_) {
    return kDefaultOvalRyPct;
  }
}

const double kOvalCxOffsetPct = 0.00;
const double kOvalCyOffsetPct = -0.03;

/// ------- Inside tolerance -------
const double kOvalInsideEpsilon = 0.95; // was 0.20 (too strict)

/// ------- Timings (dynamic via SettingsStore) -------
/// استخدم getters آمنة بدل ثوابت/متغيرات أعلى الملف.
/// لو SettingsStore لم يتهيّأ بعد → رجّع fallback (5 و 59).
int get kCountdownSeconds {
  try {
    return SettingsStore.I.value.countdownSeconds;
  } catch (_) {
    return 5;
  }
}

int get kScreensaverSeconds {
  try {
    return SettingsStore.I.value.screensaverSeconds;
  } catch (_) {
    return 30;
  }
}

const int kDisplayImageMs = 15000;
const int kClockDwellMs = 30000;
const int kBrightnessSampleEveryN = 3;

/// ------- Performance -------
const int kDetectEveryN = 4;

/// ------- HTTPS (debug only) -------
// bool get kAllowInsecureHttps => !kReleaseMode;
const bool kAllowInsecureHttps = true;

/// ------- Feature flags -------
const bool kEnableLiveness        = bool.fromEnvironment('ENABLE_LIVENESS', defaultValue: false);
// const bool kEnableFaceRecognition = bool.fromEnvironment('ENABLE_FACE_RECOGNITION', defaultValue: false);
const bool kEnableOnDeviceDetection = bool.fromEnvironment('ENABLE_ONDEVICE_DETECTION', defaultValue: false);
bool get kEnableFaceRecognition {
  try {
    return SettingsStore.I.value.enableFaceRecognition;
  } catch (_) {
    return false; // fallback
  }
}


// مدى تقبّل الانحراف عن مركز البيضاوي كنسبة من نصف القطر (0..1)
const double kCenterEpsilonPct = 0.18; // جرّب 0.15..0.22 حسب ذوقك
