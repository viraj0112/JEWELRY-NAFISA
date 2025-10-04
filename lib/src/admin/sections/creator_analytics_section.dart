import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';

class CreatorAnalyticsSection extends StatelessWidget {
  const CreatorAnalyticsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Text('Creator Analytics',
            style:
                GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        const StyledCard(
          child: Center(
            child: Text(
              'Creator-specific analytics and charts will be displayed here.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const ChartGrid(),
      ],
    );
  }
}
