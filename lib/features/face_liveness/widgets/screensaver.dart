// =============================
// File: lib/features/face_liveness/widgets/screensaver.dart
// =============================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:battery_plus/battery_plus.dart';

class Screensaver extends StatefulWidget {
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
  State<Screensaver> createState() => _ScreensaverState();
}

class _ScreensaverState extends State<Screensaver> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  double _posX = 0.0;
  double _posY = 0.0;
  double _vx = 90.0; // pixels per second
  double _vy = 75.0; // pixels per second

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }

    final double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    if (dt <= 0 || dt > 0.1) return; // Skip frame drop anomalies

    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final double areaWidth = size.width - padding.left - padding.right;
    final double areaHeight = size.height - padding.top - padding.bottom;

    final isLandscape = size.width > size.height;

    // Logo size proportional to screen width (39%, increased by 1.5x)
    double logoSize = (size.width * 0.39).clamp(120.0, 450.0);

    // Clock/Date details (shifted up)
    final double clockHeight = size.height * (isLandscape ? 0.3 : 0.22);
    final double dateHeight = size.height * (isLandscape ? 0.08 : 0.05);
    final double spacing = isLandscape ? 4.0 : 12.0;
    final double textHeight = clockHeight + dateHeight + spacing;

    // Aligned at Alignment(0, -0.6)
    final double centerY = areaHeight * (1.0 + (-0.6)) / 2;
    final double boxYMax = centerY + (textHeight / 2) + 60.0; // 60px padding below text to prevent overlap

    // Dynamic scaling of logo if there's not enough room in the bottom area (e.g. landscape)
    final double availableHeight = areaHeight - boxYMax;
    if (logoSize > availableHeight - 20.0) {
      logoSize = (availableHeight - 20.0).clamp(50.0, 450.0);
    }

    final double minY = boxYMax;
    final double maxY = areaHeight - logoSize;

    // Initial position setup if not initialized
    if (!_initialized) {
      _posX = 15.0;
      _posY = minY + 10.0;
      _initialized = true;
    }

    // Dynamic clamping to prevent getting stuck if size changes (e.g. rotation)
    if (_posX > areaWidth - logoSize) {
      _posX = areaWidth - logoSize;
      _vx = -_vx.abs();
    }

    final double currentMinY = minY;
    final double currentMaxY = maxY > minY ? maxY : minY + 5.0;
    if (_posY < currentMinY) {
      _posY = currentMinY;
      _vy = _vy.abs();
    } else if (_posY > currentMaxY) {
      _posY = currentMaxY;
      _vy = -_vy.abs();
    }

    double nextX = _posX + _vx * dt;
    double nextY = _posY + _vy * dt;

    // 1. Bounce off outer SafeArea boundaries (left and right)
    if (nextX <= 0) {
      nextX = 0;
      _vx = -_vx;
    } else if (nextX >= areaWidth - logoSize) {
      nextX = areaWidth - logoSize;
      _vx = -_vx;
    }

    // 2. Bounce off vertical bounds (restricted to bottom region)
    if (nextY <= currentMinY) {
      nextY = currentMinY;
      _vy = -_vy;
    } else if (nextY >= currentMaxY) {
      nextY = currentMaxY;
      _vy = -_vy;
    }

    setState(() {
      _posX = nextX;
      _posY = nextY;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show hours and minutes (updated once a minute)
    final timeStr = DateFormat('HH:mm').format(widget.now);
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(widget.now);

    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // Constrain the text container heights based on screen height to avoid overflow.
    final clockHeight = size.height * (isLandscape ? 0.3 : 0.22);
    final dateHeight = size.height * (isLandscape ? 0.08 : 0.05);

    // Logo size proportional to screen width (39%)
    double logoSize = (size.width * 0.39).clamp(120.0, 450.0);

    // Dynamic scaling of logo if there's not enough room in the bottom area (e.g. landscape)
    final padding = MediaQuery.of(context).padding;
    final double areaHeight = size.height - padding.top - padding.bottom;
    final double spacing = isLandscape ? 4.0 : 12.0;
    final double textHeight = clockHeight + dateHeight + spacing;
    final double centerY = areaHeight * (1.0 + (-0.6)) / 2;
    final double boxYMax = centerY + (textHeight / 2) + 60.0;
    final double availableHeight = areaHeight - boxYMax;
    if (logoSize > availableHeight - 20.0) {
      logoSize = (availableHeight - 20.0).clamp(50.0, 450.0);
    }

    return GestureDetector(
      onTap: widget.onTap,
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

              // Clock and Date Area with Pixel Shifting (Shifted Upwards)
              Align(
                alignment: const Alignment(0, -0.6),
                child: Transform.translate(
                  offset: widget.offset,
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
                      ],
                    ),
                  ),
                ),
              ),

              // Moving Logo (confined to bottom region)
              Positioned(
                left: _posX,
                top: _posY,
                child: Opacity(
                  opacity: 0.20, // Set to match the date brightness (0.20)
                  child: Image.asset(
                    'assets/icon/default-wb.png',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
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
