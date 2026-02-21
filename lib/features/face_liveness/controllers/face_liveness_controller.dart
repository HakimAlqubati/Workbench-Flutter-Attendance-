// =============================
// File: lib/features/face_liveness/controller/face_liveness_controller.dart
// =============================
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:my_app/core/network_helper.dart';
import 'package:my_app/features/attendance/attendance_service.dart';

// 1) التقط الصورة واعرضها فورًا
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../constants.dart';
import '../services/network_service.dart';


class FaceLivenessController extends ChangeNotifier with WidgetsBindingObserver {

  final ValueNotifier<String?> bannerMessage = ValueNotifier<String?>(null);

  void showBanner(String msg) {
    bannerMessage.value = msg;
  }

  void clearBanner() {
    bannerMessage.value = null;
  }

  Future<String?> Function()? onRequireType;

  // ===== Dependencies / Services =====
  final LivenessNetworkService _net = LivenessNetworkService();
  int _warmUpFrames = 0;

  VoidCallback? onLivenessFailed;

  DateTime? _lastBlendTs;

  Map<String, dynamic>? _attendanceResult;
  Map<String, dynamic>? get attendanceResult => _attendanceResult;


  // ===== Camera =====
  CameraController? _controller;
  CameraController? get controller => _controller;
  CameraDescription? _frontCamera;
  List<CameraDescription> _allCams = const [];


  bool _useFront = false; // ✅ الحالة الحالية: false = خلفية (افتراضياً)
  bool get isFrontCamera => _useFront;
  CameraDescription? _rearCamera;
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

  // ===== Waiting state (لشاشة الانتظار فوق الصورة) =====
  bool _waiting = false;
  bool get waiting => _waiting;

  int _captureSeq = 0;        // token متزايد لكل لقطة
  int? _activeCaptureSeq;     // token الحالي قيد الانتظار

  String _waitMessage = '';
  String get waitMessage => _waitMessage;

  bool get livenessPending =>
      kEnableLiveness && _waiting && (_livenessResult == null);
  bool get recognitionPending =>
      kEnableFaceRecognition && _waiting && (_faceRecognitionResult == null);

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

  // ===== حقل للحضور الآلي لمنع التكرار لكل لقطة =====
  bool _postedAttendanceForThisCapture = false;

  // اختيارية: لعرض رسالة آخر استدعاء API في الواجهة
  String? _lastApiMessage;
  String? get lastApiMessage => _lastApiMessage;
  bool _lastApiOk = false;
  bool get lastApiOk => _lastApiOk;

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

  Future<void> _startDisplayAndResume({required int seq}) async {
    // أبقِ الصورة معروضة لهذه المدة (حتى يقرأ المستخدم البانرات)
    await Future.delayed(Duration(milliseconds: kDisplayImageMs));

    // لا ترجع إذا تغيّر السياق أو تغيّر الـ token
    if (_showScreensaver) return;
    if (_activeCaptureSeq != seq) return;

    await _resumeLivePreview();
  }

