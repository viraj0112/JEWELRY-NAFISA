import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Clipboard
import 'package:provider/provider.dart';
import '../../providers/users_provider.dart';
import 'package:intl/intl.dart';

class NonMembersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UsersProvider>();
    if (prov.loading) return const Center(child: CircularProgressIndicator());
    
    final users = prov.nonMembers;
    
    if (users.isEmpty) return const Center(child: Text('No non-members found.'));
    
    return LayoutBuilder(builder: (context, constraints) {
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
                    radius: 22, 
                    child: Text(u.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join())
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () {
                           if (u.email.isNotEmpty) {
                             Clipboard.setData(ClipboardData(text: u.email));
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email copied!')));
                           }
                        },
                        child: Text(
                          u.email, 
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline)
                        ),
                      ),
                    ]),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Credits: ${u.credits}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Referrals: ${u.referrals}'),
                      const SizedBox(height: 6),
                      Text('Registered: ${u.lastActive != null ? DateFormat.yMMMd().format(u.lastActive!) : '—'}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PotentialBadge(potential: _calcPotential(u)),
                          const SizedBox(width: 8),
                          if (u.phone.isNotEmpty)
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.phone, size: 20),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: u.phone));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone copied!')));
                              },
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
    });
  }

  String _calcPotential(UserModel u) {
    // Based on activity indicators
    if (u.credits >= 10 || u.referrals >= 3) return 'High';
    if (u.credits >= 5) return 'Medium';
    return 'Low';
  }
}

class _PotentialBadge extends StatelessWidget {
  final String potential;
  const _PotentialBadge({required this.potential});
  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    if (potential == 'High') {
      bg = Colors.green.shade50;
      text = Colors.green.shade800;
    } else if (potential == 'Medium') {
      bg = Colors.yellow.shade50;
      text = Colors.orange.shade800;
    } else {
      bg = Colors.red.shade50;
      text = Colors.red.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(potential, style: TextStyle(color: text)),
    );
  }
}