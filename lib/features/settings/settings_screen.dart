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

  double ovalRx = kDefaultOvalRxPct;
  double ovalRy = kDefaultOvalRyPct;
  int screensaver = 30; // القيمة الابتدائية

  @override
  void initState() {
    super.initState();
    final s = SettingsStore.I.value;
    _countdownCtrl = TextEditingController(text: s.countdownSeconds.toString());
    _screensaverCtrl = TextEditingController(text: s.screensaverSeconds.toString());
    screensaver = s.screensaverSeconds.clamp(15, 30);
    ovalRx = s.ovalRxPct;
    ovalRy = s.ovalRyPct;
  }

  @override
  void dispose() {
    _countdownCtrl.dispose();
    _screensaverCtrl.dispose();
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
    // final sv = (int.tryParse(_screensaverCtrl.text.trim()) ?? 30).clamp(15, 30).toInt();
    final sv = screensaver.clamp(15, 30);

    await SettingsStore.I.setCountdownSeconds(cd);
    await SettingsStore.I.setScreensaverSeconds(sv);
    await SettingsStore.I.setOvalRxPct(ovalRx);
    await SettingsStore.I.setOvalRyPct(ovalRy);



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
                    style: const TextStyle(color: Colors.white70,
                    fontSize: 18),

                  ),
                  Text(
                    'Default: ${defaultValue.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 15),
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
            _adjustableField(
              label: 'Countdown (sec)',
              value: int.parse(_countdownCtrl.text).toDouble(),
              defaultValue: 5,
              onIncrement: () {
                setState(() {
                  final v = int.tryParse(_countdownCtrl.text) ?? 5;
                  _countdownCtrl.text = (v + 1).toString();
                });
              },
              onDecrement: () {
                setState(() {
                  final v = int.tryParse(_countdownCtrl.text) ?? 5;
                  if (v > 1) _countdownCtrl.text = (v - 1).toString();
                });
              },
            ),


            _adjustableField(
              label: 'Screensaver',
              value: screensaver.toDouble(),
              defaultValue: 30,
              onIncrement: () {
                setState(() {
                  if (screensaver < 30) screensaver++;
                });
              },
              onDecrement: () {
                setState(() {
                  if (screensaver > 15) screensaver--;
                });
              },
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

            // const SizedBox(height: 16),
            // SwitchListTile(
            //   title: const Text('Enable Face Recognition'),
            //   subtitle: const Text('Turn on to check faces against database'),
            //   value: s.enableFaceRecognition,
            //   activeColor: primaryColor,
            //   onChanged: (v) async {
            //     await SettingsStore.I.setEnableFaceRecognition(v);
            //     if (mounted) setState(() {});
            //   },
            // ),

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
        )

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
