import 'package:flutter/material.dart';
import '../sections/reports_section.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: ReportsSection(), 
    );
  }
}