// =============================
// File: lib/features/face_liveness/widgets.dart
// =============================
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';


class Glass extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final bool border;
  final double radius;
  final EdgeInsets padding;
  const Glass({super.key, required this.child, this.blur = 8, this.opacity = .12, this.border = false, this.radius = 14, this.padding = const EdgeInsets.all(8)});


  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(radius),
            border: border ? Border.all(color: Colors.white.withOpacity(.16)) : null,
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8))],
          ),
          child: child,
        ),
      ),
    );
  }
}