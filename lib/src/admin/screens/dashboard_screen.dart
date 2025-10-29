import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/dashboard_section.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: DashboardSection(),
      ),
    );
  }
}
