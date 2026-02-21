import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/core/navigation/routes.dart';
import 'package:my_app/core/network_helper.dart';
import 'package:my_app/core/toast_utils.dart';
import 'package:my_app/core/widgets/app_watermark.dart';
import 'package:my_app/features/face_liveness/constants.dart';
import 'package:my_app/features/face_liveness/services/auth_service.dart';
import 'package:my_app/features/face_liveness/views/face_liveness_screen.dart';
import 'package:my_app/features/splash/splash_gate.dart';
import 'package:platform_device_id_plus/platform_device_id.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/big_action_button.dart';
import 'widgets/update_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateDialog.checkAndShow(context);
    });
  }

  void _openCamera(BuildContext context) async  {
    final connected = await NetworkHelper.checkAndToastConnection();
    if (!connected) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FaceLivenessScreen()),
    );
  }

  Future<void> _openKeypad(BuildContext context) async {
    final connected = await NetworkHelper.checkAndToastConnection();
    if (!connected) {
      return;
    }
    Navigator.pushNamed(context, AppRoutes.attendanceKeypad);
  }


  void _openSettings(BuildContext context) async {
    final connected = await NetworkHelper.checkAndToastConnection();
    if (!connected) {
      return;
    }
    Navigator.pushNamed(context, AppRoutes.settings);
  }

  Future<void> _clearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.4),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: -5,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SYSTEM PURGE',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: Theme.of(context).primaryColor,
                      shadows: [
                        Shadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Are you sure you want to clear operational cache? This action is irreversible.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Theme.of(context).primaryColor.withOpacity(0.6),
                              width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text('ABORT'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.85),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 15,
                          shadowColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text(
                          'EXECUTE',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;

    // Navigate to SplashGate (initial point) and remove all history
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashGate()),
      (r) => false,
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final auth = AuthService();
    await auth.logout();

    if (!context.mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You have been logged out')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Face Liveness"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline), // Trash icon
            onPressed: () => _clearCache(context),
            tooltip: 'Clear Cache',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(context),
            onLongPress: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Open settings'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
        // actions: [
        //   PopupMenuButton<_MenuAction>(
        //     onSelected: (value) {
        //       switch (value) {
        //         case _MenuAction.settings:
        //           _openSettings(context);
        //           break;
        //       }
        //     },
        //     itemBuilder: (ctx) => const [
        //       PopupMenuItem(
        //         value: _MenuAction.settings,
        //         child: ListTile(
        //           leading: Icon(Icons.settings),
        //           title: Text('Settings'),
        //           dense: true,
        //           contentPadding: EdgeInsets.zero,
        //         ),
        //       ),
        //     ],
        //   ),
        // ],
      ),
      body: Stack(
        children: [
          const AppWatermark(),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      // if(kShowCameraScreen)
                      BigActionButton(
                        icon: Icons.camera_alt_outlined,
                        title: 'Start Camera',
                        onPressed: () => _openCamera(context),
                      ),
                      // if(kShowKeypadScreen)
                      BigActionButton(
                        icon: Icons.dialpad_rounded,
                        title: 'Attendance Keypad',
                        onPressed: () => _openKeypad(context),
                        disabled:true,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _MenuAction { settings }