  // زر التخطي من الواجهة
  Future<void> skipWaiting() async {
    if (!_waiting) return;
    final seq = _activeCaptureSeq;
    if (seq == null) return;
    _waiting = false;
    notifyListeners();
    await _startDisplayAndResume(seq: seq);
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
    // ✅ اجلب الكاميرات مرة واحدة
    _allCams = await availableCameras();

    // ✅ حارس: لا توجد كاميرات
    if (_allCams.isEmpty) {
      debugPrint('❌ No cameras available');
      return;
    }

    // ✅ عيّن الأمامية والخلفية مع orElse غير قابل لـ null
    _frontCamera = _allCams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _allCams.first, // non-null
    );
    _rearCamera = _allCams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _allCams.first, // non-null
    );

    // ✅ اختر الكاميرا الدافعة حسب العلم الحالي مع fallback منطقي
    final CameraDescription camToUse =
    _useFront ? (_frontCamera ?? _rearCamera!) : (_rearCamera ?? _frontCamera!);

    // ✅ أنشئ الكونترولر مرة واحدة فقط باستخدام الكاميرا المختارة
    _controller = CameraController(
      camToUse,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _controller!.initialize();
    await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

    // ✅ خزّن حجم الإطار الأخير
    _latestImageSize = Size(
      _controller!.value.previewSize?.width ?? 1280,
      _controller!.value.previewSize?.height ?? 720,
    );

    // ✅ مراقبة أخطاء المعاينة
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
    _attendanceResult = null;
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
    _resetInactivity();
    _capturedFile = null;
    _livenessResult = null;
    _faceRecognitionResult = null;
    _attendanceResult = null;
    _cameraOpen = true;
    _isSnapshotting = false;
    _readyForNextImage = true;
    _insideOval = false;
    _ratioProgress = 0.0;

    _warmUpFrames = 12; // ⬅️ تجاهل أول 12 إطار بعد الرجوع

    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 120));
    await _startStreamSafely();
  }

  // ===== Core vision loop =====
  Future<void> _onNewCameraImage(CameraImage image) async {
    if (_warmUpFrames > 0) {
      _warmUpFrames--;
      _readyForNextImage = true;
      return;
    }

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
            (b.boundingBox.width * b.boundingBox.height)
            ? a
            : b);

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
          final double targetProgress =
          (sizeFactor * posFactor).clamp(0.0, 1.0);
          _blendProgress(targetProgress, smooth: 0.22);
        }

        // اكتشاف الوجه
        _updateFaceDetected(sizeRaw >= _sizeCfg.rawMin * 0.75);

        debugPrint('Hakim{$sizeRaw}');
        debugPrint('rawMin: ${_sizeCfg.rawMin.toStringAsFixed(3)}');
        debugPrint('rawMax: ${_sizeCfg.rawMax.toStringAsFixed(3)}');
        final bool goodLighting = _brightnessStatus == 'Good lighting ✅' ||
            _brightnessStatus == 'Excellent lighting 🌟';

        // ✅ الأهلية تعتمد على (تمركز المركز + حجم ضمن النطاق)
        final bool eligible = _faceDetected &&
            _insideOval &&
            sizeRaw >= _sizeCfg.rawMin &&
            sizeRaw <= _sizeCfg.rawMax

            && goodLighting
        ;

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
    double epsilonPct = 0.05,
  }) {
    if (screenSize == Size.zero) {
      _centerScore = 0.0;
      _centerOffsetPx = null;
      return false;
    }

    final srcW = imageRawSize.height; // portrait width
    final srcH = imageRawSize.width; // portrait height
    final scale = math.max(screenSize.width / srcW, screenSize.height / srcH);
    final dxPad = (screenSize.width - srcW * scale) / 2.0;
    final dyPad = (screenSize.height - srcH * scale) / 2.0;

    double cx = faceCenter.dx * scale + dxPad;
    final double cy = faceCenter.dy * scale + dyPad;

    if (isFront == true) {
      final midX = screenSize.width / 2;
      cx = 2 * midX - cx;
    }

    final ovalCx = screenSize.width * (0.5 + kOvalCxOffsetPct);
    final ovalCy = screenSize.height * (0.5 + kOvalCyOffsetPct);
    final ovalRx = (screenSize.width * kOvalRxPct);
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
  static const double _kEdgeOverflowTol = 0.22; // 15% خارج الحد
  static const double _kCornersNeeded = 4; // 3 زوايا كفاية

  // استبدل دالة _isFaceInsideOvalOnScreen بالكامل بهذه (إزالة return المكرر غير القابل للوصول)
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

      final dxn = (cx - ovalCx) / ovalRx;
      final dyn = (cy - ovalCy) / ovalRy;
      final distance = dxn * dxn + dyn * dyn; // <= 1 داخل
      if (distance <= (1.0 + _kEdgeOverflowTol)) insideCount++;
    }

    // تحقُّق إضافي: مركز الوجه داخل البيضاوي مع سماحية نصفية
    final faceCxRaw = faceRect.center;
    double ccx = faceCxRaw.dx * scale + dx;
    double ccy = faceCxRaw.dy * scale + dy;
    if (isFront == true) {
      final midX = screenSize.width / 2;
      ccx = 2 * midX - ccx;
    }
    final cdxn = (ccx - ovalCx) / ovalRx;
    final cdyn = (ccy - ovalCy) / ovalRy;
    final centerInside =
        (cdxn * cdxn + cdyn * cdyn) <= (1.0 + _kEdgeOverflowTol * 0.5);

    return insideCount >= _kCornersNeeded && centerInside;
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
        _attendanceResult = null;
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
      if (_showScreensaver) {
        t.cancel();
        return;
      }
      if (!_captureEligible) {
        _stopCountdown();
        t.cancel();
        return;
      }
      if (_isSnapshotting) {
        t.cancel();
        return;
      }

      if (_countdown != null && _countdown! > 0) {
        _countdown = _countdown! - 1;
        notifyListeners();
        if (_countdown == 0) {
          _countdown = 0;
          _isSnapshotting = true;
          notifyListeners();
          t.cancel();
          scheduleMicrotask(() async {
            await _handleLivenessCheck();
          });
        }
      }
    });
    notifyListeners();
  }
  /// قص صورة داخل بيضاوي (Oval) حسب أبعاد الشاشة
  Future<File> cropToOval(File originalFile, Size screenSize, {double scale = 1.0}) async {
    final bytes = await originalFile.readAsBytes();
    final src = img.decodeImage(bytes)!;

    // أبعاد البيضاوي بالنسبة للصورة نفسها
    final ovalCx = src.width * (0.5 + kOvalCxOffsetPct);
    final ovalCy = src.height * (0.5 + kOvalCyOffsetPct);
    final ovalRx = src.width * kOvalRxPct;
    final ovalRy = src.height * kOvalRyPct;

    // المستطيل المحيط بالبيضاوي
    final left   = (ovalCx - ovalRx).clamp(0, src.width - 1).toInt();
    final top    = (ovalCy - ovalRy).clamp(0, src.height - 1).toInt();
    final right  = (ovalCx + ovalRx).clamp(0, src.width - 1).toInt();
    final bottom = (ovalCy + ovalRy).clamp(0, src.height - 1).toInt();

    // ✅ اجعلها مربعة
    int side = math.min(right - left, bottom - top);

    // ✅ طبّق التكبير/التصغير
    side = (side * scale).toInt().clamp(10, math.min(src.width, src.height));

    // ✅ قص مربع متمركز
    final squareLeft = (ovalCx - side / 2).clamp(0, src.width - side).toInt();
    final squareTop  = (ovalCy - side / 2).clamp(0, src.height - side).toInt();

    final croppedSquare = img.copyCrop(
      src,
      x: squareLeft,
      y: squareTop,
      width: side,
      height: side,
    );

    // حفظ الصورة
    final croppedPath = originalFile.path.replaceFirst('.jpg', '_square.jpg');
    final croppedFile = File(croppedPath)
      ..writeAsBytesSync(img.encodeJpg(croppedSquare, quality: 95));

    return croppedFile;
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

    // token لهذه اللقطة
    final int seq = ++_captureSeq;
    _activeCaptureSeq = seq;

    _postedAttendanceForThisCapture = false;

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

      // 1️⃣ التقط الصورة
      final XFile captured = await _controller!.takePicture();

      // 2️⃣ انسخ الصورة للمجلد الخاص بالتطبيق
      final Directory dir = await getApplicationDocumentsDirectory();
      final Directory folder = Directory(path.join(dir.path, 'liveness_captures'));
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      final String filename = 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String savedPath = path.join(folder.path, filename);
      final File savedFile = await File(captured.path).copy(savedPath);

      // ✂️ قص الصورة بالبيضاوي
      final File ovalFile = await cropToOval(savedFile, _screenSize,scale: kCropScale);

      // 3️⃣ حفظ الصورة المقصوصة في المعرض (اختياري)
      // await GallerySaver.saveImage(ovalFile.path, albumName: 'LivenessCaptures');

      // ✅ اعتمد الصورة المقصوصة فقط
      _capturedFile = XFile(ovalFile.path);

      // (اختياري) احتفظ بنسخة في مجلد التطبيق
      final String ovalSavedPath = path.join(folder.path, 'oval_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(ovalFile.path).copy(ovalSavedPath);

      // إعادة ضبط الحالة
      _lastFaceRect = null;
      _livenessResult = null;
      _faceRecognitionResult = null;
      _attendanceResult = null;
      _resetInactivity();

      _waiting = true;
      _waitMessage = '';
      notifyListeners();

      // إرسال المهام (liveness + recognition)
      final futures = <Future<void>>[];

      if (kEnableLiveness) {
        final connected = await NetworkHelper.checkAndToastConnection();
        if (!connected) {
          _livenessResult = {'error': 'Check Your Internet Connection'};
          _waiting = false;
          notifyListeners();
          return;
        }
        futures.add(
          _net.sendLiveness(ovalFile.path).then((liveJson) {
            if (_activeCaptureSeq != seq) return;
            _livenessResult = liveJson ?? {'error': 'Invalid response'};
            notifyListeners();
          }).catchError((e) {
            if (_activeCaptureSeq != seq) return;
            _livenessResult = {'error': e.toString()};
            notifyListeners();
          }),
        );
      }

      await Future.wait(futures);
      if (kEnableFaceRecognition  &&
          _livenessResult != null &&
          _livenessResult?['status'] == 'ok' &&
          _livenessResult?['result']?['liveness'] == true) {
        final connected = await NetworkHelper.checkAndToastConnection();
        if (!connected) return;

        futures.add(
          _net.sendFaceRecognition(ovalFile.path).then((recog) async {
            if (_activeCaptureSeq != seq) return;
            _faceRecognitionResult = recog ?? {'error': 'Invalid response'};
            notifyListeners();
          }).catchError((e) {
            if (_activeCaptureSeq != seq) return;
            _faceRecognitionResult = {'error': e.toString()};
            notifyListeners();
          }),
        );
      }

      // Soft timeout
      Future.delayed(Duration(milliseconds: kSoftTimeoutMs), () {
        if (_activeCaptureSeq == seq && _waiting) {
          _waitMessage = 'Taking longer than usual…';
          notifyListeners();
        }
      });

      await Future.wait(futures);

      await _maybeAutoPostAttendance();

      if (_activeCaptureSeq == seq) {
        _waiting = false;
        notifyListeners();
        await _startDisplayAndResume(seq: seq);
      }
    } catch (_) {
      _livenessResult ??= {'error': 'Error sending image to backend!'};
      _waiting = false;
      notifyListeners();
      await _startDisplayAndResume(seq: _activeCaptureSeq ?? ++_captureSeq);
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

    final up = sstep(_sizeCfg.rawMin, _sizeCfg.rawIdeal, raw);
    final down = 1.0 - sstep(_sizeCfg.rawIdeal, _sizeCfg.rawMax, raw);
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
    final srcH = imageRawSize.width; // portrait height
    final scale = math.max(screenSize.width / srcW, screenSize.height / srcH);
    final dxPad = (screenSize.width - srcW * scale) / 2.0;
    final dyPad = (screenSize.height - srcH * scale) / 2.0;

    double cx = faceCenterRaw.dx * scale + dxPad;
    final double cy = faceCenterRaw.dy * scale + dyPad;

    if (isFront) {
      final midX = screenSize.width / 2;
      cx = 2 * midX - cx;
    }

    final ovalCx = screenSize.width * (0.5 + kOvalCxOffsetPct);
    final ovalCy = screenSize.height * (0.5 + kOvalCyOffsetPct);
    final ovalRx = (screenSize.width * kOvalRxPct);
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
    final stepX = math.max(1, image.width ~/ 64);

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
          sum += l;
          count++;
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
    _lumaEma =
    (_lumaEma == null) ? raw : (_lumaEma! + alpha * (raw - _lumaEma!));
    return _lumaEma!.clamp(0.0, 255.0);
  }

  String _statusForLuma(double v) {
    if (v < 30) return "Very dark ❌";
    if (v < 60) return "Too dim ❌";
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

    // نظّف النتائج والبيانات
    _livenessResult = null;
    _faceRecognitionResult = null;
    _attendanceResult = null;
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

    // ✅ بدل ما نعيد init كل مرة:
    if (_controller == null) {
      // أول مرة فقط أو لو فعلاً اختفت الكاميرا
      await _initCamera();
    } else if (_controller!.value.isInitialized) {
      // الكاميرا جاهزة → بس استأنف البث
      await _startStreamSafely();
    } else {
      // حالة نادرة: عندنا controller لكن مو مهيأ
      try {
        await _controller!.initialize();
        await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
        await _startStreamSafely();
      } catch (e) {
        // fallback لو فشل → إعادة init كاملة
        await _initCamera();
      }
    }
  }

  // ======= 💡 استدعاء الحضور تلقائيًا عند توفر employee_id   =======
  Future<void> _maybeAutoPostAttendance() async {
    if (_postedAttendanceForThisCapture) {
      debugPrint('[ATT] Skipped: already posted for this capture.');
      return;
    }

    final recog = _faceRecognitionResult;
    if (recog == null) {
      debugPrint('[ATT] Skipped: no faceRecognitionResult yet.');
      return;
    }

    // لطباعة الاستجابة كما هي للمراجعة
    debugPrint('[FR][RAW] $recog');


    // ==== Helpers محلية لاستخراج القيم بأمان ====
    dynamic _get(Map m, List path) {
      dynamic cur = m;
      for (final k in path) {
        if (cur is Map && cur.containsKey(k)) {
          cur = cur[k];
        } else {
          return null;
        }
      }
      return cur;
    }

    int? _asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      if (v is num) return v.toInt();
      return null;
    }

    String? _asStr(dynamic v) {
      if (v == null) return null;
      if (v is String) return v.trim().isEmpty ? null : v.trim();
      if (v is num) return v.toString();
      return null;
    }

    // ==== جرّب جميع المسارات الشائعة ====
    final Map<String, dynamic> R = Map<String, dynamic>.from(recog);

    final employeeId = _asInt(
        _get(R, ['employee_id']) ??
            _get(R, ['match', 'employee_id']) ??
            _get(R, ['match', 'employee', 'id']) ??
            _get(R, ['match', 'employee_data', 'id'])
    );




    if (employeeId == null) {
      debugPrint('[ATT] Skipped: neither employee_id  found in recog.');
      return;
    }

    final nowStr = formatDateTime(DateTime.now());
    // final nowStr = formatDateTime(DateTime.parse("2026-02-12 12:55:00"));

    try {
      ApiResult result;
      if (employeeId == null) {
        debugPrint('[ATT] Skip: employee_id is null, not posting attendance.');
        return;
      }

      result = await AttendanceService.storeByEmployeeId(
        employeeId: employeeId,
        dateTime: nowStr,
      );


// خزّن رسالة الرد الأولى (قد تحتوي "please specify type")
      final String firstMessage = (result.message ?? '').toString().trim();

// ✅ لو السيرفر طلب type → افتح المودال
      if (result.needType == true) {
        final String? picked = await (onRequireType?.call());

        if (picked != null) {
          // إعادة الإرسال مع النوع المختار
          result = await AttendanceService.storeByEmployeeId(
            employeeId: employeeId,
            dateTime: nowStr,
            type: picked,
          );
        } else {
          // المستخدم أغلق المودال → اطبع رسالة السيرفر كما هي (أو بديل)
          _attendanceResult = {
            'status': 'error',
            'message': firstMessage.isNotEmpty ? firstMessage : 'Type not selected',
          };
          _postedAttendanceForThisCapture = true;
          _lastApiOk = false;
          _lastApiMessage = _attendanceResult!['message'];
          notifyListeners();
          return;
        }
      }

// من هنا: عندنا نتيجة نهائية (نجاح/فشل) من أحد الطلبين
      debugPrint('resultAttendance ${result.ok}__${result.message}');
      _postedAttendanceForThisCapture = true;

      _lastApiOk = result.ok;
      _lastApiMessage = result.message;

// أعرض رسالة السيرفر كما هي
      _attendanceResult = {
        'status': result.ok ? 'ok' : 'error',
        'message': result.message,
      };

      debugPrint('[ATT][RESPONSE] ok=${result.ok}, msg=${result.message}');
      notifyListeners();
      debugPrint('resultAttendance${result.ok}__${result.message}');
      _postedAttendanceForThisCapture = true;

      _lastApiOk = result.ok;
      _lastApiMessage = result.message;

      // ✅ أضف هذا السطر:
      _attendanceResult = {
        'status': result.ok ? 'ok' : 'error',
        'message': result.message,
      };

      debugPrint('[ATT][RESPONSE] ok=${result.ok}, msg=${result.message}');
      notifyListeners();
    } catch (e) {
      debugPrint('[ATT][ERROR] $e');
    }
  }
  Future<void> toggleCamera() async {
    final hasFront = _frontCamera != null;
    final hasRear  = _rearCamera  != null;

    if (!(hasFront && hasRear)) {
      debugPrint('ℹ️ Only one camera available; toggle ignored.');
      return;
    }

    try {
      await _stopStreamSafely();
      await _disposeCamera();

      _useFront = !_useFront; // ✅ قلب الاختيار بين الأمامية والخلفية

      // نظّف الحالة
      _capturedFile = null;
      _livenessResult = null;
      _faceRecognitionResult = null;
      _attendanceResult = null;
      _ratioProgress = 0.0;
      _insideOval = false;
      _faceDetected = false;
      _setCaptureEligible(false);
      notifyListeners();

      await _initCamera();   // ✅ أعد فتح الكاميرا الجديدة
      _resetInactivity();
    } catch (e) {
      debugPrint('❌ toggleCamera error: $e');
    }
  }


}
