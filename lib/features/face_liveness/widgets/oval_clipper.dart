import 'package:flutter/widgets.dart';
import '../constants.dart';

class OvalClipper extends CustomClipper<Path> {
  final Size screenSize;
  const OvalClipper(this.screenSize);

  @override
  Path getClip(Size size) {
    final w = screenSize.width;
    final h = screenSize.height;

    final isLandscape = w > h;
    final shortSide = isLandscape ? h : w;
    final longSide = isLandscape ? w : h;

    final cx = w * (0.5 + kOvalCxOffsetPct);
    final cy = h * (0.5 + kOvalCyOffsetPct);
    final rx = (isLandscape ? shortSide : w) * kOvalRxPct;
    final ry = (isLandscape ? longSide : h) * kOvalRyPct;

    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    );
    return Path()..addOval(rect);
  }

  @override
  bool shouldReclip(covariant OvalClipper oldClipper) => false;
}
