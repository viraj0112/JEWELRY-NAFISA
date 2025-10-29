import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/emails_section.dart';

class EmailsScreen extends StatelessWidget {
  const EmailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: EmailsSection(),
      ),
    );
  }
}
