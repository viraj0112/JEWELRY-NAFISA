import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Clipboard
import 'package:provider/provider.dart';
import '../../providers/users_provider.dart';

class MembersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UsersProvider>();

    if (prov.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prov.error.isNotEmpty) {
      return Center(child: Text('Error: ${prov.error}'));
    }

    final users = prov.members;

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 800;
      if (users.isEmpty) {
        return const Center(child: Text('No members found.'));
      }
      return isMobile ? _MembersCardList(users: users) : _MembersDataTable(users: users);
    });
  }
}

// Helper for copying to clipboard
void _copyToClipboard(BuildContext context, String value, String label) {
  if (value.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No $label available')),
    );
    return;
  }
  Clipboard.setData(ClipboardData(text: value));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label copied to clipboard')),
  );
}

class _MembersCardList extends StatelessWidget {
  final List<UserModel> users;
  const _MembersCardList({required this.users});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, i) {
        final u = users[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: u.avatar != null ? NetworkImage(u.avatar!) : null,
                  child: u.avatar == null ? Text(u.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(u.email, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                  ]),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _TierBadge(tier: u.tier),
                    const SizedBox(height: 8),
                    Text('Credits: ${u.credits}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _copyToClipboard(context, u.email, 'Email'),
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy Email',
                          iconSize: 20,
                        ),
                        IconButton(
                          onPressed: () => _copyToClipboard(context, u.phone, 'Phone'),
                          icon: const Icon(Icons.phone),
                          tooltip: 'Copy Phone',
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MembersDataTable extends StatelessWidget {
  final List<UserModel> users;
  const _MembersDataTable({required this.users});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8),
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Tier')),
              DataColumn(label: Text('Credits')),
              DataColumn(label: Text('Boards')),
              DataColumn(label: Text('Shares')),
              DataColumn(label: Text('Referrals')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: users.map((u) => DataRow(cells: [
              DataCell(Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: u.avatar != null ? NetworkImage(u.avatar!) : null,
                  child: u.avatar == null ? Text(u.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()) : null,
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(u.email, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                ]),
              ])),
              DataCell(_TierBadge(tier: u.tier)),
              DataCell(Text(u.credits.toString())),
              DataCell(Text(u.boards.toString())),
              DataCell(Text(u.shares.toString())),
              DataCell(Text(u.referrals.toString())),
              DataCell(_StatusBadge(status: u.status)),
              DataCell(Row(children: [
                IconButton(
                  onPressed: () => _copyToClipboard(context, u.email, 'Email'),
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy Email',
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(context, u.phone, 'Phone'),
                  icon: const Icon(Icons.phone),
                  tooltip: 'Copy Phone',
                ),
              ])),
            ])).toList(),
          ),
        ),
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  final String tier;
  const _TierBadge({required this.tier});
  @override
  Widget build(BuildContext context) {
    final isPremium = tier.toLowerCase() == 'premium' || tier.toLowerCase() == 'gold';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isPremium ? Colors.purple.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isPremium) const Icon(Icons.emoji_events, size: 14, color: Colors.purple),
        if (isPremium) const SizedBox(width: 6),
        Text(tier.isEmpty ? 'Basic' : tier, style: TextStyle(color: isPremium ? Colors.purple.shade800 : Colors.grey.shade700)),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final active = status.toLowerCase() == 'approved' || status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status, style: TextStyle(color: active ? Colors.green.shade800 : Colors.orange.shade800)),
    );
  }
}