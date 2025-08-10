import 'package:flutter/material.dart';

class SocialAuthButton extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;
  final VoidCallback onPressed; // Changed from a placeholder

  const SocialAuthButton({
    super.key,
    required this.text,
    required this.backgroundColor,
    this.textColor = Colors.white,
    required this.icon,
    required this.onPressed, // Added this required parameter
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: textColor),
      label: Text(text, style: TextStyle(color: textColor, fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 2,
      ),
      onPressed: onPressed, // Use the passed-in function
    );
  }
}