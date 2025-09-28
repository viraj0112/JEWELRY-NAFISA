import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CreatorAnalyticsSection extends StatelessWidget {
  const CreatorAnalyticsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'B2B Creator Analytics Section - Coming Soon',
        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }
}