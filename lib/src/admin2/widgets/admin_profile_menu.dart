import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProfileMenu extends StatelessWidget {
  const AdminProfileMenu({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut(); 
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Admin';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'A';

    return PopupMenuButton<String>(
      tooltip: 'Profile Menu',
      offset: const Offset(0, 50),
      onSelected: (value) {
        if (value == 'logout') {
          _signOut(context);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(initial, style: TextStyle(color: Theme.of(context).primaryColor)),
            ),
            title: const Text('Admin', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              email,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey.shade200,
          child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
      ),
    );
  }
}