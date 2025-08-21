// =============================
// File: lib/features/face_liveness/widgets/camera_preview_cover.dart
// =============================
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPreviewCover extends StatelessWidget {
  final CameraController controller;
  const CameraPreviewCover({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = controller.value.previewSize;
    if (s == null) return const ColoredBox(color: Colors.black);
    final portrait = Size(s.height, s.width); // تبديل للأبوبورتريت
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: portrait.width,
          height: portrait.height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
