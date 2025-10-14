import 'package:flutter/material.dart';
import 'package:my_app/core/network_helper.dart';
import 'package:my_app/core/toast_utils.dart';
import 'package:my_app/features/face_liveness/services/auth_service.dart';
import 'dart:ui';

import 'package:platform_device_id_plus/platform_device_id.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}


class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  final _auth = AuthService();

  @override
  void initState()   {
    super.initState();

     _getDeviceId();
    // فقط أثناء التطوير، املأ الحقول افتراضيًا
    assert(() {
      _emailCtrl.text = 'admin@admin.com';
      _passCtrl.text = '123456';
      return true;
    }());
  }

  Future<String?> getDeviceUniqueId() async {
    String? deviceId;
    try {
      deviceId = await PlatformDeviceId.deviceInfoPlugin.androidInfo
          .then<String?>((androidInfo) {
        if (androidInfo.version.sdkInt <= 30) {

          debugPrint('androidInfo.serialNumber_${androidInfo.serialNumber}');
          debugPrint('cn1_${deviceId}');

          return androidInfo.serialNumber.replaceAll('.', '');
        } else {
          debugPrint('cn2_${deviceId}');

          final id =  PlatformDeviceId.getDeviceId;

          debugPrint('cn3_${id}');

          return id;
        }

      }).catchError((error) {

        showCustomToast(message: "Error getting Android device ID: $error",backgroundColor: AppColors.primaryColor,
        );
        return null;
      });
      return deviceId;
    } catch (e, stackTrace) {


      return null;
    }
  }

  String? deviceId;
    _getDeviceId() async {
    deviceId = await getDeviceUniqueId();

    debugPrint('DEVICEID${deviceId.toString()}');
    showCustomToast(message: deviceId!);
    setState(() {

    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // 🛡️ تحقق من الاتصال قبل المتابعة
    final connected = await NetworkHelper.checkAndToastConnection();
    if (!connected) return;

    setState(() { _loading = true; _error = null; });
    try {
      await _auth.login(
        username: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      // بعد النجاح ادخل المستخدم إلى شاشتك الرئيسية
      Navigator.of(context).pushReplacementNamed('/');
    } catch (e) {
      setState(() => _error = 'Sign-in failed. ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // خلفية متدرجة داكنة
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B2A2E), // teal-dk
              Color(0xFF082126),
              Color(0xFF0A1B1E),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // هالة توهج خارجية خلف البطاقة
                Container(
                  width: double.infinity,
                  height: 420,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF19E6C1).withOpacity(.18),
                        blurRadius: 80,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),

                // البطاقة الزجاجية
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 56, 22, 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1518).withOpacity(.55),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF19E6C1).withOpacity(.45),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF19E6C1).withOpacity(.22),
                            blurRadius: 24,
                            spreadRadius: 0.8,
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 14),
                            const Text(
                              'Sign in to Workbench Attendance',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Email
                            _NeonField(
                              label: 'Email',
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Please enter your email'
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            // Password
                            _NeonField(
                              label: 'Password',
                              controller: _passCtrl,
                              obscureText: _obscure,
                              validator: (v) =>
                              (v == null || v.isEmpty)
                                  ? 'Please enter your password'
                                  : null,
                              suffix: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                color: const Color(0xFF19E6C1),
                                tooltip: _obscure ? 'Show' : 'Hide',
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Error
                            if (_error != null) ...[
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFFF6B6B),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Sign In Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10BFA3),
                                  foregroundColor: Colors.white,
                                  shadowColor:
                                  const Color(0xFF19E6C1).withOpacity(.6),
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: const Color(0xFF19E6C1)
                                          .withOpacity(.6),
                                      width: 1.2,
                                    ),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.3,
                                    fontSize: 16,
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                                    : const Text('SIGN IN'),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Footer
                            const Text(
                              '© 2025 Workbench',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: .2,
                              ),

                            ),
                            IconButton(
                              tooltip: 'Reload Device ID',
                              icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
                              onPressed: (){
                                setState(() {

                                  getDeviceUniqueId();
                                });
                              }, // ← ينادي الدالة
                            ),
                            // if (deviceId != null) ...[
                            //   const SizedBox(height: 8),
                            //   Text(
                            //     'Device ID: $_getDeviceId',
                            //     textAlign: TextAlign.center,
                            //     style: const TextStyle(
                            //       color: Colors.white70,
                            //       fontSize: 12,
                            //       letterSpacing: .3,
                            //     ),
                            //   ),
                            // ],

                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // فتحة دائرية متوهّجة أعلى البطاقة (الديكور)
                Positioned(
                  top: 12,
                  child: Container(
                    width: 88,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.rectangle,
                    ),
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF19E6C1).withOpacity(.35),
                                blurRadius: 40,
                                spreadRadius: 6,
                              ),
                            ],
                            gradient: const RadialGradient(
                              colors: [Color(0xFF19E6C1), Color(0xFF0A1B1E)],
                              radius: .8,
                            ),
                          ),
                        ),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF19E6C1).withOpacity(.6),
                              width: 1.2,
                            ),
                            color: const Color(0xFF0E1F22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// حقل نصّي بستايل نيون/زجاجي
class _NeonField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Widget? suffix;

  const _NeonField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    const neon = Color(0xFF19E6C1);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(.9)),
        filled: true,
        fillColor: const Color(0xFF0A1518).withOpacity(.35),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: neon.withOpacity(.55), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neon, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
        ),
        suffixIcon: suffix == null
            ? null
            : Padding(
          padding: const EdgeInsets.only(right: 6),
          child: suffix,
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 42),
      ),
    );
  }
}
