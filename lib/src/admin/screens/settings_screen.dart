import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/settings_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: SettingsSection(), 
    );
  }
}