// lib/features/face_liveness/widgets/top_hud.dart
import 'package:flutter/material.dart';
import 'package:my_app/features/face_liveness/controllers/face_liveness_controller.dart';
import 'package:my_app/features/face_liveness/widgets/gclass.dart';
import 'package:my_app/features/face_liveness/widgets/clock_chip.dart';

class TopHud extends StatelessWidget {
  final FaceLivenessController c;
  final bool hidden;
  const TopHud({super.key, required this.c, this.hidden = false});

  static const _timerIcon = Icon(
    Icons.timer_outlined,
    size: 16,
    color: Color(0xff0fd86e),
  );

  static const _countTextStyle = TextStyle(
    color: Color(0xffc7ffdf),
    fontSize: 13,
    decoration: TextDecoration.none,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    if (hidden) return const SizedBox.shrink();

    final top = MediaQuery.of(context).padding.top + 12;
    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // يسار: عداد السكون إذا موجود
          _CountdownChip(
            countdown: c.screensaverCountdown,
            icon: _timerIcon,
            textStyle: _countTextStyle,
          ),

          const SizedBox(width: 8),

          // يمين: الساعة دائمًا — معزولة لتقليل إعادة الطلاء
          RepaintBoundary(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 90),
              child: ClockChip(
                now: c.now,
                showIcon: false,
              ),
            ),
          ),

        ],
      ),
    );
  }
}

class _CountdownChip extends StatelessWidget {
  final int? countdown;
  final Widget icon;
  final TextStyle textStyle;

  const _CountdownChip({
    required this.countdown,
    required this.icon,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (countdown == null) return const SizedBox.shrink();

    return RepaintBoundary(
      child: Glass(
        blur: 10,
        opacity: 0.14,
        border: true,
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(countdown!.toString(), style: textStyle),
          ],
        ),
      ),
    );
  }
}
