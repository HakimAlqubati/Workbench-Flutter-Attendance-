import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/features/face_liveness/constants.dart';
import 'package:my_app/features/face_liveness/controllers/face_liveness_controller.dart';
import 'package:my_app/features/face_liveness/widgets/top_hud.dart';
import 'package:my_app/features/attendance/attendance_service.dart';
import 'package:my_app/features/face_liveness/widgets/camera_ui.dart';
import 'package:my_app/features/face_liveness/widgets/screensaver.dart';
import 'package:my_app/features/face_liveness/services/auth_service.dart';
import 'package:my_app/core/datetime_setting_helper.dart';

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

  Widget _buildTimeTamperedOverlay(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1020), Color(0xFF0A1B26), Color(0xFF091C1B)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  color: Colors.redAccent,
                  size: 72,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Automatic Time Disabled',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'To register attendance, you must enable "Automatic Date & Time" in your phone settings to ensure clock accuracy and prevent time tampering.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Colors.redAccent, Colors.deepOrangeAccent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await DateTimeSettingHelper.openDateTimeSettings();
                  },
                  icon: const Icon(Icons.settings_rounded, color: Colors.white),
                  label: const Text(
                    'Open Time Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        c.screenSize = MediaQuery.of(context).size;

        const bg = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1020), Color(0xFF0A1B26), Color(0xFF091C1B)],
          ),
        );

        return Scaffold(
          backgroundColor: Colors.black,
          body: !c.isTimeAutomatic
              ? _buildTimeTamperedOverlay(context)
              : OrientationBuilder(
                  builder: (context, orientation) {
                    final isLandscape = orientation == Orientation.landscape;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: c.userActivity,
                      onPanDown: (_) => c.userActivity(),
                      onPanUpdate: (_) => c.userActivity(),
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: DecoratedBox(decoration: bg),
                          ),

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

                          if (!c.showScreensaver)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: isLandscape
                                          ? Alignment.center
                                          : Alignment.topCenter,
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

                          SafeArea(
                            child: Stack(
                              children: [
                                TopHud(
                                  c: c,
                                  hidden: c.showScreensaver,
                                  branchName: _branchName,
                                ),

                                if (kShowSwitchCameraButton &&
                                    !c.showScreensaver &&
                                    c.cameraOpen &&
                                    c.capturedFile == null &&
                                    !c.waiting)
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          onTap: () async {
                                            await c.toggleCamera();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0x66000000),
                                              borderRadius:
                                                  BorderRadius.circular(20),
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
                                                  c.isFrontCamera
                                                      ? 'Front'
                                                      : 'Back',
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
