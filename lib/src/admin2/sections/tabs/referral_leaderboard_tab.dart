// sections/tabs/referral_leaderboard_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/users_provider.dart';

class ReferralLeaderboardTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UsersProvider>();
    if (prov.loading) return const Center(child: CircularProgressIndicator());
    final lb = prov.leaderboard;
    if (lb.isEmpty) return const Center(child: Text('No referral data found.'));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: lb.length,
      itemBuilder: (context, i) {
        final item = lb[i];
        return ListTile(
          leading: _RankWidget(rank: i + 1),
          title: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: item.user.avatar != null ? NetworkImage(item.user.avatar!) : null,
              child: item.user.avatar == null ? Text(item.user.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()) : null,
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(item.user.email, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
            ]),
          ]),
          subtitle: Row(children: [
            Text('Total: ${item.totalReferrals}'),
            const SizedBox(width: 12),
            Text('Success: ${item.successful}', style: const TextStyle(color: Colors.green)),
            const SizedBox(width: 12),
            Text('Credits: ${item.creditsEarned}'),
          ]),
          trailing: SizedBox(
            width: 100,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              LinearProgressIndicator(
                value: item.successRate,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
              ),
              const SizedBox(height: 6),
              Text('${(item.successRate * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
            ]),
          ),
        );
      },
    );
  }
}

class _RankWidget extends StatelessWidget {
  final int rank;
  const _RankWidget({required this.rank});
  @override
  Widget build(BuildContext context) {
    if (rank == 1) {
      return const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.star, color: Colors.white));
    }
    return CircleAvatar(backgroundColor: Colors.grey.shade200, child: Text('#$rank'));
  }
}
