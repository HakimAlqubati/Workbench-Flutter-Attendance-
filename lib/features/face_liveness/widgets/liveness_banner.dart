import 'package:flutter/material.dart';
import 'package:my_app/features/face_liveness/widgets/gclass.dart';

class LivenessBanner extends StatelessWidget {
  final Map<String, dynamic> json;
  const LivenessBanner({super.key, required this.json});

  @override
  Widget build(BuildContext context) {
    final status = json['status'];
    final ok = status == 'ok';
    final isNoMatch = status == 'no_match';

    IconData icon;
    Color color;
    if (ok)      { icon = Icons.verified_rounded;       color = const Color(0xff0fd86e); }
    else if (isNoMatch) { icon = Icons.error_rounded;   color = const Color(0xffff4d67); }
    else        { icon = Icons.warning_amber_rounded;   color = const Color(0xffffb74d); }

    final size = MediaQuery.of(context).size;
    return Positioned(
      top: size.height * 0.12, left: 16, right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Glass(
            blur: 14, opacity: .18, radius: 16, border: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Flexible(child: Text(
                _text(json),
                softWrap: true, overflow: TextOverflow.fade,
                style: TextStyle(
                  color: ok ? const Color(0xffd9ffe9)
                      : (isNoMatch ? const Color(0xffffe2e8) : const Color(0xfffff3e0)),
                  fontWeight: FontWeight.w800, fontSize: 14.5, letterSpacing: .2,
                  decoration: TextDecoration.none,
                ),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  String _text(Map<String, dynamic> j) {
    final status = j['status'];
    final msg = j['message'] ?? '';
    final error = j['error'];
    if (status == 'ok') {
      final score = j['result']?['score'] ?? j['score'];
      return 'Real face  (${score ?? '-'})';
    }
    if (status == 'no_match') {
      final score = j['result']?['score'] ?? j['score'];
      return '(${score ?? '-'})';
    }
    if (error != null) return '($error)';
    return msg.isNotEmpty ? msg : 'No clear face found';
  }
}
