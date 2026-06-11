import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/features/face_liveness/constants.dart';
import 'package:my_app/features/face_liveness/controllers/face_liveness_controller.dart';
import 'package:my_app/features/face_liveness/widgets/top_hud.dart';
import 'package:my_app/features/attendance/attendance_service.dart';
import 'package:my_app/features/face_liveness/widgets/camera_ui.dart';
import 'package:my_app/features/face_liveness/widgets/screensaver.dart';
import 'package:my_app/features/face_liveness/services/auth_service.dart';

class FaceLivenessScreen extends StatefulWidget {
  const FaceLivenessScreen({super.key});
  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

class _FaceLivenessScreenState extends State<FaceLivenessScreen>
    with TickerProviderStateMixin {
  late final FaceLivenessController c;
  late final AnimationController glowCtrl;
  String? _branchName;

  @override
  void initState() {
    super.initState();
    // السماح بجميع الاتجاهات لهذه الصفحة
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _loadBranch();

    c = FaceLivenessController()..init();

    // ✅ ثم: عرّف رد فعل الفشل
    c.onLivenessFailed = () {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Sorry'),
          content: const Text(
            'Liveness check incomplete. Please ensure your real face is visible and try aga',
          ),
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

    // ✅ تعيين onRequireType هنا بـ context ثابت (parent)
    c.onRequireType = () {
      if (!mounted) return Future.value(null);
      return askTypeModal(context);
    };
    c.onShiftConflict = (options) {
      if (!mounted) return Future.value(null);
      return askConflictModal(context, options);
    };
    AttendanceService.onRequireType = c.onRequireType;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _loadBranch() async {
    final session = await AuthService().getSavedSession();
    if (mounted) {
      setState(() {
        _branchName = session?.branchName;
      });
    }
  }

  @override
  void dispose() {
    // إعادة ضبط الاتجاه إلى الطولي فقط عند الخروج (إذا كان هذا هو الافتراضي لتطبيقك)
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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
            begin: Alignment.topLeft, // تم التعديل ليتناسب مع كلا الوضعين
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1020), Color(0xFF0A1B26), Color(0xFF091C1B)],
          ),
        );

        return Scaffold(
          backgroundColor: Colors.black,
          body: OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;

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
                        alignment: Alignment.center,
                        offset: c.screensaverOffset,
                        blink: c.clockBlink,
                        onTap: () async => c.exitScreensaverAndReopen(),
                      )
                    else
                      CameraUI(c: c, glowCtrl: glowCtrl),

                    // طبقة إضاءة خفيفة (تُخفى أثناء السكرين سيفر لتكون الشاشة سوداء تماماً)
                    if (!c.showScreensaver)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: isLandscape
                                    ? Alignment.center
                                    : Alignment
                                          .topCenter, // توسيط الإضاءة في العرضي
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

                    // تغليف العناصر العلوية بـ SafeArea لتجنب الـ Notch في الوضع العرضي
                    SafeArea(
                      child: Stack(
                        children: [
                          // شريط علوي: عداد السكون (يسار) + الساعة (يمين)
                          TopHud(
                            c: c,
                            hidden: c.showScreensaver,
                            branchName: _branchName,
                          ),

                          // ============================
                          // ✅ زر تبديل الكاميرا (أعلى المنتصف)
                          // ============================
                          if (kShowSwitchCameraButton &&
                              !c.showScreensaver && // لا تعرضه أثناء شاشة الـ Screensaver
                              c.cameraOpen && // المعاينة شغّالة
                              c.capturedFile == null && // ليس بعد الالتقاط
                              !c.waiting) // ليس أثناء انتظار نتائج الشبكة
                            Align(
                              // في الوضع العرضي نضعه في أعلى المنتصف أيضاً، ولكن الـ SafeArea ستحميه
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(22),
                                    onTap: () async {
                                      await c
                                          .toggleCamera(); // ← استدعِ الدالة في الـ controller
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0x66000000,
                                        ), // خلفية نصف شفافة
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.cameraswitch_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            c.isFrontCamera ? 'Front' : 'Back',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
