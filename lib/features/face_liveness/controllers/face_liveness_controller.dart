// =============================
// File: lib/features/face_liveness/controller/face_liveness_controller.dart
// =============================
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../services/network_service.dart';

class FaceLivenessController extends ChangeNotifier with WidgetsBindingObserver {
  // ===== Dependencies / Services =====
  final LivenessNetworkService _net = LivenessNetworkService();

  // ===== Camera =====
  CameraController? _controller;
  CameraController? get controller => _controller;
  CameraDescription? _frontCamera;

  // ===== Detector =====
  FaceDetector? _detector;
  bool _isDetecting = false;

  // ===== State (public getters) =====
  bool _cameraOpen = true;
  bool get cameraOpen => _cameraOpen;

  bool _faceDetected = false;
  bool get faceDetected => _faceDetected;

  double? _faceRatioValue;
  double? get faceRatioValue => _faceRatioValue;

  double _ratioProgress = 0.0;
  DateTime? _lastFaceTs;

  /// القيمة المقروءة من الشاشة (0..1)
  double get ratioProgress => _ratioProgress;

  /// تحديث داخلي
  set _setRatioProgress(double v) {
    _ratioProgress = v.clamp(0.0, 1.0);
    notifyListeners();
  }


  int _frameCount = 0;
  int _detectCounter = 0;

  double? _brightnessLevel; // 0..255
  double? get brightnessLevel => _brightnessLevel;
  String? _brightnessStatus;
  String? get brightnessStatus => _brightnessStatus;

  int? _countdown;
  int? get countdown => _countdown;

  bool get isCountdownActive => _countdown != null && _countdown! > 0;
  bool _isSnapshotting = false;

  Map<String, dynamic>? _livenessResult;
  Map<String, dynamic>? get livenessResult => _livenessResult;

  Map<String, dynamic>? _faceRecognitionResult;
  Map<String, dynamic>? get faceRecognitionResult => _faceRecognitionResult;

  XFile? _capturedFile;
  XFile? get capturedFile => _capturedFile;

  // For painters
  Rect? _lastFaceRect;
  Rect? get lastFaceRect => _lastFaceRect;

  Size? _latestImageSize;
  Size? get latestImageSize => _latestImageSize;

  bool _insideOval = false;
  bool get insideOval => _insideOval;

  bool _readyForNextImage = true;
  bool _isStreaming = false;
  bool _streamLock = false;

  // Screensaver / inactivity
  Timer? _inactivityTimer;
  Timer? _inactivityTicker;
  int? _screensaverCountdown;
  int? get screensaverCountdown => _screensaverCountdown;

  bool _showScreensaver = false;
  bool get showScreensaver => _showScreensaver;

  // Clock animation for screensaver
  final List<String> _clockPositions = ['center', 'right', 'left'];
  int _clockPosIndex = 0;
  int get clockPosIndex => _clockPosIndex;

  Timer? _clockMoveTimer;
  bool _clockBlink = false;
  bool get clockBlink => _clockBlink;

  Timer? _clockBlinkTimer;
  DateTime _now = DateTime.now();
  DateTime get now => _now;
  Timer? _nowTicker;

  // Layout-dependent
  Size _screenSize = Size.zero;
  set screenSize(Size s) => _screenSize = s;

