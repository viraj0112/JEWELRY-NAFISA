import 'package:flutter/material.dart';
import '../sections/dashboard_overview.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: DashboardOverview(), 
    );
  }
}