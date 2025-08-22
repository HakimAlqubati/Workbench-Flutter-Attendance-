import 'package:flutter/material.dart';
import 'dart:ui'; // لاستخدام FontFeature
import 'gclass.dart'; // تأكد من أن هذا الملف موجود في مشروعك

// Enum لتنظيم حالات الإضاءة وجعل الكود أكثر نظافة
enum BrightnessStatus { good, warning, initializing }

class FaceRatioBar extends StatelessWidget {
  final double progress; // 0..1
  final String brightnessText;
  final double? brightnessValue;

  const FaceRatioBar({
    super.key,
    required this.progress,
    required this.brightnessText,
    required this.brightnessValue,
  });

  // دالة مساعدة لتحديد الحالة بناءً على النص
  (BrightnessStatus, String) _getBrightnessDetails() {
    final lowerCaseText = brightnessText.toLowerCase();
    if (lowerCaseText.contains('dark') || lowerCaseText.contains('bright')) {
      return (BrightnessStatus.warning, brightnessText);
    } else if (lowerCaseText.contains('good')) {
      return (BrightnessStatus.good, brightnessText);
    }
    return (BrightnessStatus.initializing, 'Measuring Light…');
  }

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final (brightnessStatus, effectiveText) = _getBrightnessDetails();

    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 20,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Glass(
            blur: 12,
            opacity: .14,
            border: true,
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // العنوان ونسبة Face fit
                Row(
                  children: [
                    const Text(
                      'Face Fit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const Spacer(),
                    // عداد النسبة المئوية المتحرك
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: clampedProgress),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, value, child) {
                        return Text(
                          '${(value * 100).round()}%',
                          style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.none,
                            fontSize: 12.5,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // شريط Face fit أصبح متحركاً
                LayoutBuilder(builder: (context, constraints) {
                  return Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xff1b1b1b).withOpacity(.65),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xff444444).withOpacity(.5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        width: constraints.maxWidth * clampedProgress,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: clampedProgress > 0.9
                                ? [const Color(0xFF388E3C), const Color(0xFF66BB6A)] // أخضر
                                : [const Color(0xFF4FC3F7), const Color(0xFF3F51B5)], // أزرق
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),

                // سطر الإضاءة
                Row(
                  children: [
                    // *** التعديل الرئيسي هنا ***
                    // تم تغليف الشريحة بـ Expanded لتأخذ العرض الكامل
                    Expanded(
                      child: _EnhancedBrightnessChip(
                        status: brightnessStatus,
                        text: effectiveText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// نسخة محسنة من الـ Chip مع أيقونة وألوان وحركة أفضل
class _EnhancedBrightnessChip extends StatelessWidget {
  final BrightnessStatus status;
  final String text;
  const _EnhancedBrightnessChip({required this.status, required this.text});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData iconData;

    switch (status) {
      case BrightnessStatus.warning:
        color = const Color(0xFFFF4D67); // أحمر
        iconData = Icons.warning_amber_rounded;
        break;
      case BrightnessStatus.good:
        color = const Color(0xFF32D37A); // أخضر
        iconData = Icons.check_circle_outline;
        break;
      case BrightnessStatus.initializing:
        color = Colors.grey.shade600; // رمادي
        iconData = Icons.highlight_alt_rounded;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.7),
          width: 1.2,
        ),
      ),
      child: Row(
        // *** التعديل الثاني هنا ***
        // لجعل المحتوى (الأيقونة والنص) في المنتصف
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              decoration: TextDecoration.none,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}