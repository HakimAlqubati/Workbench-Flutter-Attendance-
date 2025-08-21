import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../constants.dart';


class FrameGlowPainter extends CustomPainter {
  final Animation<double> glow;
  final bool inside;
  FrameGlowPainter(this.glow, {required this.inside}) : super(repaint: glow);


  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * (0.5 + kOvalCxOffsetPct);
    final cy = size.height * (0.5 + kOvalCyOffsetPct);
    final rx = size.width * kOvalRxPct;
    final ry = size.height * kOvalRyPct;


    final rect =
    Rect.fromCenter(center: Offset(cx, cy), width: rx * 2.06, height: ry * 2.06);


    final t = (math.sin(glow.value * 2 * math.pi) + 1) / 2;
    final baseColor = inside ? const Color(0xFF00E676) : const Color(0xFFFF4D67);
    final paint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, ui.lerpDouble(0, 20, t)!)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ui.lerpDouble(1.1, 1.8, t)!
      ..color = baseColor.withOpacity(ui.lerpDouble(0.20, .45, t)!);


    canvas.drawOval(rect, paint);
  }


  @override
  bool shouldRepaint(covariant FrameGlowPainter old) =>
      inside != old.inside || glow != old.glow;
}