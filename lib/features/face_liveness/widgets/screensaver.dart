// =============================
// File: lib/features/face_liveness/widgets/screensaver.dart
// =============================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:battery_plus/battery_plus.dart';
import '../widgets/floating_logo.dart';

class Screensaver extends StatelessWidget {
  final DateTime now;
  final Alignment alignment;
  final bool blink;
  final VoidCallback onTap;

  const Screensaver({
    super.key,
    required this.now,
    required this.alignment,
    required this.blink,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat.Hms().format(now);
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            const FloatingLogo(),
            Align(
              alignment: alignment,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 80),
                opacity: blink ? 0 : 1,
                child: Container(
                  margin: const EdgeInsets.only(top: 60),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(timeStr,
                          style: const TextStyle(
                              color: Colors.white,
                              decoration: TextDecoration.none,
                              fontWeight: FontWeight.w900,
                              fontSize: 56,
                              shadows: [Shadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 3))])),
                      const SizedBox(height: 6),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          decoration: TextDecoration.none, // 👈 هنا أيضًا
                        ),
                      ),
                      const SizedBox(height: 12),
                      const BatteryIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BatteryIndicator extends StatefulWidget {
  const BatteryIndicator({super.key});

  @override
  State<BatteryIndicator> createState() => _BatteryIndicatorState();
}

class _BatteryIndicatorState extends State<BatteryIndicator> {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchBatteryLevel();
    // Update battery level every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _fetchBatteryLevel());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() {
          _batteryLevel = level;
        });
      }
    } catch (e) {
      // Ignore if failed (e.g. unsupported platform)
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWarning = _batteryLevel <= 20;
    final color = isWarning ? Colors.redAccent : Colors.white;
    final icon = isWarning
        ? Icons.battery_alert
        : _batteryLevel >= 95
            ? Icons.battery_full
            : _batteryLevel >= 80
                ? Icons.battery_6_bar
                : _batteryLevel >= 60
                    ? Icons.battery_5_bar
                    : _batteryLevel >= 40
                        ? Icons.battery_4_bar
                        : Icons.battery_3_bar;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 6),
        Text(
          '$_batteryLevel%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
