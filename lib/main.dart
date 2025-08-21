import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:my_app/theme/app_theme.dart'; // ← هنا


import 'features/auth/login_screen.dart';
import 'features/face_liveness/face_liveness_screen.dart';
import 'features/face_liveness/services/auth_service.dart';

// الإعدادات
import 'features/settings/settings_store.dart';
import 'features/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ثبّت الوضع الطولي
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // منع قفل الشاشة أثناء التشغيل
  await WakelockPlus.enable();

  // تهيئة مخزن الإعدادات قبل تشغيل التطبيق
  await SettingsStore.I.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Face Liveness',
      theme:appTheme,
      // ملاحظة: وجود home يجعل initialRoute غير فعّال؛ نُبقي home فقط.
      home: const SplashGate(),
      routes: {
        '/face-liveness': (_) => const FaceLivenessScreen(),
        '/login': (_) => const LoginScreen(),
        '/settings': (_) => const SettingsScreen(), // شاشة الإعدادات
      },
    );
  }
}

/// شاشة بسيطة تتحقق من وجود توكن وتحدد الوجهة
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
    // (SettingsStore.I.init() تم استدعاؤه في main)
    final session = await _auth.getSavedSession();
    if (!mounted) return;

    if (session != null && session.token.isNotEmpty) {
      // عنده توكن محفوظ → ادخله مباشرة للصفحة الرئيسية
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // لا يوجد توكن → اعرض شاشة الدخول
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openCamera(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FaceLivenessScreen()),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.pushNamed(context, '/settings');
  }

  void _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final auth = AuthService();
    await auth.logout(); // حذف التوكن أو بيانات الجلسة

    if (!context.mounted) return;

    // الرجوع إلى شاشة الدخول
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You have been logged out')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Face Liveness"),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _openCamera(context),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
