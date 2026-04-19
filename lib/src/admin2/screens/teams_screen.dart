import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/creators_provider.dart';
import '../sections/tabs/creators_teams_tab.dart';
import '../widgets/admin_page_header.dart';
import '../widgets/admin_skeletons.dart';

/// Standalone Teams Screen for Admin Panel
/// Shows team members with workload capacity and onboarding
class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreatorsProvider()..loadCreators(),
      child: const _TeamsScreenContent(),
    );
  }
}

class _TeamsScreenContent extends StatelessWidget {
  const _TeamsScreenContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreatorsProvider>();
    final horizontalPadding =
        MediaQuery.of(context).size.width < 900 ? 12.0 : 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminPageHeader(
          title: 'Teams',
          subtitle: 'Manage artisan workload, capacity, and onboarding.',
          actions: [
            ElevatedButton.icon(
              onPressed:
                  provider.loading ? null : () => provider.loadCreators(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showOnboardDialog(context),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Onboard Artisan'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 600, // Fixed height for the teams grid
          child: provider.loading
              ? const AdminSkeletonView(variant: AdminSkeletonVariant.cards)
              : CreatorsTeamsTab(creators: provider.creators),
        ),
      ],
    );
  }

  void _showOnboardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Onboard New Artisan'),
        content: const SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invite a new artisan to join the team.'),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Specialization',
                  hintText: 'e.g., 3D Modeling, Goldsmithing',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement onboarding logic
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }
}
