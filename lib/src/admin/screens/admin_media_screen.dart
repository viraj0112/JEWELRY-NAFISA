import 'package:flutter/material.dart';

class AdminMediaScreen extends StatelessWidget {
  const AdminMediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Media Management')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Designer File Approvals', style: theme.textTheme.headlineSmall),
            const Text('Review and approve uploads from 3D designers and sketch artists.'),
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                leading: Icon(Icons.pending_actions),
                title: Text('New Ring Design by Charlie'),
                subtitle: Text('Pending Approval'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 40),
            Text('Upload Center', style: theme.textTheme.headlineSmall),
            const Text('Upload new images and reels directly to the platform.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload New Image/Reel'),
              onPressed: () {
                // TODO: Implement upload functionality
              },
            ),
          ],
        ),
      ),
    );
  }
}