  double _estimateLuma(CameraImage image) {
    // نختار قناة مضيئة حسب فورمات الصورة
    final group = image.format.group;

    // خطوات أخذ عينة خفيفة
    final stepY = math.max(1, image.height ~/ 36);
    final stepX = math.max(1, image.width  ~/ 64);

    int sum = 0, count = 0;

    if (group == ImageFormatGroup.bgra8888) {
      // iOS غالباً — Plane واحد BGRA (4 بايت/بكسل)
      final p = image.planes[0];
      final bytes = p.bytes;
      final stride = p.bytesPerRow; // 4*width أو أكبر

      for (int r = 0; r < image.height; r += stepY) {
        final rowStart = r * stride;
        for (int c = 0; c < image.width; c += stepX) {
          final idx = rowStart + c * 4;
          final b = bytes[idx];
          final g = bytes[idx + 1];
          final r8 = bytes[idx + 2];
          // تحويل إلى الإضاءة التقريبية (BT.601)
          final luma = ((299 * r8 + 587 * g + 114 * b) / 1000).round(); // 0..255
          sum += luma; count++;
        }
      }
    } else {
      // Android NV21/YUV420 — أول plane هو Y (إضاءة مباشرة)
      final yPlane = image.planes.first;
      final bytes = yPlane.bytes;
      final stride = yPlane.bytesPerRow;

      for (int r = 0; r < image.height; r += stepY) {
        final rowStart = r * stride;
        for (int c = 0; c < image.width; c += stepX) {
          sum += bytes[rowStart + c]; // قيمة Y جاهزة 0..255
          count++;
        }
      }
    }

    if (count == 0) return 0.0;
    return sum / count; // 0..255
  }


  String _statusForLuma(double v) {
    if (v < 30)  return "Very dark ❌";
    if (v < 60)  return "Too dim ❌";
    if (v < 100) return "Dim light ⚠️";
    if (v < 160) return "Good lighting ✅";
    if (v < 220) return "Excellent lighting 🌟";
    return "Too bright ⚠️";
  }

