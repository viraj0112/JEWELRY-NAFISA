import 'package:flutter/material.dart';
import '../sections/email_section.dart';

class EmailScreen extends StatelessWidget {
  const EmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: EmailSection(), 
    );
  }
}