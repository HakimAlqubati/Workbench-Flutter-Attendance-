import 'package:flutter/material.dart';
import 'package:my_app/core/navigation/routes.dart';
import 'package:my_app/core/widgets/app_watermark.dart';
import 'package:my_app/features/face_liveness/services/auth_service.dart';
import 'package:my_app/features/face_liveness/views/face_liveness_screen.dart';
import 'widgets/big_action_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openCamera(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FaceLivenessScreen()),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.settings);
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
          PopupMenuButton<_MenuAction>(
            onSelected: (value) {
              switch (value) {
                case _MenuAction.settings:
                  _openSettings(context);
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: _MenuAction.settings,
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
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
                      BigActionButton(
                        icon: Icons.camera_alt_outlined,
                        title: 'Start Camera',
                        onPressed: () => _openCamera(context),
                      ),
                      BigActionButton(
                        icon: Icons.dialpad_rounded,
                        title: 'Attendance Keypad',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.attendanceKeypad),
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
