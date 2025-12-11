import 'package:flutter/foundation.dart';
import 'package:my_app/features/settings/settings_store.dart';



/// ------- API Base URL -------
// const String kApiBaseUrl = "https://workbench.ressystem.com";
// const String kApiBaseUrl = "http://192.168.8.149:9000";
late String kApiBaseUrl; // تُعيَّن في الإقلاع قبل استعمالها

String get kFaceRecognitionApiUrl => "$kApiBaseUrl/api/hr/identifyEmployee";
String get kAttendanceApiUrl      => "$kApiBaseUrl/api/v2/attendance/test";

// (اختياري) دالة موحّدة:
String api(String path) => "$kApiBaseUrl$path";
// ثم تستخدم: api("/api/hr/identifyEmployee")

/// ------- Face fit thresholds -------
const double kMinFaceRatio = 0.06;
const double kFitRelaxFactor = 1.30;



/// ------- UI feature flags -------
bool get kShowSwitchCameraButton {
  try {
    return SettingsStore.I.value.showSwitchCameraButton;
  } catch (_) {
    return false; // fallback لو ما وصلت قيمة من السيرفر
  }
}

/// ------- Ellipse window (screen %) -------
/// ملاحظة: نستخدم getters ديناميكية لقراءة القيم من SettingsStore (إن وُجدت)
const double kDefaultOvalRxPct = 0.42;
const double kDefaultOvalRyPct = 0.27;

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
int get kCountdownSeconds {
  try {
    return SettingsStore.I.value.countdownSeconds;
  } catch (_) {
    return 1;
  }
}

int get kScreensaverSeconds {
  try {
    return SettingsStore.I.value.screensaverSeconds;
  } catch (_) {
    return 30;
  }
}
// مدة بقاء الصورة بعد اكتمال النتائج أو تفعيل fallback
const int kDisplayImageMs   = 5000;

// مهلة لعرض رسالة "يطول أكثر من المعتاد"
const int kSoftTimeoutMs    = 2500;

// مهلة قصوى قبل بدء العدّاد حتى لو النتائج لم تكتمل
const int kHardTimeoutMs    = 6000;

const int kClockDwellMs = 30000;
const int kBrightnessSampleEveryN = 3;

/// ------- Performance -------
const int kDetectEveryN = 4;

/// ------- HTTPS (debug only) -------
// bool get kAllowInsecureHttps => !kReleaseMode;
const bool kAllowInsecureHttps = true;

/// ------- Feature flags -------
const bool kEnableLiveness        = bool.fromEnvironment('ENABLE_LIVENESS', defaultValue: true);
const bool kEnableOnDeviceDetection = bool.fromEnvironment('ENABLE_ONDEVICE_DETECTION', defaultValue: false);

bool get kEnableFaceRecognition {
  try {
    return SettingsStore.I.value.enableFaceRecognition;
  } catch (_) {
    return true; // fallback
  }
}

// مدى تقبّل الانحراف عن مركز البيضاوي كنسبة من نصف القطر (0..1)
const double kCenterEpsilonPct = 0.18; // جرّب 0.15..0.22 حسب ذوقك

/// ------- Face size thresholds (faceShort/imgShort) -------

/// ------- Face size thresholds (faceShort/imgShort) -------
double get kFaceRawMin {
  try {
    return SettingsStore.I.value.faceRawMin;
  } catch (_) {
    return 0.20;
  }
}

double get kFaceRawIdeal {
  try {
    return SettingsStore.I.value.faceRawIdeal;
  } catch (_) {
    return 0.22;
  }
}

double get kFaceRawMax {
  try {
    return SettingsStore.I.value.faceRawMax;
  } catch (_) {
    return 0.50;
  }
}

/// Class لتعريف إعدادات افتراضية
class FaceSizeThresholds {
  final double rawMin;   // أصغر نسبة مقبولة (لو أقل ⇒ بعيد)
  final double rawIdeal; // النسبة المثلى
  final double rawMax;   // أكبر نسبة مقبولة (لو أعلى ⇒ قريب جداً)

  const FaceSizeThresholds({
    required this.rawMin,
    required this.rawIdeal,
    required this.rawMax,
  });

  /// إعدادات افتراضية مناسبة لمعظم الأجهزة (عدّل حسب تجربتك)
  static const FaceSizeThresholds defaults = FaceSizeThresholds(
    rawMin: 0.20,   // بعيد
    rawIdeal: 0.22, // مثالي
    rawMax: 0.50,   // قريب جداً
  );
}

/// ------- Crop scale factor -------
/// 0.7 = الحجم الطبيعي, >1 = تكبير, <1 = تصغير
double get kCropScale {
  try {
    return SettingsStore.I.value.cropScale;
  } catch (_) {
    return 0.7; // fallback
  }
}

bool get kShowCameraScreen {
  try {
    return SettingsStore.I.value.showCameraScreen;
  } catch (_) {
    return true;
  }
}

bool get kShowKeypadScreen {
  try {
    return SettingsStore.I.value.showKeypadScreen;
  } catch (_) {
    return true;
  }
}
