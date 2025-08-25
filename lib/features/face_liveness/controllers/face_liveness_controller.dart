// =============================
// File: lib/features/face_liveness/controller/face_liveness_controller.dart
// =============================
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../constants.dart';
import '../services/network_service.dart';

class FaceLivenessController extends ChangeNotifier with WidgetsBindingObserver {
  // ===== Dependencies / Services =====
  final LivenessNetworkService _net = LivenessNetworkService();

  DateTime? _lastBlendTs;

  // ===== Camera =====
  CameraController? _controller;
  CameraController? get controller => _controller;
  CameraDescription? _frontCamera;

  // ===== Detector =====
  FaceDetector? _detector;
  bool _isDetecting = false;

  // ===== State =====
  bool _cameraOpen = true;
  bool get cameraOpen => _cameraOpen;

  bool _faceDetected = false;
  bool get faceDetected => _faceDetected;

  double _ratioProgress = 0.0;
  double get ratioProgress => _ratioProgress;

  bool _centeredInOval = false;
  bool get centeredInOval => _centeredInOval;

  double _centerScore = 0.0; // 0..1
  double get centerScore => _centerScore;

  Offset? _centerOffsetPx;
  Offset? get centerOffsetPx => _centerOffsetPx;

  bool _captureEligible = false;
  bool get captureEligible => _captureEligible;

  void _setCaptureEligible(bool v) {
    if (_captureEligible == v) return;
    _captureEligible = v;
    debugPrint('[ELIGIBLE -> ${v ? 'YES' : 'NO'}]');
    notifyListeners();
  }

