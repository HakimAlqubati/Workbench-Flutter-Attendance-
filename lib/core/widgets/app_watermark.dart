import 'package:flutter/material.dart';

class AppWatermark extends StatelessWidget {
  const AppWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: 0.06,
          child: Image.network(
            'https://nltworkbench.com/storage/logo/default-wb.png',
            width: 280,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
