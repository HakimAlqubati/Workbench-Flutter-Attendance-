import 'package:flutter/material.dart';
import 'package:my_app/core/navigation/routes.dart';
import 'package:my_app/core/widgets/app_watermark.dart';
import 'package:my_app/features/face_liveness/services/auth_service.dart';
import 'package:my_app/features/home/home_screen.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    try {
    final session = await _auth.getSavedSession();
    if (!mounted) return;

    if (session != null && session.token.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
    } catch (e, st) {
      debugPrint('SplashGate._go error: $e\n$st');
      if (!mounted) return;

      // fallback: لو صار أي خطأ نروح لشاشة تسجيل الدخول
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppWatermark(),
          Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
