import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/creator_analytics_section.dart';

class CreatorAnalyticsScreen extends StatelessWidget {
  const CreatorAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: CreatorAnalyticsSection(),
    );
  }
}