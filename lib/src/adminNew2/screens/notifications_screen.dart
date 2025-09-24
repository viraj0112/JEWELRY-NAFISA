import 'package:flutter/material.dart';
import '../sections/notifications_section.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child:NotificationsSection(), 
    );
  }
}