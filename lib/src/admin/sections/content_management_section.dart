import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ContentManagementSection extends StatelessWidget {
  const ContentManagementSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Content Management Section - Coming Soon',
        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }
}