import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/content_management_section.dart';

class ContentManagementScreen extends StatelessWidget {
  const ContentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: ContentManagementSection(),
      ),
    );
  }
}
