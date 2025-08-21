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
    final sv = int.tryParse(_screensaverCtrl.text.trim()) ?? 300;
    final rx = double.tryParse(_ovalRxCtrl.text.trim()) ?? kDefaultOvalRxPct;
    final ry = double.tryParse(_ovalRyCtrl.text.trim()) ?? kDefaultOvalRyPct;

    await SettingsStore.I.setCountdownSeconds(cd);
    await SettingsStore.I.setScreensaverSeconds(sv);
    await SettingsStore.I.setOvalRxPct(rx.clamp(0.1, 1.0));
    await SettingsStore.I.setOvalRyPct(ry.clamp(0.1, 1.0));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully')),
    );
  }

  Future<void> _saveAndOpenCamera() async {
    await _save();
    if (!mounted) return;
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
          IconButton(
            tooltip: 'Open Camera',
            onPressed: _saveAndOpenCamera,
            icon: const Icon(Icons.camera_alt_outlined),
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
              hint: '300',
              decimal: false,
            ),
            const SizedBox(height: 12),
            _numberField(
              label: 'Oval Width (Rx)',
              controller: _ovalRxCtrl,
              hint: kDefaultOvalRxPct.toString(),
              decimal: true,
              formatters: [
                RangeTextInputFormatter(min: 0.1, max: 1.0),
              ],
            ),
            const SizedBox(height: 12),
            _numberField(
              label: 'Oval Height (Ry)',
              controller: _ovalRyCtrl,
              hint: kDefaultOvalRyPct.toString(),
              decimal: true,
              formatters: [
                RangeTextInputFormatter(min: 0.1, max: 1.0),
              ],
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
