import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../constants.dart';


class FaceBoxPainter extends CustomPainter {
  final Rect? faceRect; // portrait-space rect from MLKit
  final Size? imageRawSize; // raw camera size (landscape w x h)
  final bool isFrontCamera;


  const FaceBoxPainter({this.faceRect, this.imageRawSize, required this.isFrontCamera});


  @override
  void paint(Canvas canvas, Size screenSize) {
    if (faceRect == null || imageRawSize == null) return;


    final srcW = imageRawSize!.height; // portrait width
    final srcH = imageRawSize!.width; // portrait height


    final scale = math.max(screenSize.width / srcW, screenSize.height / srcH);
    final dx = (screenSize.width - srcW * scale) / 2.0;
    final dy = (screenSize.height - srcH * scale) / 2.0;


    Rect r = Rect.fromLTRB(
      faceRect!.left * scale + dx,
      faceRect!.top * scale + dy,
      faceRect!.right * scale + dx,
      faceRect!.bottom * scale + dy,
    );


    if (isFrontCamera) {
      final cx = screenSize.width / 2;
      r = Rect.fromLTRB(2 * cx - r.right, r.top, 2 * cx - r.left, r.bottom);
    }


    final paint = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(r, paint);
  }


  @override
  bool shouldRepaint(covariant FaceBoxPainter old) =>
      faceRect != old.faceRect || imageRawSize != old.imageRawSize || isFrontCamera != old.isFrontCamera;
}