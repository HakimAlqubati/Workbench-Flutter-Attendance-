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
  late final TextEditingController _baseUrlCtrl;

  double ovalRx = kDefaultOvalRxPct;
  double ovalRy = kDefaultOvalRyPct;

  @override
  void initState() {
    super.initState();
    final s = SettingsStore.I.value;
    _baseUrlCtrl = TextEditingController(text: SettingsStore.I.value.baseUrl);
    _countdownCtrl = TextEditingController(text: s.countdownSeconds.toString());
    _screensaverCtrl = TextEditingController(text: s.screensaverSeconds.toString());
    ovalRx = s.ovalRxPct;
    ovalRy = s.ovalRyPct;
  }

  @override
  void dispose() {
    _countdownCtrl.dispose();
    _screensaverCtrl.dispose();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  void _adjustOvalValue(bool isRx, double delta) {
    setState(() {
      double current = isRx ? ovalRx : ovalRy;
      double updated = (current + delta).clamp(0.1, 0.5);
      if (isRx) {
        ovalRx = double.parse(updated.toStringAsFixed(2));
      } else {
        ovalRy = double.parse(updated.toStringAsFixed(2));
      }
    });
  }

  Future<void> _save() async {
    final cd = int.tryParse(_countdownCtrl.text.trim()) ?? 5;
    final sv = (int.tryParse(_screensaverCtrl.text.trim()) ?? 30).clamp(15, 30).toInt();

    await SettingsStore.I.setCountdownSeconds(cd);
    await SettingsStore.I.setScreensaverSeconds(sv);
    await SettingsStore.I.setOvalRxPct(ovalRx);
    await SettingsStore.I.setOvalRyPct(ovalRy);

    final base = _baseUrlCtrl.text.trim();
    await SettingsStore.I.setBaseUrl(base);

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
                textAlign: TextAlign.center,
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

  Widget _adjustableField({
    required String label,
    required double value,
    required double defaultValue,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label: ${value.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    'Default: ${defaultValue.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.white70,
              onPressed: onDecrement,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: Colors.white70,
              onPressed: onIncrement,
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
            Row(
              children: [
                Expanded(
                  child: _numberField(
                    label: 'Countdown',
                    controller: _countdownCtrl,
                    // suffix: 'sec',
                    hint: 'Default: 5',
                    decimal: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField(
                    label: 'Screensaver',
                    controller: _screensaverCtrl,
                    // suffix: 'sec',
                    hint: 'Default: 59 (min: 15)',
                    decimal: false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            _adjustableField(
              label: 'Oval Width (Rx)',
              value: ovalRx,
              defaultValue: kDefaultOvalRxPct,
              onIncrement: () => _adjustOvalValue(true, 0.01),
              onDecrement: () => _adjustOvalValue(true, -0.01),
            ),
            const SizedBox(height: 12),
            _adjustableField(
              label: 'Oval Height (Ry)',
              value: ovalRy,
              defaultValue: kDefaultOvalRyPct,
              onIncrement: () => _adjustOvalValue(false, 0.01),
              onDecrement: () => _adjustOvalValue(false, -0.01),
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
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: primaryColor.withOpacity(0.4)),
              ),
              color: Colors.white.withOpacity(0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  controller: _baseUrlCtrl,
                  keyboardType: TextInputType.url, // نصي عادي (URL مناسب هنا)
                  decoration: const InputDecoration(
                    labelText: 'Server Base URL',
                    hintText: 'Default: http://47.130.152.211:5000',
                    border: InputBorder.none,
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                  cursorColor: primaryColor,
                ),
              ),
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

            const SizedBox(height: 12),
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
