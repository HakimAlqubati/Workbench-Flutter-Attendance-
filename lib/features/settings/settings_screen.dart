import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/features/face_liveness/constants.dart';
import 'package:my_app/features/settings/settings_store.dart';

const primaryColor = Color(0xFF0d7c66);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _countdownCtrl;
  late final TextEditingController _screensaverCtrl;
  late final TextEditingController _ovalRxCtrl;
  late final TextEditingController _ovalRyCtrl;

  @override
  void initState() {
    super.initState();
    final s = SettingsStore.I.value;
    _countdownCtrl = TextEditingController(text: s.countdownSeconds.toString());
    _screensaverCtrl = TextEditingController(text: s.screensaverSeconds.toString());
    _ovalRxCtrl = TextEditingController(text: s.ovalRxPct.toStringAsFixed(2));
    _ovalRyCtrl = TextEditingController(text: s.ovalRyPct.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _countdownCtrl.dispose();
    _screensaverCtrl.dispose();
    _ovalRxCtrl.dispose();
    _ovalRyCtrl.dispose();
    super.dispose();
  }



  Future<void> _save() async {
    final cd = int.tryParse(_countdownCtrl.text.trim()) ?? 5;
    final sv = (int.tryParse(_screensaverCtrl.text.trim()) ?? 59).clamp(15, 59).toInt();

    double? _validateOrFallback(String text, double fallback) {
      if (text.trim().isEmpty) return fallback;

      final v = double.tryParse(text.trim());
      if (v == null || v < 0.1 || v > 0.5) return null;
      return double.parse(v.toStringAsFixed(2));
    }

    final rx = _validateOrFallback(_ovalRxCtrl.text, kDefaultOvalRxPct);
    final ry = _validateOrFallback(_ovalRyCtrl.text, kDefaultOvalRyPct);

    if (rx == null || ry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Oval Rx and Ry must be between 0.1 and 0.5 if provided.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // تحديث الحقول بالنص النهائي
    _ovalRxCtrl.text = rx.toStringAsFixed(2);
    _ovalRyCtrl.text = ry.toStringAsFixed(2);

    await SettingsStore.I.setCountdownSeconds(cd);
    await SettingsStore.I.setScreensaverSeconds(sv);
    await SettingsStore.I.setOvalRxPct(rx);
    await SettingsStore.I.setOvalRyPct(ry);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully')),
    );

    Navigator.pushNamed(context, '/face-liveness');
  }


  Widget _numberField({
    required String label,
    required TextEditingController controller,
    String? suffix,
    String? hint,
    bool decimal = false,
    List<TextInputFormatter>? formatters,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primaryColor.withOpacity(0.4)),
      ),
      color: Colors.white.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: formatters ??
                    <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                        RegExp(decimal ? r'^\d*\.?\d{0,6}' : r'^\d*'),
                      ),
                    ],
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  border: InputBorder.none,
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                cursorColor: primaryColor,
              ),
            ),
            if (suffix != null)
              Text(
                suffix,
                style: const TextStyle(color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsStore.I.value;

    return Scaffold(
      backgroundColor: const Color(0xFF0b1e1a),
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Settings'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _numberField(
              label: 'Countdown (seconds)',
              controller: _countdownCtrl,
              suffix: 'sec',
              hint: '5',
              decimal: false,
            ),
            const SizedBox(height: 12),
            _numberField(
              label: 'Screensaver (seconds)',
              controller: _screensaverCtrl,
              suffix: 'sec',
              hint: '59',
              decimal: false,
              // formatters: [
              //   RangeTextInputFormatter(min: 15, max: 59), // ✅ أضف هذا السطر
              // ],
            ),
            const SizedBox(height: 12),
            _numberField(
              label: 'Oval Width (Rx)',
              controller: _ovalRxCtrl,
              hint: kDefaultOvalRxPct.toString(),
              decimal: true,
              // formatters: [
              //   RangeTextInputFormatter(min: 0.1, max: 1.0),
              // ],
            ),
            const SizedBox(height: 12),
            _numberField(
              label: 'Oval Height (Ry)',
              controller: _ovalRyCtrl,
              hint: kDefaultOvalRyPct.toString(),
              decimal: true,
              // formatters: [
              //   RangeTextInputFormatter(min: 0.1, max: 1.0),
              // ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Face Recognition'),
              subtitle: const Text('Turn on to check faces against database'),
              value: s.enableFaceRecognition,
              activeColor: primaryColor,
              onChanged: (v) async {
                await SettingsStore.I.setEnableFaceRecognition(v);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Save Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RangeTextInputFormatter extends TextInputFormatter {
  final double min;
  final double max;

  RangeTextInputFormatter({required this.min, required this.max});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty || text == ".") return newValue;

    final value = double.tryParse(text);
    if (value == null) return oldValue;
    if (value < min || value > max) return oldValue;

    return newValue;
  }
}
