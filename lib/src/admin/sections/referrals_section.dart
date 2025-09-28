import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';

class ReferralsSection extends StatefulWidget {
  const ReferralsSection({super.key});

  @override
  State<ReferralsSection> createState() => _ReferralsSectionState();
}

class _ReferralsSectionState extends State<ReferralsSection> {
  final AdminService _adminService = AdminService();
  late Future<List<TopReferrer>> _topReferrersFuture;

  @override
  void initState() {
    super.initState();
    _topReferrersFuture = _adminService.getTopReferrers(limit: 10);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Text('Referrals & Growth', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        // This can be wired up to the main dashboard metrics later
        // const MetricsGrid(),
        const SizedBox(height: 24),
        StyledCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Top Referrers", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              FutureBuilder<List<TopReferrer>>(
                future: _topReferrersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final referrers = snapshot.data ?? [];
                  if (referrers.isEmpty) {
                    return const Center(child: Text('No referral data available.'));
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 600) {
                        return _buildReferrersList(referrers);
                      } else {
                        return _buildReferrersTable(referrers);
                      }
                    },
                  );
                },
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReferrersList(List<TopReferrer> referrers) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: referrers.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final referrer = referrers[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text('${index + 1}'),
            backgroundColor: index < 3 ? Colors.amber.shade100 : Colors.grey.shade200,
          ),
          title: Text(referrer.username ?? 'N/A'),
          subtitle: Text(referrer.email ?? 'No Email'),
          trailing: Text(
            '${referrer.referralCount} referrals',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  DataTable _buildReferrersTable(List<TopReferrer> referrers) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Rank')),
        DataColumn(label: Text('User')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Successful Referrals')),
      ],
      rows: referrers.asMap().entries.map((entry) {
        int index = entry.key;
        TopReferrer referrer = entry.value;
        return DataRow(
          cells: [
            DataCell(Text('${index + 1}')),
            DataCell(Text(referrer.username ?? 'N/A')),
            DataCell(Text(referrer.email ?? 'No Email')),
            DataCell(Text('${referrer.referralCount}')),
          ],
        );
      }).toList(),
    );
  }
}