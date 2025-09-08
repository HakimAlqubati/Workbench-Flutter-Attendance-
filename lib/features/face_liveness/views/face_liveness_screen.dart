import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/features/face_liveness/controllers/face_liveness_controller.dart';
import 'package:my_app/features/face_liveness/widgets/top_hud.dart';
import 'package:my_app/features/face_liveness/widgets/camera_ui.dart';
import 'package:my_app/features/face_liveness/widgets/screensaver.dart';

class FaceLivenessScreen extends StatefulWidget {
  const FaceLivenessScreen({super.key});
  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

class _FaceLivenessScreenState extends State<FaceLivenessScreen>
    with TickerProviderStateMixin {
  late final FaceLivenessController c;
  late final AnimationController glowCtrl;

  @override
  void initState() {
    super.initState();


    c = FaceLivenessController()..init();

    // ✅ ثم: عرّف رد فعل الفشل
    c.onLivenessFailed = () {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Sorry'),
          content: const Text('Liveness check failed. Please ensure your real face is visible and try again.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                c.tapNextEmployee(); // Restart the camera
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    };

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
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

        const bg = BoxDecoration(
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
              const Positioned.fill(child: DecoratedBox(decoration: bg)),
              if (c.showScreensaver)
                Screensaver(
                  now: c.now,
                  alignment: Alignment.topCenter,
                  blink: c.clockBlink,
                  onTap: () async => c.exitScreensaverAndReopen(),
                )
              else
                CameraUI(c: c, glowCtrl: glowCtrl),

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

              // شريط علوي: عداد السكون (يسار) + الساعة (يمين)
              TopHud(c: c,hidden: c.showScreensaver),
            ],
          ),
        );
      },
    );
  }
}
