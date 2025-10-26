import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/b2b_creators_section.dart';

class B2BCreatorsScreen extends StatelessWidget {
  const B2BCreatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: B2BCreatorsSection(),
    );
  }
}
