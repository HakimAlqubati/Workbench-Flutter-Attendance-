// lib/features/splash/splash_gate.dart
import 'package:flutter/material.dart';
import 'package:my_app/core/config/base_url_store.dart';
import 'package:my_app/features/face_liveness/constants.dart';
import 'package:my_app/core/navigation/routes.dart'; // يحوي AppRoutes

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    // نؤخر التنقل لما بعد أول فريم
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final saved = await BaseUrlStore.get(); // يقرأ من SharedPreferences

    if (!mounted) return;

    if (saved == null || saved.isEmpty) {
      // أول تشغيل: ما في URL محفوظ → افتح شاشة الإدخال
      Navigator.of(context).pushReplacementNamed(AppRoutes.enterBaseUrl);
    } else {
      // موجود: ثبت القيمة واكمل للوجن
      kApiBaseUrl = saved; // مهم قبل استعمال أي endpoint
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    // شاشة سبلاش خفيفة أثناء القرار
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
