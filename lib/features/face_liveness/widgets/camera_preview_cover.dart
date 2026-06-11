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
    if (!controller.value.isInitialized) return const ColoredBox(color: Colors.black);

    final previewSize = controller.value.previewSize!;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // التأكد من معرفة الضلع الأطول والضلع الأقصر في الكاميرا
    final double longSide = previewSize.width > previewSize.height ? previewSize.width : previewSize.height;
    final double shortSide = previewSize.width > previewSize.height ? previewSize.height : previewSize.width;

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: isLandscape ? longSide : shortSide,
          height: isLandscape ? shortSide : longSide,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
