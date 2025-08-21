// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// شاشة اللّيفنس بعد التقسيم
import 'features/face_liveness/face_liveness_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ثبّت الاتجاه عمودي (اختياري لكنه مفيد مع الكاميرا)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // منع قفل الشاشة ما دام التطبيق فعّال
  await WakelockPlus.enable();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Face Liveness',
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
      // (اختياري) تعريف route باسم
      routes: {
        '/face-liveness': (_) => const FaceLivenessScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openCamera(BuildContext context) {
    // إمّا تستخدم الـ route:
    // Navigator.pushNamed(context, '/face-liveness');

    // أو مباشرة:
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FaceLivenessScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Face Liveness"), centerTitle: true),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _openCamera(context),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          child: const Text("Open Camera", style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
