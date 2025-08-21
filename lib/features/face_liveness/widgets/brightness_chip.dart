// =============================
// File: lib/features/face_liveness/widgets.dart
// =============================
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';


class BrightnessChip extends StatelessWidget {
  final String text;
  const BrightnessChip({super.key, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wb_sunny_rounded, size: 16, color: Colors.white),
          SizedBox(width: 6),
// Text injected by parent via DefaultTextStyle
        ],
      ),
    );
  }
}