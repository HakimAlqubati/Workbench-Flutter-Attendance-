import 'package:flutter/material.dart';
import 'package:my_app/core/navigation/routes.dart';
import 'package:my_app/core/network_helper.dart';
import 'package:my_app/core/widgets/app_watermark.dart';
import 'package:my_app/features/face_liveness/services/auth_service.dart';
import 'package:my_app/features/face_liveness/views/face_liveness_screen.dart';
import 'widgets/big_action_button.dart';
import 'widgets/update_dialog.dart';
import 'widgets/credential_verification_dialog.dart';
import '../../widgets/clear_cache_dialog.dart';

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

  void _openCamera(BuildContext context) async {
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

  Future<bool> _verifyAction(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final auth = AuthService();
    final session = await auth.getSavedSession();

    if (session == null) return true; // If no session, no need to verify

    if (!context.mounted) return false;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CredentialVerificationDialog(
        email: session.email,
        title: title,
        message: message,
      ),
    );

    return verified == true;
  }

  Future<void> _logout(BuildContext context) async {
    final verified = await _verifyAction(
      context,
      title: 'Confirm Logout',
      message: 'Please enter your password to log out',
    );

    if (!verified) return;

    final auth = AuthService();
    await auth.logout();

    if (!context.mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('You have been logged out')));
  }

  Future<void> _clearCache(BuildContext context) async {
    final verified = await _verifyAction(
      context,
      title: 'Confirm',
      message: 'Please enter your password to clear cache',
    );

    if (!verified) return;

    if (!context.mounted) return;
    ClearCacheDialog.show(context);
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
                        disabled: true,
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