  // Lifecycle
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _initDetector();
    _resetInactivity();
    _nowTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_showScreensaver) {
        _now = DateTime.now();
        notifyListeners();
      }
    });
    await _initCamera();
  }

  Future<void> disposeAll() async {
    WidgetsBinding.instance.removeObserver(this);
    _stopEverything();
    await _disposeCamera();
    _detector?.close();
    _detector = null;
    super.dispose();
  }

  // Handle app pause/resume
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_controller == null) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      await _stopStreamSafely();
    } else if (state == AppLifecycleState.resumed) {
      if (!_showScreensaver) await _startStreamSafely();
    }
  }

  // ===== Init parts =====
  void _initDetector() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableContours: false,
        enableLandmarks: false,
        enableClassification: false,
        enableTracking: false,
      ),
    );
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _frontCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(
      _frontCamera!,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _controller!.initialize();
    await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

    _latestImageSize = Size(
      _controller!.value.previewSize?.width ?? 1280,
      _controller!.value.previewSize?.height ?? 720,
    );

    _controller!.addListener(() async {
      final v = _controller!.value;
      if (v.hasError) {
        await _stopStreamSafely();
        await _startStreamSafely();
      }
    });

    await _startStreamSafely();
    notifyListeners();
  }

  Future<void> _disposeCamera() async {
    try {
      if (_controller != null) {
        await _stopStreamSafely();
        await _controller!.dispose();
      }
    } catch (_) {}
    _controller = null;
  }

  // ===== Inactivity / screensaver =====
  void _resetInactivity() {
    _inactivityTimer?.cancel();
    _inactivityTicker?.cancel();
    _screensaverCountdown = kScreensaverSeconds;

    _inactivityTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_showScreensaver) {
        if (_screensaverCountdown != null && _screensaverCountdown! > 0) {
          _screensaverCountdown = _screensaverCountdown! - 1;
          notifyListeners();
        }
      }
    });

    _inactivityTimer = Timer(Duration(seconds: kScreensaverSeconds), () async {
      _showScreensaver = true;
      _cameraOpen = false;
      notifyListeners();
      await _disposeCamera();
      _startClockMover();
    });

    _screensaverCountdown = kScreensaverSeconds;
    notifyListeners();
  }

  void userActivity() {
    if (_showScreensaver) return; // تجاهل أثناء شاشة التوقف حتى نقر العودة
    _resetInactivity();
  }

  void _startClockMover() {
    _clockMoveTimer?.cancel();
    _clockMoveTimer = Timer.periodic(const Duration(milliseconds: kClockDwellMs), (_) {
      _clockBlink = true;
      notifyListeners();
      _clockBlinkTimer?.cancel();
      _clockBlinkTimer = Timer(const Duration(milliseconds: 70), () {
        _clockPosIndex = (_clockPosIndex + 1) % _clockPositions.length;
        _clockBlink = false;
        notifyListeners();
      });
    });
  }

  Future<void> exitScreensaverAndReopen() async {
    _showScreensaver = false;
    _cameraOpen = true;
    _capturedFile = null;
    _livenessResult = null;
    _faceRecognitionResult = null;
    _stopCountdown(force: true);
    _isSnapshotting = false;
    _isDetecting = false;
    _readyForNextImage = true;
    _faceDetected = false;
    _faceRatioValue = null;
    _ratioProgress = 0.0;
    _brightnessLevel = null;
    _brightnessStatus = null;
    _detectCounter = 0;
    _lastFaceRect = null;
    _insideOval = false;

    await _initCamera();
    _resetInactivity();
    notifyListeners();
  }

  // ===== Stream control =====
  Future<void> _startStreamSafely() async {
    if (_controller == null) return;
    if (_streamLock) return;
    if (_controller!.value.isStreamingImages || _isStreaming) return;
    if (!_controller!.value.isInitialized) return;
    try {
      _streamLock = true;
      await _controller!.startImageStream(_onNewCameraImage);
      _isStreaming = true;
    } catch (_) {
    } finally {
      _streamLock = false;
    }
  }

  Future<void> _stopStreamSafely() async {
    if (_controller == null) return;
    if (_streamLock) return;
    if (!_controller!.value.isStreamingImages && !_isStreaming) return;
    try {
      _streamLock = true;
      await _controller!.stopImageStream();
    } catch (_) {
    } finally {
      _isStreaming = false;
      _streamLock = false;
    }
  }

  Future<void> _resumeLivePreview() async {
    _capturedFile = null;
    _livenessResult = null;
    _faceRecognitionResult = null;
    _cameraOpen = true;
    _isSnapshotting = false;
    _readyForNextImage = true;
    _insideOval = false;
    _ratioProgress = 0.0;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 120));
    await _startStreamSafely();
  }

  // ===== Core vision loop =====
  Future<void> _onNewCameraImage(CameraImage image) async {
    if (!_readyForNextImage || !_cameraOpen) return;
    _readyForNextImage = false;

    _latestImageSize = Size(image.width.toDouble(), image.height.toDouble());


    _frameCount = (_frameCount + 1) % kBrightnessSampleEveryN;
    if (_frameCount == 0) {
      final luma = _estimateLuma(image);     // 0..255
      _brightnessLevel = luma;
      _brightnessStatus = _statusForLuma(luma);
      debugPrint('LUMA=${_brightnessLevel?.toStringAsFixed(1)} | ${_brightnessStatus}');

      notifyListeners(); // مهم جداً
    }

    // Decimate detection
    _detectCounter = (_detectCounter + 1) % kDetectEveryN;
    if (_detectCounter != 0) {
      _readyForNextImage = true;
      return;
    }
    if (_isDetecting) {
      _readyForNextImage = true;
      return;
    }
    _isDetecting = true;

    try {
      final inputImage = _toInputImage(image);
      final faces = await _detector!.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        final rect = face.boundingBox; // portrait space
        _lastFaceRect = rect;

        final rawW = image.width.toDouble();
        final rawH = image.height.toDouble();
        final faceArea = rect.width * rect.height;
        final frameArea = rawW * rawH;
        final faceRatio = frameArea > 0 ? faceArea / frameArea : 0.0;
        _faceRatioValue = faceRatio;

        final target = (faceRatio / (kMinFaceRatio * kFitRelaxFactor)).clamp(0.0, 1.0);
        _ratioProgress = ui.lerpDouble(_ratioProgress, target, 0.18)!;

        _insideOval = _isFaceInsideOvalOnScreen(
          faceCenter: rect.center,
          imageRawSize: Size(rawW, rawH),
          screenSize: _screenSize,
          isFront: _frontCamera?.lensDirection == CameraLensDirection.front,
        );

        _updateFaceDetected(faceRatio >= kMinFaceRatio);

        if (_faceDetected && _insideOval && _ratioProgress >= 0.99) {
          _beginCountdown();
        } else {
          _stopCountdown();
        }
      } else {
        _lastFaceRect = null;
        _insideOval = false;
        _updateFaceDetected(false);
        _stopCountdown();
      }
    } catch (_) {
      // swallow
    } finally {
      _isDetecting = false;
      _readyForNextImage = true;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 2));
    }
  }

  bool _isFaceInsideOvalOnScreen({
    required Offset faceCenter,
    required Size imageRawSize,
    required Size screenSize,
    required bool? isFront,
  }) {
    if (screenSize == Size.zero) return false;
    final srcW = imageRawSize.height; // portrait width
    final srcH = imageRawSize.width;  // portrait height

    final scale = math.max(screenSize.width / srcW, screenSize.height / srcH);
    final dx = (screenSize.width - srcW * scale) / 2.0;
    final dy = (screenSize.height - srcH * scale) / 2.0;

    double cxOnScreen = faceCenter.dx * scale + dx;
    final double cyOnScreen = faceCenter.dy * scale + dy;

    if (isFront == true) {
      final midX = screenSize.width / 2;
      cxOnScreen = 2 * midX - cxOnScreen;
    }

    final ovalCx = screenSize.width * (0.5 + kOvalCxOffsetPct);
    final ovalCy = screenSize.height * (0.5 + kOvalCyOffsetPct);
    final ovalRx = (screenSize.width * kOvalRxPct) * kOvalInsideEpsilon;
    final ovalRy = (screenSize.height * kOvalRyPct) * kOvalInsideEpsilon;

    final dxn = (cxOnScreen - ovalCx) / (ovalRx == 0 ? 1 : ovalRx);
    final dyn = (cyOnScreen - ovalCy) / (ovalRy == 0 ? 1 : ovalRy);
    return (dxn * dxn + dyn * dyn) <= 1.0;
  }

  void _updateFaceDetected(bool detected) {
    if (detected == _faceDetected) return;
    _faceDetected = detected;
    if (!detected) {
      _ratioProgress = ui.lerpDouble(_ratioProgress, 0.0, 0.12)!;
    } else {
      if (!_isSnapshotting) {
        _livenessResult = null;
        _faceRecognitionResult = null;
        _capturedFile = null;
      }
      _resetInactivity();
    }
  }

  void _beginCountdown() {
    if (_isSnapshotting || !_cameraOpen) return;
    if (isCountdownActive) return;
    _countdown = kCountdownSeconds;

    Timer.periodic(const Duration(seconds: 1), (Timer t) async {
      if (_showScreensaver) { t.cancel(); return; }
      if (!_insideOval || !_faceDetected) { _stopCountdown(); t.cancel(); return; }
      if (_isSnapshotting) { t.cancel(); return; }

      if (_countdown != null && _countdown! > 0) {
        _countdown = _countdown! - 1;
        notifyListeners();
        if (_countdown == 0) {
          _countdown = 0;
          _isSnapshotting = true;
          notifyListeners();
          t.cancel();
          scheduleMicrotask(() async { await _handleLivenessCheck(); });
        }
      }
    });
    notifyListeners();
  }

  void _stopCountdown({bool force = false}) {
    if (_isSnapshotting && !force) return;
    _countdown = null;
    notifyListeners();
  }

  // ===== Capture & backend =====
  Future<void> _handleLivenessCheck() async {
    if (!_insideOval || !_faceDetected) {
      _isSnapshotting = false;
      _readyForNextImage = true;
      _stopCountdown(force: true);
      await _startStreamSafely();
      return;
    }

    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      _readyForNextImage = false;
      _isDetecting = false;
      await _stopStreamSafely();
      await Future.delayed(const Duration(milliseconds: 80));

      if (!_insideOval || !_faceDetected) {
        _isSnapshotting = false;
        _readyForNextImage = true;
        _stopCountdown(force: true);
        await _startStreamSafely();
        return;
      }

      final file = await _controller!.takePicture();
      _capturedFile = file;
      _lastFaceRect = null;
      notifyListeners();

      final liveJson = await _net.sendLiveness(file.path);
      _livenessResult = liveJson ?? {'error': 'Invalid response'};
      notifyListeners();

      if (kEnableFaceRecognition) {
        final recog = await _net.sendFaceRecognition(file.path);
        print('recoRequest{$recog}');
        _faceRecognitionResult = recog ?? {'error': 'Invalid response'};
        notifyListeners();
      }
      Timer(const Duration(milliseconds: kDisplayImageMs), () async {
        if (_showScreensaver) return;
        await _resumeLivePreview();
      });
    } catch (_) {
      _livenessResult = {'error': 'Error sending image to backend!'};
      notifyListeners();
    } finally {
      _isSnapshotting = false;
      _readyForNextImage = true;
    }
  }

  // ===== Helpers =====
  InputImage _toInputImage(CameraImage image) {
    final bytes = _concatenatePlanes(image.planes);
    final rotation = _rotationIntToImageRotation(
      _controller?.description.sensorOrientation ?? 0,
    );
    final inputFormat = (image.format.group == ImageFormatGroup.nv21)
        ? InputImageFormat.nv21
        : InputImageFormat.yuv420;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: inputFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void _stopEverything() {
    _inactivityTimer?.cancel();
    _inactivityTicker?.cancel();
    _clockMoveTimer?.cancel();
    _clockBlinkTimer?.cancel();
    _nowTicker?.cancel();
  }

  void _decayRatio() {
    // إن ما في وجه، خفّض المؤشر تدريجياً نحو الصفر
    const decay = 0.85;
    _setRatioProgress = _ratioProgress * decay;

    if (_ratioProgress < 0.005) {
      _setRatioProgress = 0.0;
    }
  }
  void _updateRatio(Rect faceRect, Size imageSize) {
    // ✅ نقيس “قُطر” الوجه بالنسبة لأقصر بُعد في الصورة (مقياس لا يتأثر بالاتجاه)
    final imgShort = math.min(imageSize.width, imageSize.height);
    final faceShort = math.min(faceRect.width, faceRect.height);

    // كلما اقترب الوجه يكبر faceShort ⇒ تزيد النسبة
    final raw = (faceShort / imgShort).clamp(0.0, 1.0);

    // 🎯 الهدف الذي نعتبره "ممتاز" للالتقاط (اضبطه حسب تصميمك/البيضاوي)
    const target = 0.22; // جرّب بين 0.18 ~ 0.26

    // حوّل إلى 0..1 (أعلى من الهدف يُقص للمحافظة على 1.0)
    final targetProgress = (raw / target).clamp(0.0, 1.0);

    // 🫧 تنعيم للاستقرار (0.15..0.30 حسب ذوقك)
    const smooth = 0.22;
    _setRatioProgress = _ratioProgress + (targetProgress - _ratioProgress) * smooth;

    notifyListeners();
  }

  void _onFacesDetected(List<Face> faces, Size imageSize) {
    if (faces.isEmpty) {
      // لو لا يوجد وجه: قلل المؤشر تدريجياً نحو الصفر
      _lastFaceTs = null;
      _decayRatio();
      return;
    }

    // خذ أكبر وجه (أقرب واحد للكاميرا عادةً)
    final face = faces.reduce((a, b) =>
    (a.boundingBox.width * a.boundingBox.height) >
        (b.boundingBox.width * b.boundingBox.height) ? a : b);

    _lastFaceTs = DateTime.now();
    _updateRatio(face.boundingBox, imageSize);
  }
  // Public actions
  Future<void> tapNextEmployee() async => _resumeLivePreview();
}
