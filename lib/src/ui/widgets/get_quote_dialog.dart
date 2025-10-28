import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart'; // No longer needed here

class GetQuoteDialog extends StatelessWidget {
  // --- MODIFIED: No longer needs the form link ---
  const GetQuoteDialog({
    super.key,
  });
  // --- END MODIFIED ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // --- MODIFIED: Now listens to show credit count update ---
    final userProfile = Provider.of<UserProfileProvider>(context);
    // --- END MODIFIED ---
    final credits = userProfile.creditsRemaining;

    String title = "Get Item Details";
    String contentText =
        "You have $credits credits remaining.\nUsing one will reveal the product details.";
    if (credits == 1) {
      contentText += "\n\nYou're low on credits. Share to get more!";
    }

    return AlertDialog(
      title: Text(title, style: theme.textTheme.titleLarge),
      content: Text(contentText, style: theme.textTheme.bodyMedium),
      // --- MODIFIED: Actions list now only has one button ---
      actions: [
        ElevatedButton(
          onPressed: () =>
              Navigator.of(context).pop(true), // Pop with 'true'
          child: const Text('Use 1 Credit'),
        ),
      ],
      // --- END MODIFIED ---
    );
  }
}