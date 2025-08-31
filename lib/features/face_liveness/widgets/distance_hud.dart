import 'package:flutter/material.dart';
import 'package:my_app/features/face_liveness/controllers/face_liveness_controller.dart';
import 'package:my_app/features/face_liveness/widgets/gclass.dart';

class DistanceHud extends StatelessWidget {
  final FaceLivenessController c;
  const DistanceHud({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final dist = c.estDistanceCm;
    final dRange = c.deltaToRangeCm;
    final center = c.centerScore; // 0..1
    final tooFar = c.tooFar;
    final tooClose = c.tooClose;

    String line1, line2;
    if (dist == null) {
      line1 = 'Distance: --';
      line2 = 'Fit: ${c.fitPct.toStringAsFixed(0)}%  •  Center: ${(center * 100).toStringAsFixed(0)}%';
    } else {
      String dir;
      if (dRange == null || dRange <= 0.0) dir = '✓ In range';
      else if (tooFar) dir = '↘ Move closer ${dRange.abs().round()} cm';
      else if (tooClose) dir = '↗ Move back ${dRange.abs().round()} cm';
      else dir = '✓ In range';

      line1 = '≈ ${dist.toStringAsFixed(0)} cm   •   $dir';
      line2 = 'Fit: ${c.fitPct.toStringAsFixed(0)}%  •  Center: ${(c.centerScore * 100).toStringAsFixed(0)}%';
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Glass(
          blur: 14, opacity: .18, radius: 16, border: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(line1, textAlign: TextAlign.center, style: const TextStyle(
              color: Color(0xffeafff3), fontWeight: FontWeight.w800, fontSize: 13.5,
              letterSpacing: .2, decoration: TextDecoration.none,
            )),
            const SizedBox(height: 4),
            Text(line2, textAlign: TextAlign.center, style: const TextStyle(
              color: Color(0xffc7ffdf), fontWeight: FontWeight.w700, fontSize: 12.5,
              letterSpacing: .2, decoration: TextDecoration.none,
            )),
          ]),
        ),
      ),
    );
  }
}
