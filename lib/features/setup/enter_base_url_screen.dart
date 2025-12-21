// lib/features/setup/enter_base_url_screen.dart
import 'package:flutter/material.dart';
import 'package:my_app/core/config/base_url_store.dart';
import 'package:my_app/features/face_liveness/constants.dart';
import 'package:my_app/core/navigation/routes.dart';

class EnterBaseUrlScreen extends StatefulWidget {
  const EnterBaseUrlScreen({super.key});

  @override
  State<EnterBaseUrlScreen> createState() => _EnterBaseUrlScreenState();
}

class _EnterBaseUrlScreenState extends State<EnterBaseUrlScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  String _normalize(String url) {
    var u = url.trim();
    while (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  String? _validate(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Base URL is required';
    final ok = s.startsWith('http://') || s.startsWith('https://');
    if (!ok) return 'URL must start with http:// or https://';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final url = _normalize(_controller.text);
    await BaseUrlStore.set(url);
    kApiBaseUrl = url;
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter Base URL',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _controller,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      hintText: 'e.g. https://domain.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    validator: _validate,
                    onFieldSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save and Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
