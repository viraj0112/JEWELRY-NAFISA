import 'package:flutter/material.dart';
import '../sections/users_section.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: UsersSection(), 
    );
  }
}