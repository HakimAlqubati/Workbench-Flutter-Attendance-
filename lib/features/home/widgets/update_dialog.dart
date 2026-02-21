import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateDialog extends StatelessWidget {
  final String version;
  
  const UpdateDialog({super.key, required this.version});

  static Future<void> checkAndShow(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      final prefs = await SharedPreferences.getInstance();
      final lastShownVersion = prefs.getString('last_shown_update_version') ?? '';

      if (currentVersion != lastShownVersion) {
        if (!context.mounted) return;
        
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => UpdateDialog(version: currentVersion),
        );
        
        await prefs.setString('last_shown_update_version', currentVersion);
      }
    } catch (e) {
      debugPrint('Error showing update dialog: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.new_releases_rounded, color: Colors.blueAccent, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "What's New in Version $version",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to the new release!',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.blueAccent),
          ),
          SizedBox(height: 16),
          _UpdateItem(text: 'Added a setting for the screensaver appearance timer.'),
          SizedBox(height: 8),
          _UpdateItem(text: 'Updated the date display format in the screensaver.'),
          SizedBox(height: 8),
          _UpdateItem(text: 'Added a button to clear the app cache.'),
          SizedBox(height: 8),
          _UpdateItem(text: 'Added a battery indicator with an alert on low battery in the screensaver.'),
          SizedBox(height: 8),
          _UpdateItem(text: 'Fixed other bugs and applied visual improvements.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blueAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _UpdateItem extends StatelessWidget {
  final String text;
  
  const _UpdateItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6, right: 4, left: 8),
          child: Icon(Icons.circle, size: 8, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }
}
