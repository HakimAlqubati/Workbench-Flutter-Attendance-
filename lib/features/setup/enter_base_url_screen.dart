// lib/features/setup/enter_base_url_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:my_app/core/config/base_url_store.dart';
import 'package:my_app/features/face_liveness/constants.dart';
import 'package:my_app/core/navigation/routes.dart';

class EnterBaseUrlScreen extends StatefulWidget {
  const EnterBaseUrlScreen({super.key});

  @override
  State<EnterBaseUrlScreen> createState() => _EnterBaseUrlScreenState();
}

enum UrlInputMode { tenant, fullUrl }

class _EnterBaseUrlScreenState extends State<EnterBaseUrlScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  UrlInputMode _inputMode = UrlInputMode.tenant;

  String _buildFinalUrl(String input) {
    var trimmed = input.trim();
    if (_inputMode == UrlInputMode.fullUrl) {
      while (trimmed.endsWith('/')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
      return trimmed;
    } else {
      final t = trimmed.toLowerCase();
      return 'https://$t.nltworkbench.com';
    }
  }

  String? _validate(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) {
      return _inputMode == UrlInputMode.tenant
          ? 'Tenant name is required'
          : 'Workspace URL is required';
    }
    if (_inputMode == UrlInputMode.tenant) {
      if (s.contains(' ')) return 'Tenant name cannot contain spaces';
      if (s.contains('/') || s.contains('.')) {
        return 'Please enter only the tenant name (no dots or slashes)';
      }
    } else {
      if (!s.startsWith('http://') && !s.startsWith('https://')) {
        return 'URL must start with http:// or https://';
      }
      if (!s.contains('.')) {
        return 'Please enter a valid URL';
      }
    }
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
                  Text(
                    _inputMode == UrlInputMode.tenant
                        ? 'Enter your workspace tenant name below.'
                        : 'Enter your custom workspace URL below.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<UrlInputMode>(
                    segments: const [
                      ButtonSegment<UrlInputMode>(
                        value: UrlInputMode.tenant,
                        label: Text('Tenant Name'),
                        icon: Icon(Icons.domain),
                      ),
                      ButtonSegment<UrlInputMode>(
                        value: UrlInputMode.fullUrl,
                        label: Text('Full URL'),
                        icon: Icon(Icons.link),
                      ),
                    ],
                    selected: {_inputMode},
                    onSelectionChanged: (Set<UrlInputMode> newSelection) {
                      setState(() {
                        _inputMode = newSelection.first;
                        _controller.clear();
                        _formKey.currentState?.reset();
                      });
                    },
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _controller,
                    keyboardType: TextInputType.text,
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                    decoration: InputDecoration(
                      labelText: _inputMode == UrlInputMode.tenant
                          ? 'Tenant Name'
                          : 'Custom Workspace URL',
                      hintText: _inputMode == UrlInputMode.tenant
                          ? 'tenant'
                          : 'https://example.com',
                      prefixText: _inputMode == UrlInputMode.tenant ? 'https://' : null,
                      suffixText: _inputMode == UrlInputMode.tenant ? '.nltworkbench.com' : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(
                        _inputMode == UrlInputMode.tenant
                            ? Icons.domain
                            : Icons.link,
                      ),
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
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _inputMode = UrlInputMode.fullUrl;
                          _controller.text = 'https://workbenchro.ressystem.com/';
                        });
                      },
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Autofill Debug URL'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

