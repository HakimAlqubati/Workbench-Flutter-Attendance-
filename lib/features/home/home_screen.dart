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
import 'package:my_app/core/database/sync_database.dart';
import 'views/failed_logs_screen.dart';

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
          ValueListenableBuilder<int>(
            valueListenable: SyncDatabase.failedLogsCount,
            builder: (context, count, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      count > 0
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: count > 0 ? Colors.amberAccent : Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FailedLogsScreen(),
                        ),
                      );
                    },
                    tooltip: 'سجل الأخطاء | Error Log',
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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
