import 'package:my_app/features/settings/settings_store.dart';

/// ------- API endpoints -------
const String kFaceRecognitionApiUrl =
    'https://workbench.ressystem.com/api/hr/faceRecognition';

String get kLivenessApiUrl {
  try {
    final base = SettingsStore.I.value.baseUrl;
    return '$base/api/liveness';
  } catch (_) {
    return '  /api/liveness';
  }
}

/// ------- Face fit thresholds -------
const double kMinFaceRatio = 0.06;
const double kFitRelaxFactor = 1.30;

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
const bool kEnableLiveness = bool.fromEnvironment(
  'ENABLE_LIVENESS',
  defaultValue: true,
);
const bool kEnableOnDeviceDetection = bool.fromEnvironment(
  'ENABLE_ONDEVICE_DETECTION',
  defaultValue: false,
);

bool get kEnableFaceRecognition {
  try {
    return SettingsStore.I.value.enableFaceRecognition;
  } catch (_) {
    return false; // fallback
  }
}

// مدى تقبّل الانحراف عن مركز البيضاوي كنسبة من نصف القطر (0..1)
const double kCenterEpsilonPct = 0.18; // جرّب 0.15..0.22 حسب ذوقك

/// ------- Face size thresholds (faceShort/imgShort) -------
class FaceSizeThresholds {
  final double rawMin; // أصغر نسبة مقبولة (لو أقل ⇒ بعيد)
  final double rawIdeal; // النسبة المثلى
  final double rawMax; // أكبر نسبة مقبولة (لو أعلى ⇒ قريب جداً)

  const FaceSizeThresholds({
    required this.rawMin,
    required this.rawIdeal,
    required this.rawMax,
  });

  /// إعدادات افتراضية مناسبة لمعظم الأجهزة (عدّل حسب تجربتك)
  static const FaceSizeThresholds defaults = FaceSizeThresholds(
    rawMin: 0.20, // بعيد
    rawIdeal: 0.22, // مثالي
    rawMax: 0.50, // قريب جداً
  );
}
