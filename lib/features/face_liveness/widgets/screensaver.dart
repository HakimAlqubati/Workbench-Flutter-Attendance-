// =============================
// File: lib/features/face_liveness/widgets/screensaver.dart
// =============================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/floating_logo.dart';

class Screensaver extends StatelessWidget {
  final DateTime now;
  final Alignment alignment;
  final bool blink;
  final VoidCallback onTap;

  const Screensaver({
    super.key,
    required this.now,
    required this.alignment,
    required this.blink,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat.Hms().format(now);
    final dateStr = DateFormat.yMMMMEEEEd().format(now);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            const FloatingLogo(),
            Align(
              alignment: alignment,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 80),
                opacity: blink ? 0 : 1,
                child: Container(
                  margin: const EdgeInsets.only(top: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  // decoration: BoxDecoration(
                  //   color: Colors.white.withOpacity(.08),
                  //   borderRadius: BorderRadius.circular(18),
                  //   border: Border.all(color: Colors.white.withOpacity(.18)),
                  //   boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 36, offset: Offset(0, 12))],
                  // ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(timeStr,
                          style: const TextStyle(
                              color: Colors.white,
                              decoration: TextDecoration.none,
                              fontWeight: FontWeight.w900,
                              fontSize: 56,
                              shadows: [Shadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 3))])),
                      const SizedBox(height: 6),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          decoration: TextDecoration.none, // 👈 هنا أيضًا
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
