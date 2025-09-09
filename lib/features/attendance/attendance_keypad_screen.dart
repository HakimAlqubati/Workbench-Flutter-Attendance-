import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/core/network_helper.dart';
import '../settings/settings_screen.dart';
import '../settings/settings_store.dart';
import '../../theme/app_theme.dart';
import 'attendance_service.dart';
import 'widgets/app_toast.dart';
// import 'package:my_app/theme/app_theme.dart';
class AttendanceKeypadScreen extends StatefulWidget {
  const AttendanceKeypadScreen({super.key});

  @override
  State<AttendanceKeypadScreen> createState() => _AttendanceKeypadScreenState();
}

class _AttendanceKeypadScreenState extends State<AttendanceKeypadScreen> with SingleTickerProviderStateMixin {
  String _input = "";
  bool _loading = false;
  String _apiMessage = "";
  bool? _apiSuccess;
  bool _toastShow = false;

  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  late final AnimationController _glowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
    // منع الرجوع بالـ back عن طريق السحب (اختياري)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _glowCtrl.dispose();
    super.dispose();
  }

  String get _digitalClock {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  void _onToastClose() {
    setState(() {
      _toastShow = false;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _apiMessage = "";
        _apiSuccess = null;
      });
    });
  }

  void _onDigitPress(int digit) {
    if (_input.length < 10) {
      setState(() => _input += digit.toString());
    }
  }

  void _onBackspace() {
    if (_input.isNotEmpty) {
      setState(() => _input = _input.substring(0, _input.length - 1));
    }
  }

  void _onClear() => setState(() => _input = "");

  Future<void> _onSubmit() async {
    final connected = await NetworkHelper.checkAndToastConnection();
    if (!connected) {
      return;
    }
    if (_input.isEmpty) return;
    setState(() {
      _loading = true;
      _apiMessage = "";
      _apiSuccess = null;
    });

    try {
      // إن كان لديك توكن مخزّن مثلاً:
      // final token = await AuthService().getToken();
      final res = await AttendanceService.storeByRfid(
        rfid: _input,
        dateTime: formatDateTime(DateTime.now()),
        headers: {
          // "Authorization": "Bearer $token",
        },
      );

      setState(() {
        _apiSuccess = res.ok;
        _apiMessage = res.message;
        _toastShow = true;
        if (res.ok) _input = "";
      });
    } catch (_) {
      setState(() {
        _apiSuccess = false;
        _apiMessage = "Error connecting to server.";
        _toastShow = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // خلفية شعاعية (radial)
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.4, 0.9),
                radius: 1.1,
                colors: [
                  Color(0xFFB7FFE5), // #b7ffe5
                  Color(0xFF0D7C66), // #0d7c66
                  Color(0xFF02291F), // #02291f
                ],
                stops: [0.0, 0.7, 1.0],
              ),
            ),
          ),

          // بطاقة زجاجية في الوسط
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              width: 370,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.40),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFF0D7C66), width: 4),
                boxShadow: const [
                  BoxShadow(color: Color(0x210D7C66), blurRadius: 40, offset: Offset(0, 8)),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // فقاعات ضوئية
                  Positioned(
                    right: -48,
                    top: -32,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFD0FFF5).withOpacity(.35),
                            const Color(0x000D7C66),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -32,
                    bottom: -56,
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: [
                            const Color(0xFFCAFFEE).withOpacity(.45),
                            const Color(0x000D7C66),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(120),
                      ),
                    ),
                  ),

                  // المحتوى
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 4),
                      // الوقت
                      Text(
                        _digitalClock,
                        style: const TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 26,
                          color: Color(0xFF09523E),
                          shadows: [
                            Shadow(color: Color(0xCCFFFFFF), blurRadius: 8, offset: Offset(0, 2)),
                            Shadow(color: Color(0x770D7C66), blurRadius: 1, offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // شاشة الإدخال
                      Container(
                        height: 80,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.90),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0x260D7C66), width: 1),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _input.isEmpty ? "—" : _input,
                          style: TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 34,
                            color: _input.isEmpty ? Colors.grey.shade400 : const Color(0xFF0D7C66),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 6,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // أزرار الأرقام
                      GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final n in [1,2,3,4,5,6,7,8,9]) _DigitButton(text: "$n", onTap: () => _onDigitPress(n)),
                          _BackspaceButton(onTap: _onBackspace),
                          _DigitButton(text: "0", onTap: () => _onDigitPress(0)),
                          _ClearButton(onTap: _onClear),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // زر البصمة
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_input.isEmpty || _loading) ? null : _onSubmit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                            // تدرّج الخلفية عبر Ink
                            backgroundColor: Colors.transparent,
                            shadowColor: const Color(0x1C0D7C66),
                            elevation: 8,
                          ).merge(ButtonStyle(
                            // نستخدم MaterialStateProperty لتلوين الخلفية بالتدرّج
                            backgroundColor: MaterialStateProperty.resolveWith((states) => Colors.transparent),
                          )),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0D7C66), Color(0xFF1BE69E), Color(0xFF8BFFE7)],
                              ),
                              border: Border.fromBorderSide(BorderSide(color: const Color(0x330D7C66))),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              child: AnimatedBuilder(
                                animation: _glowCtrl,
                                builder: (_, __) {
                                  final t = (_glowCtrl.value - .5).abs(); // 0..0.5..0
                                  final blur = 8 + (1 - t) * 12;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_loading)
                                        const Padding(
                                          padding: EdgeInsets.only(bottom: 8.0),
                                          child: SizedBox(
                                            width: 36, height: 36,
                                            child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white),
                                          ),
                                        ),
                                      Icon(
                                        Icons.fingerprint_rounded,
                                        size: 56,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(color: Colors.white.withOpacity(.9), blurRadius: blur),
                                          const Shadow(color: Colors.white, blurRadius: 2),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // التوست
          AppToast(
            message: _apiMessage,
            show: _toastShow && _apiMessage.isNotEmpty,
            success: _apiSuccess == true,
            onClose: _onToastClose,
          ),
        ],
      ),
    );
  }
}

/// زر رقم بدون توهج
class _DigitButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _DigitButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64, width: 64,
      child: Material(
        color: Colors.white.withOpacity(.95),
        borderRadius: BorderRadius.circular(18),
        elevation: 3,
        shadowColor: const Color(0x1A0D7C66),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: const Color(0x330D7C66),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF0D7C66),
                fontSize: 26,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackspaceButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64, width: 64,
      child: Material(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(18),
        elevation: 2,
        shadowColor: const Color(0x170D7C66),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: const Center(
            child: Icon(Icons.backspace_outlined, color: Color(0xFFC0392B), size: 26),
          ),
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64, width: 64,
      child: Material(
        color: const Color(0xFFFFF6F6),
        borderRadius: BorderRadius.circular(18),
        elevation: 2,
        shadowColor: const Color(0x17B41E1E),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: const Center(
            child: Icon(Icons.delete_forever_rounded, color: Color(0xFFD43843), size: 28),
          ),
        ),
      ),
    );
  }
}
