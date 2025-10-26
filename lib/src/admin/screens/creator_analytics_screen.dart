import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/creator_analytics_section.dart';

class CreatorAnalyticsScreen extends StatelessWidget {
  final String creatorId;
  final String? creatorName;

  const CreatorAnalyticsScreen({
    super.key,
    required this.creatorId,
    this.creatorName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(creatorName ?? 'Creator Analytics'),
        elevation: 1,
        shadowColor: Colors.black,
      ),
      body: CreatorAnalyticsSection(
        creatorId: creatorId,
      ),
    );
  }
}
