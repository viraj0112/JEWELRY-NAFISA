import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/services/google_sheets_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminPanel extends StatelessWidget {
  // final GoogleSheetsService googleSheetsService;
  final List<String> userSheetLinks;

  const AdminPanel({
    super.key,
    // required this.googleSheetsService,
    required this.userSheetLinks,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
      ),
      body: ListView.builder(
        itemCount: userSheetLinks.length + 1,
        itemBuilder: (context, index) {
          if (index == userSheetLinks.length) {
            return ListTile(
              title: const Text('Provide Monthly Credits'),
              subtitle:
                  const Text('Set monthly credits for members and non-members'),
              trailing: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  // Navigate to a new screen or show a dialog to configure monthly credits
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MonthlyCreditsSettingsScreen(),
                    ),
                  );
                },
              ),
            );
          }

          final link = userSheetLinks[index];
          return ListTile(
            title: Text('User ${index + 1}'),
            subtitle: Text(link),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () async {
                if (await canLaunch(link)) {
                  await launch(link);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open the link.'),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class MonthlyCreditsSettingsScreen extends StatelessWidget {
  const MonthlyCreditsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Credits Settings'),
      ),
      body: Center(
        child: Text('Settings for monthly credits will be here.'),
      ),
    );
  }
}
