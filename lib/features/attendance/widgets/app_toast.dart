import 'package:flutter/material.dart';

class AppToast extends StatefulWidget {
  final String message;
  final bool show;
  final bool success;
  final VoidCallback onClose;
  final Duration duration;

  const AppToast({
    super.key,
    required this.message,
    required this.show,
    required this.success,
    required this.onClose,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<AppToast> with SingleTickerProviderStateMixin {
  @override
  void didUpdateWidget(covariant AppToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && widget.message.isNotEmpty) {
      Future.delayed(widget.duration, () {
        if (mounted) widget.onClose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();

    final gradient = widget.success
        ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF14B8A6)]) // emerald → teal
        : const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEF4444)]); // red tones

    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: widget.onClose,
          child: Container(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 380),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(.2), width: 1),
              boxShadow: const [
                BoxShadow(color: Color(0x210D7C66), blurRadius: 24, offset: Offset(0, 4)),
              ],
            ),
            child: Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
