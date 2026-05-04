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

  String _buildFinalUrl(String tenant) {
    final t = tenant.trim().toLowerCase();
    return 'https://$t.nltworkbench.com';
    // return 'https://workbench.ressystem.com';
  }

  String? _validate(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Tenant name is required';
    if (s.contains(' ')) return 'Tenant name cannot contain spaces';
    if (s.contains('/') || s.contains('.'))
      return 'Please enter only the tenant name (no dots or slashes)';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final url = _buildFinalUrl(_controller.text);
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
                  const Text(
                    'Workspace Setup',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter your workspace tenant name below.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _controller,
                    keyboardType: TextInputType.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                    decoration: InputDecoration(
                      // prefixText: 'https://',
                      // suffixText: '.nltworkbench.com',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      // prefixIcon: const Icon(Icons.domain),
                    ),
                    validator: _validate,
                    onFieldSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save and Continue',
                        style: TextStyle(fontSize: 16),
                      ),
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
