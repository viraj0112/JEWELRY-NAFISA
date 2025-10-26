import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/notifications_sections.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: NotificationsSection(),
    );
  }
}
