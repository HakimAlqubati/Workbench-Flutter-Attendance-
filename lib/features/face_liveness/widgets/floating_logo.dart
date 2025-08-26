// =============================
// File: lib/features/face_liveness/widgets.dart
// =============================
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';


class FloatingLogo extends StatefulWidget {
  const FloatingLogo({super.key});
  @override
  State<FloatingLogo> createState() => _FloatingLogoState();
}



class _FloatingLogoState extends State<FloatingLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  double _ease(double t) => (math.sin(2 * math.pi * t) + 1) / 2;


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        final dx = ui.lerpDouble(-0.12, 0.10, _ease(t))!;
        final dy = ui.lerpDouble(-0.10, 0.10, _ease((t + .25) % 1))!;
        final scale = ui.lerpDouble(1, 1.03, _ease((t + .125) % 1))!;
        final opacity = ui.lerpDouble(.95, 1, _ease((t + .25) % 1))!;
        return Transform.translate(
          offset: Offset(dx * size.width, dy * size.height),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity!,
              child: Center(
                child: Image.asset(
                  'assets/icon/default-wb.png',
                  width: math.min(size.width * .6, 420),
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}