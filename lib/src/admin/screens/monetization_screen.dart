// admin/screens/monetization_screen.dart
import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/monetization_section.dart';

class MonetizationScreen extends StatelessWidget {
  const MonetizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: MonetizationSection(),
      ),
    );
  }
}
