import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';

class ActivityLogsSection extends StatelessWidget {
  const ActivityLogsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Text('Activity Logs', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        const StyledCard(
          child: Center(
            child: Text(
              'Activity logs section content will be implemented here.',
            ),
          ),
        ),
      ],
    );
  }
}