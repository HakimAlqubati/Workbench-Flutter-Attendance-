import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/features/face_liveness/controllers/face_liveness_controller.dart';

import 'package:my_app/features/face_liveness/painters/frame_glow_painter.dart';
import 'package:my_app/features/face_liveness/painters/frame_mask_painter.dart';
import 'package:my_app/features/face_liveness/widgets/face_ratio_bar.dart';

import 'widgets/oval_clipper.dart';
import 'constants.dart';
import 'widgets/gclass.dart';
import 'widgets/camera_preview_cover.dart';
import 'widgets/screensaver.dart'; // ✅ المسار الصحيح (singular)

class FaceLivenessScreen extends StatefulWidget {
  const FaceLivenessScreen({super.key});
  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

class _FaceLivenessScreenState extends State<FaceLivenessScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final FaceLivenessController c;
  late final AnimationController glowCtrl;

  bool _isFullscreen = false;

  // ===== إدارة وضع ملء الشاشة =====
  Future<void> _enterFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    // هذه دالة sync (ترجع void) — لا تسبقها await
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    if (mounted) setState(() => _isFullscreen = true);
  }

  Future<void> _exitFullscreen({bool silent = false}) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // أيضًا بدون await
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    if (mounted) {
      if (silent) {
        _isFullscreen = false; // بدون setState في وضع silent
      } else {
        setState(() => _isFullscreen = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    c = FaceLivenessController()..init();
    glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // ابدأ الشاشة بوضعية طبيعية (غير ممتلئة)
    _exitFullscreen(silent: true);
  }

  @override
  void dispose() {
    // ارجاع الوضع لطبيعته عند مغادرة الشاشة
    _exitFullscreen(silent: true);
    WidgetsBinding.instance.removeObserver(this);

    glowCtrl.dispose();
    c.disposeAll();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // عند استئناف التطبيق؛ إن لم نكن في ملء الشاشة نعيد الحواف
    if (state == AppLifecycleState.resumed && !_isFullscreen) {
      _exitFullscreen(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        c.screenSize = MediaQuery.of(context).size;

        final bg = const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1020), Color(0xFF0A1B26), Color(0xFF091C1B)],
          ),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: c.userActivity,
          onPanDown: (_) => c.userActivity(),
          onPanUpdate: (_) => c.userActivity(),
          child: Stack(
            children: [
              Positioned.fill(child: DecoratedBox(decoration: bg)),
              if (c.showScreensaver)
                _buildScreensaver(context)
              else
                _buildCameraUI(context),

              // طبقة إضاءة خفيفة
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.2,
                        colors: [
                          Colors.white.withOpacity(0.03),
                          Colors.transparent,
                          Colors.white.withOpacity(0.00),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ===== HUD: المسافة المتبقية لايف (اختياري) =====
              // if (c.cameraOpen && c.capturedFile == null)
              //   Positioned(
              //     top: MediaQuery.of(context).size.height * 0.12 + 100,
              //     left: 16,
              //     right: 16,
              //     child: _buildDistanceHud(context),
              //   ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScreensaver(BuildContext context) {
    Alignment align;
    switch (c.clockPosIndex % 3) {
      case 1:
        align = Alignment.topRight;
        break;
      case 2:
        align = Alignment.topLeft;
        break;
      default:
        align = Alignment.topCenter;
    }
    return Screensaver(
      now: c.now,
      alignment: Alignment.topCenter,
      blink: c.clockBlink,
      onTap: () async => c.exitScreensaverAndReopen(),
    );
  }

  Widget _buildCameraUI(BuildContext context) {
    final cam = c.controller;

    final Widget basePreview =
        (c.capturedFile != null)
            ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: ClipPath(
                clipper: OvalClipper(MediaQuery.of(context).size),
                child: Image.file(
                  File(c.capturedFile!.path),
                  fit: BoxFit.cover,
                ),
              ),
            )
            : (cam != null && cam.value.isInitialized)
            ? CameraPreviewCover(controller: cam)
            : const ColoredBox(color: Colors.black);

    // اللون النشط للبيضاوي
    final Color ovalActiveColor =
        c.captureEligible
            ? const Color(0xff0fd86e) // ✅ جاهز
            : const Color(0xffffb74d); // ⚠️ داخل الإطار لكن غير مؤهل بعد

    return Stack(
      children: [
        Positioned.fill(child: basePreview),

        if (c.cameraOpen && c.capturedFile == null)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.35),
                      Colors.transparent,
                      Colors.black.withOpacity(0.08),
                    ],
                  ),
                ),
              ),
            ),
          ),

        if (c.cameraOpen && c.capturedFile == null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: FrameMaskPainter(
                  inside: c.insideOval,
                  activeColor: ovalActiveColor,
                  inactiveColor: Colors.white.withOpacity(0.92),
                  glow: (math.sin(glowCtrl.value * 2 * math.pi) + 1) / 2,
                  strokeWidth: 2.0,
                ),
                foregroundPainter: FrameGlowPainter(
                  glowCtrl,
                  inside: c.captureEligible,
                ),
              ),
            ),
          ),

        // ✅ عدّاد عند الأهلية
        if (c.cameraOpen && c.countdown != null && c.captureEligible)
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.18,
            left: 0,
            right: 0,
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 1.2),
                key: ValueKey(c.countdown),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Text(
                      (c.countdown! > 0) ? '${c.countdown!}' : '✓',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                        letterSpacing: 0.5,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        // ⚠️ خلاف ذلك: رسالة قصيرة
        else if (c.cameraOpen && !c.captureEligible)
          // نظهر التوجيه حتى لو خرجت الزوايا قليلاً
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.18,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                c.tooFar
                    ? "Move In" // بعيد: اقترب
                    : (c.tooClose
                        ? "Move Back" // قريب جدًا: ابتعد
                        : "Align Center"), // داخل النطاق لكن غير متمركز بما يكفي
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.08,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (c.cameraOpen && c.capturedFile == null)
          FaceRatioBar(
            progress: c.ratioProgress,
            brightnessText: _brightnessLabel,
            brightnessValue: c.brightnessLevel,
          ),

        // ليفنِس بانر
        if (c.livenessResult != null)
          _buildLivenessBanner(context, c.livenessResult!),

        // تعريف الوجه (اختياري)
        if (kEnableFaceRecognition && c.faceRecognitionResult != null)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.12 + 56,
            left: 16,
            right: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Glass(
                  blur: 14,
                  opacity: .18,
                  radius: 16,
                  border: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.badge_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _recognitionText(c.faceRecognitionResult!),
                          softWrap: true,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(
                            color: Color(0xffd9ffe9),
                            decoration: TextDecoration.none,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            letterSpacing: .2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // زر التالي بعد الالتقاط
        if (c.capturedFile != null)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            right: 16,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward_rounded),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shadowColor: Colors.black54,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () async => c.tapNextEmployee(),
              label: const Text('Next Employee'),
            ),
          ),

        // شريط علوي: عداد السكرين سيفر
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 12,
          right: 12,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            children: [
              if (c.screensaverCountdown != null)
                Glass(
                  blur: 10,
                  opacity: 0.14,
                  border: true,
                  radius: 999,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: Color(0xff0fd86e),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${c.screensaverCountdown}',
                        style: const TextStyle(
                          color: Color(0xffc7ffdf),
                          fontSize: 13,
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // زر Full Screen أعلى اليمين — يظهر فقط إذا لم نكن في وضع ملء الشاشة
        if (!_isFullscreen)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.fullscreen, color: Colors.white, size: 28),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.black45),
                shape: WidgetStateProperty.all(const CircleBorder()),
              ),
              onPressed: _enterFullscreen,
            ),
          ),
      ],
    );
  }

  // ===== HUD: المسافة لايف =====
  Widget _buildDistanceHud(BuildContext context) {
    final dist = c.estDistanceCm;
    final dRange = c.deltaToRangeCm;
    final center = c.centerScore; // 0..1
    final tooFar = c.tooFar;
    final tooClose = c.tooClose;

    String line1, line2;

    if (dist == null) {
      line1 = 'Distance: --';
      line2 =
          'Fit: ${c.fitPct.toStringAsFixed(0)}%  •  Center: ${(center * 100).toStringAsFixed(0)}%';
    } else {
      String dir;
      if (dRange == null || dRange <= 0.0) {
        dir = '✓ In range';
      } else if (tooFar) {
        dir = '↘ Move closer ${dRange.abs().round()} cm';
      } else if (tooClose) {
        dir = '↗ Move back ${dRange.abs().round()} cm';
      } else {
        dir = '✓ In range';
      }

      line1 = '≈ ${dist.toStringAsFixed(0)} cm   •   $dir';
      line2 =
          'Fit: ${c.fitPct.toStringAsFixed(0)}%  •  Center: ${(center * 100).toStringAsFixed(0)}%';
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Glass(
          blur: 14,
          opacity: .18,
          radius: 16,
          border: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                line1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xffeafff3),
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  letterSpacing: .2,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                line2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xffc7ffdf),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  letterSpacing: .2,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivenessBanner(BuildContext context, Map<String, dynamic> j) {
    final ok = _livenessOk(j);
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.12,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Glass(
            blur: 14,
            opacity: .18,
            radius: 16,
            border: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ok ? Icons.verified_rounded : Icons.error_rounded,
                  color: ok ? const Color(0xff0fd86e) : const Color(0xffff4d67),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _livenessText(j),
                    softWrap: true,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      color:
                          ok
                              ? const Color(0xffd9ffe9)
                              : const Color(0xffffe2e8),
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      letterSpacing: .2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _brightnessLabel {
    if (c.brightnessLevel == null) return '';
    final pct = (c.brightnessLevel!.clamp(0, 255) / 255.0) * 100.0;
    final status = c.brightnessStatus ?? '';
    return '$status - ${pct.toStringAsFixed(0)}%';
  }

  bool _livenessOk(Map<String, dynamic> j) {
    final l = j['liveness'];
    final score = j['score'];
    if (l is bool && score is num) {
      return l == true && score >= 0.85;
    }
    return false;
  }

  String _livenessText(Map<String, dynamic> j) {
    final l = j['liveness'];
    final score = j['score'];
    if (l == null && j['error'] != null) return '❌ (${j['error']})';
    if (l is bool && score is num) {
      return (l && score >= 0.85) ? 'Real face ✅ ($score)' : '❌ ($score)';
    }
    return 'Unknown';
  }

  String _recognitionText(Map<String, dynamic> j) {
    if (j['error'] != null) return '❌ (${j['error']})';

    final Map<String, dynamic> m =
        (j['match'] is Map) ? Map<String, dynamic>.from(j['match']) : {};

    final bool found = m['found'] == true;

    final name = m['name'] ?? j['employee']?['name'] ?? j['name'] ?? 'Unknown';

    final id = m['employee_id'] ?? j['employee']?['id'] ?? j['id'];

    final score = m['score'] ?? j['score'] ?? j['similarity'];

    if (!found) {
      final lower = name.toString().toLowerCase();
      if (lower.contains('no match')) return 'No match found ❌';
      return 'No match ❌';
    }

    final parts = <String>['$name'];
    if (id != null) parts.add('#$id');
    if (score != null) parts.add('score: $score');

    return '✅ ${parts.join('  •  ')}';
  }
}
