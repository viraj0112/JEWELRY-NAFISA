import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';

class CreatorAnalyticsSection extends StatelessWidget {
  final String creatorId;

  const CreatorAnalyticsSection({super.key, required this.creatorId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CreatorDashboard>(
      future: AdminService().getCreatorDashboard(creatorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(
            child: Text(
              'No analytics data found for this creator.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final dashboard = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Text('Creator Analytics',
                style: GoogleFonts.inter(
                    fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            StyledCard(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Total Works Uploaded'),
                    trailing: Text(
                      dashboard.totalWorksUploaded.toString(),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    title: const Text('Total Unlocks'),
                    trailing: Text(
                      dashboard.totalUnlocks.toString(),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    title: const Text('Total Saves'),
                    trailing: Text(
                      dashboard.totalSaves.toString(),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Top 5 Posts',
                style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            StyledCard(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Title')),
                  DataColumn(label: Text('Views')),
                  DataColumn(label: Text('Likes')),
                  DataColumn(label: Text('Saves')),
                ],
                rows: dashboard.topPosts.map((post) {
                  return DataRow(cells: [
                    DataCell(Text(post.title)),
                    DataCell(Text(post.views.toString())),
                    DataCell(Text(post.likes.toString())),
                    DataCell(Text(post.saves.toString())),
                  ]);
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
