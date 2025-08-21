import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../constants.dart';


class FrameMaskPainter extends CustomPainter {
  final bool inside;
  const FrameMaskPainter({required this.inside});


  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;


    final cx = size.width * (0.5 + kOvalCxOffsetPct);
    final cy = size.height * (0.5 + kOvalCyOffsetPct);
    final rx = size.width * kOvalRxPct;
    final ry = size.height * kOvalRyPct;
    final ovalRect =
    Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);


    final overlay = Path()..addRect(full);
    final window = Path()..addOval(ovalRect);
    final mask = Path.combine(PathOperation.difference, overlay, window);


    final dimPaint = Paint()..color = const Color(0xA6000000);
    canvas.drawPath(mask, dimPaint);


    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = (inside ? const Color(0xFF7CFFC4) : Colors.white).withOpacity(.9);
    canvas.drawOval(ovalRect, edgePaint);
  }


  @override
  bool shouldRepaint(covariant FrameMaskPainter old) => inside != old.inside;
}