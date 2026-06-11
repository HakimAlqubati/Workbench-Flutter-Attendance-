// =============================
// File: lib/features/face_liveness/widgets/screensaver.dart
// =============================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:battery_plus/battery_plus.dart';

class Screensaver extends StatelessWidget {
  final DateTime now;
  final Alignment alignment;
  final Offset offset;
  final bool blink;
  final VoidCallback onTap;

  const Screensaver({
    super.key,
    required this.now,
    required this.alignment,
    required this.offset,
    required this.blink,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Show hours and minutes (updated once a minute)
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now);

    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // Constrain the text container heights based on screen height to avoid overflow.
    final clockHeight = size.height * (isLandscape ? 0.3 : 0.22);
    final dateHeight = size.height * (isLandscape ? 0.08 : 0.05);

    // Static Logo (dimmed to save battery, prevent burn-in, and match the date opacity)
    final logoWidget = Opacity(
      opacity: 0.20, // Set to match the date brightness (0.20)
      child: Image.asset(
        'assets/icon/default-wb.png',
        width: isLandscape ? size.height * 0.4 : size.width * 0.5,
        height: isLandscape ? size.height * 0.4 : size.width * 0.5,
        fit: BoxFit.contain,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Stack(
            children: [
              // Battery Indicator (dimmed to save power)
              const Positioned(
                top: 20,
                right: 20,
                child: Opacity(
                  opacity: 0.4, // Adjusted for readability
                  child: BatteryIndicator(),
                ),
              ),
              
              // Clock, Date and Logo Area with Pixel Shifting
              Center(
                child: Transform.translate(
                  offset: offset,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Time fitted box
                        SizedBox(
                          width: double.infinity,
                          height: clockHeight,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            child: Text(
                              timeStr,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.35), // Adjusted for readability in dark environments
                                fontWeight: FontWeight.w900,
                                decoration: TextDecoration.none,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isLandscape ? 4 : 12),
                        // Date fitted box
                        SizedBox(
                          width: double.infinity,
                          height: dateHeight,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            child: Text(
                              dateStr,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.20), // Adjusted for readability
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isLandscape ? 16 : 32),
                        // Logo below Time and Date
                        logoWidget,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