  set _setRatioProgress(double v) {
    _ratioProgress = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  // قياسات الإضاءة
  int _frameCount = 0;
  int _detectCounter = 0;
  double? _brightnessLevel; // 0..255
  double? get brightnessLevel => _brightnessLevel;
  String? _brightnessStatus;
  String? get brightnessStatus => _brightnessStatus;

  // العد التنازلي
  int? _countdown;
  int? get countdown => _countdown;
  bool get isCountdownActive => _countdown != null && _countdown! > 0;
  bool _isSnapshotting = false;

  // النتائج
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

  // Clock
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

  // ==== إعدادات الحجم ====
  final FaceSizeThresholds _sizeCfg;
  FaceLivenessController({FaceSizeThresholds? sizeCfg})
      : _sizeCfg = sizeCfg ?? FaceSizeThresholds.defaults;

  // حجم الوجه النسبي (يُحدّث كل إطار)
  double? _sizeRaw;
  double? get sizeRawLive => _sizeRaw;

  // ==== تقدير المسافة (تقريبي) ====
  static const double _kIdealDistanceCm = 22.0;

  double? get estDistanceCm {
    final s = _sizeRaw;
    if (s == null || s <= 0) return null;
    return _kIdealDistanceCm * (_sizeCfg.rawIdeal / s);
  }

  double? get deltaToIdealCm {
    final d = estDistanceCm;
    if (d == null) return null;
    return d - _kIdealDistanceCm;
  }

  double? get deltaToRangeCm {
    final s = _sizeRaw;
    if (s == null || s <= 0) return null;
    if (s >= _sizeCfg.rawMin && s <= _sizeCfg.rawMax) return 0.0;

    final dNow = estDistanceCm!;
    if (s < _sizeCfg.rawMin) {
      final dWant = _kIdealDistanceCm * (_sizeCfg.rawIdeal / _sizeCfg.rawMin);
      return dNow - dWant; // موجبة => اقترب
    }
    final dWant = _kIdealDistanceCm * (_sizeCfg.rawIdeal / _sizeCfg.rawMax);
    return dNow - dWant; // موجبة => ابتعد
  }

  bool get tooFar => _sizeRaw != null && _sizeRaw! < _sizeCfg.rawMin;
  bool get tooClose => _sizeRaw != null && _sizeRaw! > _sizeCfg.rawMax;

  double get fitPct => (_ratioProgress.clamp(0.0, 1.0)) * 100.0;

  // ===== Lifecycle =====
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
    });

    _screensaverCountdown = kScreensaverSeconds;
    notifyListeners();
  }

  void userActivity() {
    if (_showScreensaver) return;
    _resetInactivity();
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
    _ratioProgress = 0.0;
    _brightnessLevel = null;
    _brightnessStatus = null;
    _detectCounter = 0;
    _lastFaceRect = null;
    _insideOval = false;
    _sizeRaw = null;
    _setCaptureEligible(false);
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

    // قياس الإضاءة كل N إطار
    _frameCount = (_frameCount + 1) % kBrightnessSampleEveryN;
    if (_frameCount == 0) {
      final luma = _estimateLuma(image);
      _brightnessLevel = luma;
      _brightnessStatus = _statusForLuma(luma);
      notifyListeners();
    }

    // تقليل كلفة الكشف
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

      // ✅ إصلاح التدفق: استخدم if/else وليس if + if + else
      if (faces.isEmpty) {
        _lastFaceRect = null;
        _insideOval = false;
        _sizeRaw = null;
        _updateFaceDetected(false);
        _collapseProgressFast(factor: 0.35);
        _stopCountdown();
      } else {
        // اختر أكبر وجه
        final face = faces.reduce((a, b) =>
        (a.boundingBox.width * a.boundingBox.height) >
            (b.boundingBox.width * b.boundingBox.height) ? a : b);

        final rect = face.boundingBox;
        _lastFaceRect = rect;

        final rawW = image.width.toDouble();
        final rawH = image.height.toDouble();

        final bool isFront =
            _frontCamera?.lensDirection == CameraLensDirection.front;

        // داخل/مركز البيضاوي
        _insideOval = _isFaceInsideOvalOnScreen(
          faceCenter: rect.center,
          imageRawSize: Size(rawW, rawH),
          screenSize: _screenSize,
          isFront: isFront,
        );

        _centeredInOval = _isFaceCenteredInOvalOnScreen(
          faceCenter: rect.center,
          imageRawSize: Size(rawW, rawH),
          screenSize: _screenSize,
          isFront: isFront,
        );

        final imgShort = math.min(rawW, rawH);
        final faceShort = math.min(rect.width, rect.height);
        final double sizeRaw = (imgShort == 0 ? 0.0 : faceShort / imgShort);
        _sizeRaw = sizeRaw;

        final double sizeFactor = _sizeScoreWindowed(sizeRaw);
        final double posFactor = _positionFactor(
          faceCenterRaw: rect.center,
          imageRawSize: Size(rawW, rawH),
          screenSize: _screenSize,
          isFront: isFront,
        );

        // تقدّم شريط الملاءمة
        final inFrame = _insideOval || _centerScore >= 0.22; // تساهل بسيط
        if (!inFrame || posFactor == 0.0) {
          _setRatioProgress = 0.0;
        } else {
          final double targetProgress = (sizeFactor * posFactor).clamp(0.0, 1.0);
          _blendProgress(targetProgress, smooth: 0.22);
        }

        // اكتشاف الوجه
        _updateFaceDetected(sizeRaw >= _sizeCfg.rawMin * 0.75);

        debugPrint('Hakim{$sizeRaw}');
        debugPrint('rawMin: ${_sizeCfg.rawMin.toStringAsFixed(3)}');
        debugPrint('rawMax: ${_sizeCfg.rawMax.toStringAsFixed(3)}');
        // ✅ الأهلية تعتمد على (تمركز المركز + حجم ضمن النطاق)
        final bool eligible = _faceDetected
            && inFrame
            && sizeRaw >= _sizeCfg.rawMin
            && sizeRaw <= _sizeCfg.rawMax;

        _setCaptureEligible(eligible);

        if (eligible) {
          _beginCountdown();
        } else {
          _stopCountdown();
        }
      }
    } catch (_) {
      // تجاهل الأخطاء اللحظية
    } finally {
      _isDetecting = false;
      _readyForNextImage = true;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 2));
    }
  }

  // ===== تمركز/داخل البيضاوي (مُرخَّص) =====

  bool _isFaceCenteredInOvalOnScreen({
    required Offset faceCenter,
    required Size imageRawSize,
    required Size screenSize,
    required bool? isFront,
    double epsilonPct = kCenterEpsilonPct,
  }) {
    if (screenSize == Size.zero) {
      _centerScore = 0.0;
      _centerOffsetPx = null;
      return false;
    }

    final srcW = imageRawSize.height; // portrait width
    final srcH = imageRawSize.width;  // portrait height
    final scale = math.max(screenSize.width / srcW, screenSize.height / srcH);
    final dxPad = (screenSize.width  - srcW * scale) / 2.0;
    final dyPad = (screenSize.height - srcH * scale) / 2.0;

    double cx = faceCenter.dx * scale + dxPad;
    final double cy = faceCenter.dy * scale + dyPad;

    if (isFront == true) {
      final midX = screenSize.width / 2;
      cx = 2 * midX - cx;
    }

    final ovalCx = screenSize.width  * (0.5 + kOvalCxOffsetPct);
    final ovalCy = screenSize.height * (0.5 + kOvalCyOffsetPct);
    final ovalRx = (screenSize.width  * kOvalRxPct);
    final ovalRy = (screenSize.height * kOvalRyPct);

    final offXpx = cx - ovalCx;
    final offYpx = cy - ovalCy;
    _centerOffsetPx = Offset(offXpx, offYpx);

    final dxn = ovalRx == 0 ? 0.0 : offXpx / ovalRx;
    final dyn = ovalRy == 0 ? 0.0 : offYpx / ovalRy;

    final rAllow = epsilonPct.clamp(0.02, 0.9);
    final r = math.sqrt(dxn * dxn + dyn * dyn);

    _centerScore = (1.0 - (r / rAllow)).clamp(0.0, 1.0);
    return r <= rAllow;
  }

  // سماحية: 15% خارج الحد مقبولة، أو 3 زوايا من 4 داخل
  static const double _kEdgeOverflowTol = 0.15; // 15% خارج الحد
  static const double _kCornersNeeded = 3;      // 3 زوايا كفاية

  bool _isFaceInsideOvalOnScreen({
    required Offset faceCenter,
    required Size imageRawSize,
    required Size screenSize,
    required bool? isFront,
  }) {
    if (screenSize == Size.zero) return false;

    final srcW = imageRawSize.height;
    final srcH = imageRawSize.width;
    final scale = math.max(screenSize.width / srcW, screenSize.height / srcH);
    final dx = (screenSize.width - srcW * scale) / 2.0;
    final dy = (screenSize.height - srcH * scale) / 2.0;

    final faceRect = _lastFaceRect;
    if (faceRect == null) return false;

    final corners = <Offset>[
      faceRect.topLeft,
      faceRect.topRight,
      faceRect.bottomLeft,
      faceRect.bottomRight,
    ];

    final ovalCx = screenSize.width * (0.5 + kOvalCxOffsetPct);
    final ovalCy = screenSize.height * (0.5 + kOvalCyOffsetPct);
    final ovalRx = (screenSize.width * kOvalRxPct);
    final ovalRy = (screenSize.height * kOvalRyPct);

    int insideCount = 0;
    for (var point in corners) {
      double cx = point.dx * scale + dx;
      double cy = point.dy * scale + dy;

      if (isFront == true) {
        final midX = screenSize.width / 2;
        cx = 2 * midX - cx;
      }

      // مسافة مُطبَّعة لنقطة بالنسبة للبيضاوي
      final dxn = (cx - ovalCx) / ovalRx;
      final dyn = (cy - ovalCy) / ovalRy;
      final distance = dxn * dxn + dyn * dyn; // <= 1 داخل

      // اسمح بزيادة 15% خارج الحد
      if (distance <= (1.0 + _kEdgeOverflowTol)) insideCount++;
    }

    // أيضًا لو المركز داخل البيضاوي بزيادة سماحية نصفية
    final faceCxRaw = faceRect.center;
    double ccx = faceCxRaw.dx * scale + dx;
    double ccy = faceCxRaw.dy * scale + dy;
    if (isFront == true) {
      final midX = screenSize.width / 2;
      ccx = 2 * midX - ccx;
    }
    final cdxn = (ccx - ovalCx) / ovalRx;
    final cdyn = (ccy - ovalCy) / ovalRy;
    final centerInside = (cdxn * cdxn + cdyn * cdyn) <= (1.0 + _kEdgeOverflowTol * 0.5);

    return insideCount >= _kCornersNeeded || centerInside;
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

    userActivity();
    Timer.periodic(const Duration(seconds: 1), (Timer t) async {
      if (_showScreensaver) { t.cancel(); return; }
      if (!_captureEligible) { _stopCountdown(); t.cancel(); return; }
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
    if (!_captureEligible) {
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

      if (!_captureEligible) {
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

      if (kEnableLiveness) {
        final liveJson = await _net.sendLiveness(file.path);
        _livenessResult = liveJson ?? {'error': 'Invalid response'};
        notifyListeners();
      }

      if (kEnableFaceRecognition) {
        final recog = await _net.sendFaceRecognition(file.path);
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
    const decay = 0.85;
    _setRatioProgress = _ratioProgress * decay;
    if (_ratioProgress < 0.005) {
      _setRatioProgress = 0.0;
    }
  }

  void _updateRatio(Rect faceRect, Size imageSize) {
    final imgShort = math.min(imageSize.width, imageSize.height);
    final faceShort = math.min(faceRect.width, faceRect.height);
    final raw = (faceShort / imgShort).clamp(0.0, 1.0);

    const target = 0.22;
    final targetProgress = (raw / target).clamp(0.0, 1.0);

    const smooth = 0.22;
    _setRatioProgress =
        _ratioProgress + (targetProgress - _ratioProgress) * smooth;

    notifyListeners();
  }

  double _sizeScore(Rect faceRect, Size imageSize, {double target = 0.22}) {
    final imgShort = math.min(imageSize.width, imageSize.height);
    final faceShort = math.min(faceRect.width, faceRect.height);
    final raw = (faceShort / (imgShort == 0 ? 1 : imgShort)).clamp(0.0, 1.0);
    return (raw / target).clamp(0.0, 1.0);
  }

  double _smoothstep(double a, double b, double x) {
    if (a == b) return x >= b ? 1.0 : 0.0;
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  double _sizeScoreWindowed(double raw) {
    double sstep(double a, double b, double x) {
      if (a == b) return x >= b ? 1.0 : 0.0;
      final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    final up   = sstep(_sizeCfg.rawMin,   _sizeCfg.rawIdeal, raw);
    final down = 1.0 - sstep(_sizeCfg.rawIdeal, _sizeCfg.rawMax,   raw);
    final peak = math.min(up, down);
    return peak.clamp(0.0, 1.0);
  }

  double _positionFactor({
    required Offset faceCenterRaw,
    required Size imageRawSize,
    required Size screenSize,
    required bool isFront,
  }) {
    if (screenSize == Size.zero) return 0.0;

    final srcW = imageRawSize.height; // portrait width
    final srcH = imageRawSize.width;  // portrait height
    final scale = math.max(screenSize.width / srcW, screenSize.height / srcH);
    final dxPad = (screenSize.width  - srcW * scale) / 2.0;
    final dyPad = (screenSize.height - srcH * scale) / 2.0;

    double cx = faceCenterRaw.dx * scale + dxPad;
    final double cy = faceCenterRaw.dy * scale + dyPad;

    if (isFront) {
      final midX = screenSize.width / 2;
      cx = 2 * midX - cx;
    }

    final ovalCx = screenSize.width  * (0.5 + kOvalCxOffsetPct);
    final ovalCy = screenSize.height * (0.5 + kOvalCyOffsetPct);
    final ovalRx = (screenSize.width  * kOvalRxPct);
    final ovalRy = (screenSize.height * kOvalRyPct);

    final dxn = (cx - ovalCx) / (ovalRx == 0 ? 1 : ovalRx);
    final dyn = (cy - ovalCy) / (ovalRy == 0 ? 1 : ovalRy);
    final r = math.sqrt(dxn * dxn + dyn * dyn);

    if (r >= 1.0) return 0.0;

    const p = 1.4;
    return math.pow((1.0 - r), p).toDouble().clamp(0.0, 1.0);
  }

  // إعادة استخدام النسختين التي لديك:
  double? _lumaEma;
  double _estimateLuma(CameraImage image, {bool smooth = true}) {
    final group = image.format.group;
    final stepY = math.max(1, image.height ~/ 36);
    final stepX = math.max(1, image.width  ~/ 64);

    int sum = 0, count = 0;

    if (group == ImageFormatGroup.bgra8888) {
      final p = image.planes[0];
      final bytes = p.bytes;
      final stride = p.bytesPerRow;

      for (int r = 0; r < image.height; r += stepY) {
        final rowStart = r * stride;
        for (int c = 0; c < image.width; c += stepX) {
          final idx = rowStart + c * 4;
          if (idx + 2 >= bytes.length) continue;
          final b = bytes[idx];
          final g = bytes[idx + 1];
          final r8 = bytes[idx + 2];
          final l = ((299 * r8 + 587 * g + 114 * b) / 1000).round();
          sum += l; count++;
        }
      }
    } else {
      final y = image.planes.first;
      final bytes = y.bytes;
      final stride = y.bytesPerRow;

      for (int r = 0; r < image.height; r += stepY) {
        final rowStart = r * stride;
        for (int c = 0; c < image.width; c += stepX) {
          final idx = rowStart + c;
          if (idx >= bytes.length) continue;
          sum += bytes[idx];
          count++;
        }
      }
    }

    final raw = (count == 0) ? 0.0 : (sum / count);
    if (!smooth) return raw;
    final alpha = 0.25;
    _lumaEma = (_lumaEma == null) ? raw : (_lumaEma! + alpha * (raw - _lumaEma!));
    return _lumaEma!.clamp(0.0, 255.0);
  }

  String _statusForLuma(double v) {
    if (v <  30) return "Very dark ❌";
    if (v <  60) return "Too dim ❌";
    if (v < 100) return "Dim light ⚠️";
    if (v < 160) return "Good lighting ✅";
    if (v < 220) return "Excellent lighting 🌟";
    return "Too bright ⚠️";
  }

  void _blendProgress(double target, {double smooth = 0.22}) {
    target = target.clamp(0.0, 1.0);
    final now = DateTime.now();
    final dt = (_lastBlendTs == null)
        ? 1.0 / 60.0
        : (now.difference(_lastBlendTs!).inMilliseconds / 1000.0)
        .clamp(0.0, 0.25);
    _lastBlendTs = now;

    const double deadzone = 0.004;
    if ((target - _ratioProgress).abs() < deadzone) {
      _setRatioProgress = target;
      return;
    }

    final s = smooth.clamp(0.0, 0.99);
    final alpha = 1 - math.pow(1 - s, dt * 60.0);

    double desired = _ratioProgress + (target - _ratioProgress) * alpha;

    const double maxUnitsPerSec = 1.2;
    final double maxStep = maxUnitsPerSec * dt;
    final double step = (desired - _ratioProgress);
    if (step.abs() > maxStep) {
      desired = _ratioProgress + step.sign * maxStep;
    }

    if (desired > 0.995) desired = 1.0;
    if (desired < 0.005) desired = 0.0;

    _setRatioProgress = desired;
  }

  void _collapseProgressFast({double factor = 0.25}) {
    final f = factor.clamp(0.05, 0.95);
    double next = _ratioProgress * (1.0 - f);
    if (next < 0.02) next = 0.0;
    _setRatioProgress = next;
  }

  // Public
  Future<void> tapNextEmployee() async {
    _stopCountdown(force: true);
    _isSnapshotting = false;

    _livenessResult = null;
    _faceRecognitionResult = null;
    _capturedFile = null;
    _lastFaceRect = null;
    _sizeRaw = null;
    _ratioProgress = 0.0;
    _insideOval = false;
    _faceDetected = false;
    _setCaptureEligible(false);

    _showScreensaver = false;
    _cameraOpen = true;

    notifyListeners();

    if (_controller == null || !_controller!.value.isInitialized) {
      await _initCamera();
    } else {
      await _startStreamSafely();
    }
  }
}
