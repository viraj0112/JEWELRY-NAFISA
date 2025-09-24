import 'package:flutter/material.dart';
import '../sections/analytics_section.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: AnalyticsSection(), 
    );
  }
}