import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';

class ReferralsSection extends StatelessWidget {
  const ReferralsSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Using a ListView for good performance and scrollability.
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Text('Referrals & Growth', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),

        // --- Key Referral Stats using the new MetricsGrid ---
        const MetricsGrid(), // This now displays your referral metrics

        const SizedBox(height: 24),

        // --- Top Referrers Leaderboard in a StyledCard ---
        StyledCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Top Referrers", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              // This LayoutBuilder makes the leaderboard responsive
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return _buildReferrersList(); // Mobile view
                  } else {
                    return _buildReferrersTable(); // Desktop view
                  }
                },
              )
            ],
          ),
        ),
      ],
    );
  }

  // A mobile-friendly list for the leaderboard
  Widget _buildReferrersList() {
    // TODO: Fetch Top Referrers data from Supabase
    final referrers = [
      {'rank': 1, 'name': 'Eleanor Vance', 'referrals': 142},
      {'rank': 2, 'name': 'Marcus Holloway', 'referrals': 118},
      {'rank': 3, 'name': 'Clara Oswald', 'referrals': 95},
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: referrers.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final referrer = referrers[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text('${referrer['rank']}'),
            backgroundColor: index < 3 ? Colors.amber.shade100 : Colors.grey.shade200,
          ),
          title: Text(referrer['name'] as String),
          trailing: Text(
            '${referrer['referrals']} referrals',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  // A desktop-friendly table for the leaderboard
  DataTable _buildReferrersTable() {
    // TODO: Fetch Top Referrers data from Supabase
    final referrers = [
      {'rank': 1, 'name': 'Eleanor Vance', 'referrals': 142, 'conversion': '45%'},
      {'rank': 2, 'name': 'Marcus Holloway', 'referrals': 118, 'conversion': '38%'},
      {'rank': 3, 'name': 'Clara Oswald', 'referrals': 95, 'conversion': '52%'},
      {'rank': 4, 'name': 'Arthur Pendragon', 'referrals': 87, 'conversion': '31%'},
      {'rank': 5, 'name': 'Freya Nightingale', 'referrals': 76, 'conversion': '41%'},
    ];
    
    return DataTable(
      columns: const [
        DataColumn(label: Text('Rank')),
        DataColumn(label: Text('User')),
        DataColumn(label: Text('Successful Referrals')),
        DataColumn(label: Text('Conversion Rate')),
      ],
      rows: referrers.map((referrer) => DataRow(
        cells: [
          DataCell(Text('${referrer['rank']}')),
          DataCell(Text(referrer['name'] as String)),
          DataCell(Text('${referrer['referrals']}')),
          DataCell(Text(referrer['conversion'] as String)),
        ],
      )).toList(),
    );
  }
}