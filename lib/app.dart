import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/features/face_liveness/views/face_liveness_screen.dart';
import 'package:my_app/theme/app_theme.dart';

import 'core/navigation/routes.dart';
import 'features/splash/splash_gate.dart';
import 'features/auth/login_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/attendance/attendance_keypad_screen.dart';

/// مدير خفيف لفرض وضع ملء الشاشة مع تجميع النداءات داخل الفريم نفسه
class FullScreenManager {
  FullScreenManager._();
  static final FullScreenManager _i = FullScreenManager._();
  factory FullScreenManager() => _i;

  bool _scheduled = false;

  void ensure() {
    if (_scheduled) return;
    _scheduled = true;
    // نجمع كل الطلبات داخل هذا الفريم لفَرْضة واحدة فقط
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scheduled = false;
      // Immersive sticky أنسب للكيـوسك/الكاميرا
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      // في حال خرج النظام من immersive (ببعض الأجهزة) نُعيد توحيد الـ style
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ));
    });
  }
}

/// مراقب نافيجيتور يعيد فرض ملء الشاشة عند كل تنقل
class _FullScreenObserver extends NavigatorObserver {
  final _fs = FullScreenManager();
  @override
  void didPush(Route route, Route? previousRoute) => _fs.ensure();
  @override
  void didPop(Route route, Route? previousRoute) => _fs.ensure();
  @override
  void didRemove(Route route, Route? previousRoute) => _fs.ensure();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _fs.ensure();
}

/// سلوك تمرير بدون وميض (خفة وأفضل جماليًا)
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // لا تضيف Glow على أندرويد
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _fs = FullScreenManager();

  void _forceFullscreen() => _fs.ensure();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // فرض ملء الشاشة عند البداية + بعد أول فريم
    _forceFullscreen();
    WidgetsBinding.instance.addPostFrameCallback((_) => _forceFullscreen());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _forceFullscreen(); // عند الرجوع من الخلفية
    }
  }

  @override
  void didChangeMetrics() {
    // عند تغيّر المقاييس (تدوير الجهاز، إظهار لوحة مفاتيح النظام…)
    _forceFullscreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Face Liveness',
      theme: appTheme, // ✅ لا نلمس الثيم
      home: const SplashGate(),
      routes: {
        AppRoutes.faceLiveness: (_) => const FaceLivenessScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.attendanceKeypad: (_) => const AttendanceKeypadScreen(),
      },
      navigatorObservers: [_FullScreenObserver()],
      scrollBehavior: const _AppScrollBehavior(),

      /// Builder خفيف يثبّت textScaleFactor ضمن نطاق منطقي ويحافظ على الثيم
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final mq = MediaQuery.of(context);
        final clampedScale = mq.textScaleFactor.clamp(0.9, 1.2);
        return MediaQuery(
          data: mq.copyWith(textScaleFactor: clampedScale),
          child: child,
        );
      },
    );
  }
}
