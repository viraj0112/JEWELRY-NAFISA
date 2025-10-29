import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/reports_section.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: ReportsSection(),
      ),
    );
  }
}
