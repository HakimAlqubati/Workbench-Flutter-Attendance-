// lib/features/face_liveness/widgets/clock_chip.dart
import 'package:flutter/material.dart';

class ClockChip extends StatelessWidget {
  final DateTime now;
  final bool showIcon; // 🔹 جديد

  const ClockChip({
    super.key,
    required this.now,
    this.showIcon = true, // الافتراضي يظهر الأيقونة
  });

  String _two(int n) => n < 10 ? '0$n' : '$n';

  @override
  Widget build(BuildContext context) {
    final timeStr = "${_two(now.hour)}:${_two(now.minute)}";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(minWidth: 80), // 🔹 أقل عرض
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const Icon(Icons.access_time, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
          ],
          Text(
            timeStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14, // 🔹 كبرت الخط شوي
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );

  }
}
