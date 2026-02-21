import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:my_app/core/toast_utils.dart';
import 'package:my_app/features/attendance/attendance_service.dart';
import 'package:my_app/features/face_liveness/controllers/face_liveness_controller.dart';
import 'package:my_app/features/face_liveness/painters/frame_glow_painter.dart';
import 'package:my_app/features/face_liveness/painters/frame_mask_painter.dart';
import 'package:my_app/features/face_liveness/widgets/camera_preview_cover.dart';
import 'package:my_app/features/face_liveness/widgets/face_ratio_bar.dart';
import 'package:my_app/features/face_liveness/widgets/liveness_banner.dart';
import 'package:my_app/features/face_liveness/widgets/gclass.dart';
import 'package:my_app/features/face_liveness/widgets/oval_clipper.dart';
import 'package:my_app/features/face_liveness/constants.dart';

Future<String?> askTypeModal(BuildContext context) async {
  String selected = 'checkin'; // افتراضي

  return await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Specify Type'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('Check-in'),
                  value: 'checkin',
                  groupValue: selected,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => selected = v); // ✅ مهم
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Check-out'),
                  value: 'checkout',
                  groupValue: selected,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => selected = v); // ✅ مهم
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(selected),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
    },
  );
}



class CameraUI extends StatelessWidget {
  final FaceLivenessController c;
  final AnimationController glowCtrl;
  const CameraUI({super.key, required this.c, required this.glowCtrl});

  @override
  Widget build(BuildContext context) {
    final cam = c.controller;
    final size = MediaQuery.of(context).size;


    // الأساس: المعاينة أو الصورة الملتقطة
    final Widget basePreview = (c.capturedFile != null)
        ? Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi),
      child: ClipPath(
        clipper: OvalClipper(size),
        child: Image.file(File(c.capturedFile!.path), fit: BoxFit.scaleDown),
      ),
    )
        : (cam != null && cam.value.isInitialized)
        ? CameraPreviewCover(controller: cam)
        : const ColoredBox(color: Colors.black);

    // لون إطار البيضاوي بحسب الأهلية
    final Color ovalActiveColor =
    c.captureEligible ? const Color(0xff0fd86e) : const Color(0xffffb74d);


    return Stack(children: [
    Positioned.fill(
    child: Container(
      color: () {
        final live = c.livenessResult;
        final reco = c.faceRecognitionResult;
        final attendance = c.attendanceResult;

        final bool? liveOk = (live == null)
            ? null
            : (live['status'] == 'ok' &&
            live['result']?['liveness'] == true);

        final bool? recoOk = (reco == null)
            ? null
            : (reco['match'] is Map &&
            (reco['match']['found'] == true));

        if (recoOk == false) {
          return Colors.red;
        }

        final bool? attOk = (attendance == null)
            ? null
            : (attendance['status'] == 'ok');

        // 🟥 شرط خاص: لو liveness false → أحمر مباشرة
        if (liveOk == false) {
         

          c.showBanner('Adjust The Lighting And Try Again');

          return Colors.red;
        }

        c.clearBanner();
        // 👇 الحالة الافتراضية = أسود (ما في رد)
        if (liveOk == null || recoOk == null || attOk == null) {
          return Colors.black;
        }

        // 👇 إذا الثلاثة ناجحين → أخضر
        if (liveOk && recoOk && attOk) {
          return Colors.green;
        }

        // 👇 إذا واحد أو أكثر false → أحمر
        return Colors.red;
      }(),
    ),
    ),
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
              foregroundPainter: FrameGlowPainter(glowCtrl, inside: c.captureEligible),
            ),
          ),
        ),


      // عدّاد الالتقاط
      if (c.cameraOpen && c.countdown != null && c.captureEligible && c.capturedFile == null)
        Positioned(
          bottom: size.height * 0.18,
          left: 0, right: 0,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 1.2),
              key: ValueKey(c.countdown),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: Text(
                  (c.countdown! > 0) ? '${c.countdown!}' : '✓',
                  style: TextStyle(
                    fontSize: size.width * 0.12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                    letterSpacing: 0.5,
                    shadows: const [Shadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 4))],
                  ),
                ),
              ),
            ),
          ),
        )
      else if (c.cameraOpen && !c.captureEligible)
        Positioned(
          bottom: size.height * 0.18, left: 0, right: 0,
          child: Center(
            child: Text(
              _guidanceText(c),
              style: TextStyle(
                fontSize: size.width * 0.08,
                fontWeight: FontWeight.w600,
                color: Colors.amberAccent,
                decoration: TextDecoration.none,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3))],
              ),
            ),
          ),
        ),



      if (c.cameraOpen && c.capturedFile == null)
        FaceRatioBar(
          progress: c.ratioProgress,
          brightnessText: _brightnessLabel(c),
          brightnessValue: c.brightnessLevel,
        ),

      if (c.livenessResult != null)
        LivenessBanner(json: c.livenessResult!),

      if (kEnableFaceRecognition && c.faceRecognitionResult != null)
        _RecognitionBanner(json: c.faceRecognitionResult!),

      if (c.attendanceResult != null)
        AttendanceBanner(json: c.attendanceResult!),
      if (c.capturedFile != null && c.waiting)
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.28),
            alignment: Alignment.center,
            child: const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
          ),
        ),

      if (c.capturedFile != null && !c.waiting)
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 20,
          right: 16,
          child: Builder(
            builder: (_) {
              debugPrint('liveRes=${c.livenessResult}');
              final bool liveOk =
                  c.livenessResult?['status'] == 'ok' &&
                      c.livenessResult?['result']?['liveness'] == true;

              final bool recoOk = _isRecognitionOk(c.faceRecognitionResult);
              final bool attOk =
                  c.attendanceResult?['status'] == 'ok';

// ✅ الزر يكون Retry إذا فشل أي واحد من الاثنين
              final bool showRetry = !(liveOk && recoOk && attOk);

              final Color bg = showRetry ? Colors.red : Theme.of(context).primaryColor;
              final IconData icon = showRetry ? Icons.refresh_rounded : Icons.arrow_forward_rounded;
              final String label = showRetry ? 'Retry' : 'Next Employee';


              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: c.bannerMessage,
                    builder: (context, msg, _) {
                      if (msg == null || msg.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.85, // عريض بنسبة 85%
                          child: Text(
                            msg,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              decoration: TextDecoration.none,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    icon: Icon(icon),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bg,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.black54,
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: () async {
                      c.clearBanner();
                      await c.tapNextEmployee();
                    },

                    label: Text(label),
                  ),
                ],
              );
            },
          ),
        ),

    ]);
  }

  // == helpers ==
  String _guidanceText(FaceLivenessController c) {
    final status = c.brightnessStatus ?? '';
    // if (status.contains('❌') && (status.contains('dark') || status.contains('dim'))) {
    //   return "Find better lighting";
    // }
    if (status.contains('⚠️') && status.contains('bright')) {
      return "Avoid direct light";
    }
    if (c.tooFar) return "Move In";
    if (c.tooClose) return "Move Back";
    return "Center Your Face";
  }
  bool _isRecognitionOk(Map<String, dynamic>? j) {
    if (j == null) return false;          // لا توجد نتيجة => اعتبرها فشل
    if (j['error'] != null) return false; // خطأ من السيرفر
    final m = (j['match'] is Map) ? Map<String, dynamic>.from(j['match']) : const {};
    return m['found'] == true;            // نجاح فقط لو found=true
  }
  String _brightnessLabel(FaceLivenessController c) {
    if (c.brightnessLevel == null) return '';
    final pct = (c.brightnessLevel!.clamp(0, 255) / 255.0) * 100.0;
    final status = c.brightnessStatus ?? '';
    return '$status - ${pct.toStringAsFixed(0)}%';
  }
}

