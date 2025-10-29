import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/activity_logs_section.dart';

class ActivityLogsScreen extends StatelessWidget {
  const ActivityLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: ActivityLogsSection(),
      ),
    );
  }
}
