import 'package:flutter/material.dart';

class BigActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onPressed;
  final bool disabled;

  const BigActionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.onPressed,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: disabled 
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not allowed.')),
              );
            }
          : onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
