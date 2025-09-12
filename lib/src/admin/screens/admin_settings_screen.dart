import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Tools')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('User Role & Permission Management'),
            subtitle: const Text('Define roles like Admin, Moderator, etc.'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('Daily Credit Reset Scheduler'),
            subtitle: const Text('Configure the daily credit reset job.'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.webhook),
            title: const Text('Webhook & API Controls'),
            subtitle: const Text('Manage ARMember Sync and other integrations.'),
            onTap: () {},
          ),
          const Divider(height: 40),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text('Log Out', style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}