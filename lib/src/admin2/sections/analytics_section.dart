import "package:flutter/material.dart";
import 'package:fl_chart/fl_chart.dart';

class AnalyticsSection extends StatefulWidget {
  const AnalyticsSection({super.key});
  @override
  State<AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<AnalyticsSection> {
  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Text("Analytics Screen"),
    );
  }
}
