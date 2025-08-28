import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:my_app/theme/app_theme.dart'; // يستخدم الثيم الذي أرسلته

import 'features/auth/login_screen.dart';
import 'features/face_liveness/face_liveness_screen.dart';
import 'features/face_liveness/services/auth_service.dart';

// الإعدادات
import 'features/settings/settings_store.dart';
import 'features/settings/settings_screen.dart';

/// ========== علامة مائية عامة ==========
class AppWatermark extends StatelessWidget {
  const AppWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: 0.06, // خفيفة وغير مزعجة
          child: Image.asset(
            'assets/icon/default-wb.png',
            width: 280,
            fit: BoxFit.contain,
          ),
          // child: Image.network(
          //   'https://nltworkbench.com/storage/logo/default-wb.png',
          //   width: 280,
          //   fit: BoxFit.contain,
          // ),
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await WakelockPlus.enable();
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
      theme: appTheme, // ✅ التزام كامل بثيمك
      home: const SplashGate(),
      routes: {
        '/face-liveness': (_) => const FaceLivenessScreen(),
        '/login': (_) => const LoginScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

/// شاشة انتقالية تتحقق من الجلسة
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
    final session = await _auth.getSavedSession();
    if (!mounted) return;

    if (session != null && session.token.isNotEmpty) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // مؤشر تحميل بسيط — لا ألوان خارج الثيم
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: const [
          AppWatermark(), // ← العلامة المائية بالخلف
          Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // إضافة مراقب دورة الحياة
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // إزالة المراقب
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('AppLifecycleState: $state'); // لتتبع الحالة
    if (state == AppLifecycleState.resumed) {
      // عند العودة إلى التطبيق من الخلفية
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/', // الشاشة الرئيسية
        (Route<dynamic> route) => false, // إزالة جميع الشاشات الأخرى
      );
    }
  }

  void _openCamera(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FaceLivenessScreen()),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.pushNamed(context, '/settings');
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
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
    await auth.logout();

    if (!context.mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('You have been logged out')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Face Liveness"),
        // ✅ يعتمد على appBarTheme في ثيمك
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ← العلامة المائية بالخلف
          const AppWatermark(),

          // محتوى الشاشة فوق العلامة
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // أزرار كبيرة باستخدام ElevatedButtonTheme من ثيمك
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _BigActionButton(
                        icon: Icons.camera_alt_outlined,
                        title: 'Start Camera',
                        onPressed: () => _openCamera(context),
                      ),
                      _BigActionButton(
                        icon: Icons.settings_suggest_rounded,
                        title: 'Settings',
                        onPressed: () => _openSettings(context),
                      ),
                    ],
                  ),
                ),

                TextButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onPressed;

  const _BigActionButton({
    required this.icon,
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // لا تثبّت اللون حتى يأخذه من الثيم/الزر تلقائيًا
          Icon(icon, size: 36),

          // لو تبغى لونًا ثابتًا عالي التباين، استخدم التالي بدل السطر أعلاه:
          // Icon(icon, size: 36, color: cs.onPrimary),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
