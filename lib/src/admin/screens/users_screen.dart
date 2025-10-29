import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/users_section.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: const Padding(padding: EdgeInsets.all(24.0), child: UsersSection()),
    );
  }
}
