import 'package:flutter/material.dart';
import 'gclass.dart';

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

  @override
  Widget build(BuildContext context) {
    final pct = (progress.clamp(0.0, 1.0) * 100).round();

    // نبني النص الفعّال دائماً: الحالة + النسبة من القيمة
    final status = brightnessText.trim().isNotEmpty ? brightnessText.split('-').first.trim() : '';
    final percent = (brightnessValue != null)
        ? ((brightnessValue!.clamp(0, 255) / 255) * 100).round()
        : null;

    // لو ما عندنا لا قيمة ولا حالة، نظهر Placeholder بسيط
    final effectiveText = (percent != null || status.isNotEmpty)
        ? '${status.isNotEmpty ? '$status  ' : ''}${percent != null ? '$percent%' : ''}'
        : 'Measuring light…';


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
                    const SizedBox(width: 8),
                    const Text(
                      '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // شريط Face fit
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xff1b1b1b).withOpacity(.65),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xff444444).withOpacity(.5)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFF4FC3F7), Color(0xFF3F51B5)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // سطر الإضاءة: نعرضه دائماً حتى لو Placeholder
                Row(
                  children: [
                    _InlineBrightnessChip(text: effectiveText),
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

/// Chip داخلية بديلة لتفادي أي سلوك غير متوقع في BrightnessChip
class _InlineBrightnessChip extends StatelessWidget {
  final String text;
  const _InlineBrightnessChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final isWarning = text.contains('❌') || text.toLowerCase().contains('dark') || text.toLowerCase().contains('bright');
    final bg = isWarning ? const Color(0x33FF4D67) : const Color(0x3332D37A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
