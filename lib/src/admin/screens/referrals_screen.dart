import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/referrals_section.dart';

class ReferralsScreen extends StatelessWidget {
  const ReferralsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Consistent padding for all new screens
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: ReferralsSection(),
    );
  }
}