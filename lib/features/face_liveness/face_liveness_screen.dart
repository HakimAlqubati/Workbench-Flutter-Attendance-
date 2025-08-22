// =============================
// File: lib/features/face_liveness/face_liveness_screen.dart
// =============================
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:my_app/features/face_liveness/painters/face_box_painter.dart';
import 'package:my_app/features/face_liveness/painters/frame_glow_painter.dart';
import 'package:my_app/features/face_liveness/painters/frame_mask_painter.dart';
import 'package:my_app/features/face_liveness/widgets/face_ratio_bar.dart';

import 'constants.dart';
import 'widgets/gclass.dart';
import 'widgets/floating_logo.dart';
import 'widgets/camera_preview_cover.dart';
import 'widgets/screensaver.dart';
import 'controllers/face_liveness_controller.dart';

class FaceLivenessScreen extends StatefulWidget {
  const FaceLivenessScreen({super.key});
  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

class _FaceLivenessScreenState extends State<FaceLivenessScreen>
    with TickerProviderStateMixin {
  late final FaceLivenessController c;
  late final AnimationController glowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    c = FaceLivenessController()..init();
  }

  @override
  void dispose() {
    glowCtrl.dispose();
    c.disposeAll();
    super.dispose();
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
      alignment: align,
      blink: c.clockBlink,
      onTap: () async => c.exitScreensaverAndReopen(),
    );
  }

  Widget _buildCameraUI(BuildContext context) {
    final cam = c.controller;
    final Widget basePreview = (c.capturedFile != null)
        ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: Image.file(File(c.capturedFile!.path), fit: BoxFit.cover),
          )
        : (cam != null && cam.value.isInitialized)
        ? CameraPreviewCover(controller: cam)
        : const ColoredBox(color: Colors.black);

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
                  activeColor: Theme.of(context).primaryColor,                 // ✅ من الثيم
                  inactiveColor: Colors.white,                     // أو theme.colorScheme.outline.withOpacity(.9)
                  glow: (math.sin(glowCtrl.value * 2 * math.pi) + 1) / 2, // لو حابب توهّج لطيف 0..1
                  strokeWidth: 2.0,
                ),
                foregroundPainter: FrameGlowPainter(
                  glowCtrl,
                  inside: c.insideOval,
                ),
              ),
            ),
          ),

        if (c.cameraOpen && c.capturedFile == null && c.insideOval)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                // painter: FaceBoxPainter(
                //   faceRect: c.lastFaceRect,
                //   imageRawSize: c.latestImageSize,
                //   isFrontCamera:
                //       c.controller?.description.lensDirection ==
                //       CameraLensDirection.front,
                // ),
              ),
            ),
          ),

        if (c.cameraOpen && c.countdown != null)
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
          ),

        if (c.cameraOpen && c.capturedFile == null)
          FaceRatioBar(
            progress: c.ratioProgress,
            brightnessText: _brightnessLabel,
            brightnessValue: c.brightnessLevel,
          ),

        // ⬇️ مؤشر محاذاة الوجه لمركز البيضاوي
        // if (c.cameraOpen && c.capturedFile == null  && c.insideOval )
        //   Positioned(
        //     top: MediaQuery.of(context).size.height * 0.12 + 100,
        //     left: 16,
        //     right: 16,
        //     child: Center(
        //       child: Opacity(
        //         opacity: c.centerScore, // 0..1
        //         child: const Icon(
        //           Icons.fiber_manual_record,
        //           size: 14,
        //           color: Color(0xff0fd86e),
        //         ),
        //       ),
        //     ),
        //   ),

        if (c.livenessResult != null)
          _buildLivenessBanner(context, c.livenessResult!),

        if (kEnableFaceRecognition  && c.faceRecognitionResult != null)
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
                      const Icon(Icons.badge_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _recognitionText(c.faceRecognitionResult!),
                          softWrap: true,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(
                            color: Color(0xffd9ffe9),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Color(0xff0fd86e)),
                      const SizedBox(width: 6),
                      Text(
                        '${c.screensaverCountdown}',
                        style: const TextStyle(color: Color(0xffc7ffdf), fontSize: 13,
                            decoration: TextDecoration.none,fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              // Glass(
              //   blur: 10,
              //   opacity: 0.14,
              //   border: true,
              //   radius: 999,
              //   padding: const EdgeInsets.all(6),
              //   child: IconButton(
              //     tooltip: 'Settings',
              //     onPressed: () {
              //       c.userActivity();                // يمنع دخول السكرين سيفر
              //       Navigator.pushNamed(context, '/settings');
              //     },
              //     icon: const Icon(Icons.settings_outlined, size: 18, color: Colors.white),
              //   ),
              // ),


            ],
          ),
        ),
      ],
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
                      color: ok
                          ? const Color(0xffd9ffe9)
                          : const Color(0xffffe2e8),
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
    // خطأ صريح من السيرفر
    if (j['error'] != null) return '❌ (${j['error']})';

    // نقرأ match إن وُجد
    final Map<String, dynamic> m =
    (j['match'] is Map) ? Map<String, dynamic>.from(j['match']) : {};

    final bool found = m['found'] == true;

    // استخراج اسم/معرف/درجة بشكل مرن
    final name = m['name'] ??
        j['employee']?['name'] ??
        j['name'] ??
        'Unknown';

    final id = m['employee_id'] ??
        j['employee']?['id'] ??
        j['id'];

    final score = m['score'] ?? j['score'] ?? j['similarity'];

    // لو ما في تطابق
    if (!found) {
      // أحيانًا السيرفر يرجّع "No match found" كنص
      final lower = name.toString().toLowerCase();
      if (lower.contains('no match')) return 'No match found ❌';
      return 'No match ❌';
    }

    // في حالة التطابق
    final parts = <String>['$name'];
    if (id != null) parts.add('#$id');
    if (score != null) parts.add('score: $score');

    return '✅ ${parts.join('  •  ')}';
  }

}
