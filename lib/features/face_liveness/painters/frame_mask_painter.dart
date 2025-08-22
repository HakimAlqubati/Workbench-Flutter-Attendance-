import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../constants.dart';

/// يرسم قناع الشاشة مع نافذة بيضاوية في الوسط + إطار متوهّج حول البيضاوي.
/// - [inside]: إذا true يَستخدم لون الحالة النشطة (غالبًا أخضر)، وإلا لون خامل.
/// - [activeColor]/[inactiveColor]: تُمرَّر عادةً من الثيم Theme.of(context).primaryColor.
/// - [glow]: شدّة التوهّج 0..1 (حرّكها بالأنيميشن لوميض لطيف).
/// - [strokeWidth]: سماكة الحد الأساسي.
/// - [dimColor]: لون تغميق الخلفية خارج البيضاوي.
class FrameMaskPainter extends CustomPainter {
  final bool inside;
  final Color activeColor;
  final Color inactiveColor;
  final double glow;            // 0..1
  final double strokeWidth;
  final Color dimColor;

  const FrameMaskPainter({
    required this.inside,
    required this.activeColor,
    required this.inactiveColor,
    this.glow = 0.5,
    this.strokeWidth = 2.0,
    this.dimColor = const Color(0xA6000000),
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ===== مساحة اللوحة =====
    final full = Offset.zero & size;

    // ===== حساب البيضاوي وفق ثوابت التصميم =====
    final cx = size.width  * (0.5 + kOvalCxOffsetPct);
    final cy = size.height * (0.5 + kOvalCyOffsetPct);
    final rx = size.width  * kOvalRxPct;
    final ry = size.height * kOvalRyPct;

    final ovalRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width:  rx * 2,
      height: ry * 2,
    );

    // ===== قناع تغميق خارج البيضاوي (نافذة مقصوصة) =====
    final overlay = Path()..addRect(full);
    final window  = Path()..addOval(ovalRect);
    final mask    = Path.combine(PathOperation.difference, overlay, window);

    final dimPaint = Paint()..color = dimColor;
    canvas.drawPath(mask, dimPaint);

    // ===== تحديد لون الحالة الحالية =====
    final Color edgeColor = (inside ? activeColor : inactiveColor);

    // ===== طبقة توهّج خارجية (Glow) =====
    // نستخدم BlurStyle.outer لعمل هالة ناعمة خارج الحد.
    // نضبط الشدة والسُمك حسب glow (0..1) للحصول على نبضات لطيفة.
    final double sigma = ui.lerpDouble(6.0, 14.0, glow.clamp(0.0, 1.0))!;
    final double glowStroke = ui.lerpDouble(strokeWidth * 1.6, strokeWidth * 2.2, glow)!;

    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowStroke
      ..color = edgeColor.withOpacity(ui.lerpDouble(0.28, 0.55, glow)!)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 0) // placeholder
      ..isAntiAlias = true;

    // ملاحظة: بعض المحرّرات تحتاج sigma عبر MaskFilter.blur مباشرة:
    glowPaint.maskFilter = MaskFilter.blur(BlurStyle.outer, sigma);

    canvas.drawOval(ovalRect, glowPaint);

    // ===== طبقة توهّج داخلية خفيفة لعمق بصري =====
    // تعطي إحساس أن الإطار نفسه يشعّ من الداخل.
    final Paint innerGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.15
      ..color = edgeColor.withOpacity(ui.lerpDouble(0.18, 0.32, glow)!)
      ..maskFilter = MaskFilter.blur(BlurStyle.inner, sigma * 0.6)
      ..isAntiAlias = true;

    canvas.drawOval(ovalRect, innerGlowPaint);

    // ===== الحد الأساسي الحاد (Core Rim) =====
    // خط واضح يعطي تعريفًا قويًا للحافة فوق التوهّج.
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = edgeColor.withOpacity(0.95)
      ..isAntiAlias = true;

    canvas.drawOval(ovalRect, rimPaint);

    // ===== لمسة لمعان subtle highlight (اختياري لطيفة) =====
    // خط نصف دائري علوي شفاف يعطي إحساس لمعان خفيف (specular).
    final Path highlight = Path()
      ..addArc(ovalRect.deflate(strokeWidth * 0.8), math.pi * 1.05, math.pi * 0.9);
    final Paint highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.9
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(inside ? 0.12 : 0.08)
      ..isAntiAlias = true;
    canvas.drawPath(highlight, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant FrameMaskPainter old) {
    return inside       != old.inside ||
        glow         != old.glow ||
        strokeWidth  != old.strokeWidth ||
        dimColor     != old.dimColor ||
        activeColor  != old.activeColor ||
        inactiveColor!= old.inactiveColor;
  }
}