class _RecognitionBanner extends StatelessWidget {
  final Map<String, dynamic> json;
  const _RecognitionBanner({required this.json});

  String _text(Map<String, dynamic> j) {
    if (j['error'] != null) return '❌ (${j['error']})';
    final Map<String, dynamic> m = (j['match'] is Map) ? Map<String, dynamic>.from(j['match']) : {};
    final bool found = m['found'] == true;
    final name = m['name'] ?? j['employee']?['name'] ?? j['name'] ?? 'Unknown';
    final id = m['employee_id'] ?? j['employee']?['id'] ?? j['id'];
    final score = m['score'] ?? j['score'] ?? j['similarity'];
    if (!found) {
      final lower = name.toString().toLowerCase();
      if (lower.contains('no match')) return 'No face match found. Please try again';
      return 'No match ❌';
    }
    final parts = <String>['$name'];
    if (id != null) parts.add('#$id');
    if (score != null) parts.add('score: $score');
    return '✅ ${parts.join('  •  ')}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      top: size.height * 0.12 + 56,
      left: 16, right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Glass(
            blur: 14, opacity: .18, radius: 16, border: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.badge_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(
                _text(json),
                softWrap: true, overflow: TextOverflow.fade,
                style: const TextStyle(
                  color: Color(0xffd9ffe9),
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  letterSpacing: .2,
                ),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}



class AttendanceBanner extends StatelessWidget {
  final Map<String, dynamic> json;
  const AttendanceBanner({super.key, required this.json});

  String _text(Map<String, dynamic> j) {
    final status = j['status'];
    final message = j['message'] ?? '';
    if (status == 'ok') {
      return '✅ Attendance recorded\n$message';
    }
    return '❌ Attendance failed\n$message';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isOk = json['status'] == 'ok';

    return Positioned(
      top: size.height * 0.12 + 112, // أسفل Liveness + Recognition
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isOk ? Icons.how_to_reg_rounded : Icons.cancel_rounded,
                  color: isOk ? const Color(0xff0fd86e) : const Color(0xffff4d67),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _text(json),
                    softWrap: true,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      color: isOk ? const Color(0xffd9ffe9) : const Color(0xffffe2e8),
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      height: 1.4,
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


}

