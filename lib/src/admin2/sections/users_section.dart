import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/users_provider.dart';
import 'tabs/members_tab.dart';
import 'tabs/non_members_tab.dart';
import 'tabs/referral_leaderboard_tab.dart';

class UsersSection extends StatefulWidget {
  const UsersSection({super.key});
  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> {
  @override
  Widget build(BuildContext context) {
    // Root scaffold for section
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Management'),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => context.read<UsersProvider>().exportCsv(),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export Users'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              // trigger campaign flow
            },
            icon: const Icon(Icons.mail_outline),
            label: const Text('Send Campaign'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;
          final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1024;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header & filter bar
                const _FilterBar(),
                const SizedBox(height: 16),
                // Tabs
                Expanded(
                  // Expanded + TabBarView ensures no RenderFlex overflow
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: TabBar(
                            labelColor: Theme.of(context).colorScheme.onSurface,
                            unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
                            indicator: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            tabs: const [
                              Tab(icon: Icon(Icons.person), text: 'Members'),
                              Tab(icon: Icon(Icons.person_outline), text: 'Non-Members'),
                              Tab(icon: Icon(Icons.emoji_events), text: 'Referral Leaderboard'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TabBarView(
                            children: [
                              MembersTab(),
                              NonMembersTab(),
                              ReferralLeaderboardTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UsersProvider>();

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 900;
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchField(),
                    const SizedBox(height: 8),
                    Wrap(
                      runSpacing: 8,
                      spacing: 8,
                      children: [
                        _UserTypeDropdown(),
                        _StatusDropdown(),
                        _MoreFiltersButton(),
                      ],
                    )
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _SearchField()),
                    const SizedBox(width: 12),
                    _UserTypeDropdown(),
                    const SizedBox(width: 8),
                    _StatusDropdown(),
                    const SizedBox(width: 8),
                    _MoreFiltersButton(),
                  ],
                ),
        ),
      );
    });
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({super.key});
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UsersProvider>();
    return TextField(
      onChanged: prov.setSearch,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Search by name or email...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}

class _UserTypeDropdown extends StatelessWidget {
  const _UserTypeDropdown({super.key});
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UsersProvider>();
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<UserTypeFilter>(
        value: prov.userType,
        items: const [
          DropdownMenuItem(value: UserTypeFilter.all, child: Text('All Users')),
          DropdownMenuItem(value: UserTypeFilter.members, child: Text('Members')),
          DropdownMenuItem(value: UserTypeFilter.nonMembers, child: Text('Non-Members')),
        ],
        onChanged: (v) {
          if (v != null) context.read<UsersProvider>().setUserType(v);
        },
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({super.key});
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UsersProvider>();
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<StatusFilter>(
        value: prov.status,
        items: const [
          DropdownMenuItem(value: StatusFilter.all, child: Text('All Status')),
          DropdownMenuItem(value: StatusFilter.active, child: Text('Active')),
          DropdownMenuItem(value: StatusFilter.inactive, child: Text('Inactive')),
        ],
        onChanged: (v) {
          if (v != null) context.read<UsersProvider>().setStatus(v);
        },
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }
}

class _MoreFiltersButton extends StatelessWidget {
  const _MoreFiltersButton({super.key});
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        // open modal with advanced filters
      },
      icon: const Icon(Icons.filter_list),
      label: const Text('More Filters'),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
