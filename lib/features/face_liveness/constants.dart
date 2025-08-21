import 'package:flutter/foundation.dart';


/// API endpoints
const String kLivenessApiUrl = 'https://54.251.132.76:5000/api/liveness';
const String kFaceRecognitionApiUrl =
    'https://workbench.ressystem.com/api/hr/faceRecognition';


/// Face fit thresholds
const double kMinFaceRatio = 0.06;
const double kFitRelaxFactor = 1.30;


/// Ellipse (real) window parameters (as screen percentages)
const double kOvalRxPct = 0.36;
const double kOvalRyPct = 0.24;
const double kOvalCxOffsetPct = 0.00;
const double kOvalCyOffsetPct = -0.03;


/// Inside tolerance (multiplies radii). Use ~0.95..1.0 for reasonable acceptance
const double kOvalInsideEpsilon = 0.95; // <-- was 0.20 (too strict)


/// Timings
const int kCountdownSeconds = 5;
const int kDisplayImageMs = 15000;
const int kScreensaverSeconds = 300;
const int kClockDwellMs = 30000;
const int kBrightnessSampleEveryN = 3;


/// Performance knobs
const int kDetectEveryN = 4;


/// Whether to allow insecure HTTPS (debug only)
bool get kAllowInsecureHttps => !kReleaseMode;


// ===== Feature flags =====
const bool kEnableLiveness          = bool.fromEnvironment('ENABLE_LIVENESS', defaultValue: true);
const bool kEnableFaceRecognition   = bool.fromEnvironment('ENABLE_FACE_RECOGNITION', defaultValue: false);
// (اختياري) لو حبيت توقف كشف الوجوه (ML Kit) نهائياً:
const bool kEnableOnDeviceDetection = bool.fromEnvironment('ENABLE_ONDEVICE_DETECTION', defaultValue: true);
