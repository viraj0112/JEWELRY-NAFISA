import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart'; // Ensure Provider is imported

class GetQuoteDialog extends StatelessWidget {
  final String googleFormLink;

  const GetQuoteDialog({
    super.key,
    required this.googleFormLink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProfile = Provider.of<UserProfileProvider>(context, listen: false);
    final credits = userProfile.creditsRemaining;
    // final isMember = userProfile.isMember; // No longer needed for logic

    String title;
    String contentText;
    List<Widget> actions = [];

    // --- Logic for showing credit usage options ---
    // This part now runs for ALL users
    if (credits > 0) {
      title = "Get Item Details"; // Use a general title
      contentText =
          "You have $credits credits remaining.\nUsing one will reveal the product details.";
      if (credits == 1) {
        contentText += "\n\nYou're low on credits. Share to get more!";
      }

      // Add the "Use 1 Credit" button
      actions.add(
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true), // Pop with 'true' to indicate using credit
          child: const Text('Use 1 Credit'),
        ),
      );
    } else {
      // If no credits, adjust title and text
      title = "Get Quote";
      contentText =
          "You have 0 credits left.\nShare your referral code to get more points or wait for the daily refill.\nAlternatively, request a quote.";
    }

    // --- Always add the "Get Quote" button ---
    actions.add(
      ElevatedButton(
        onPressed: () async {
          // Launch the Google Form link
          if (await canLaunchUrl(Uri.parse(googleFormLink))) { // Use canLaunchUrl and Uri.parse
             await launchUrl(Uri.parse(googleFormLink)); // Use launchUrl and Uri.parse
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text(
                   "We’ve received your details. We’ll get back with a quote soon!",
                 ),
               ),
             );
           } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content:
                     Text("Could not open the form. Please try again later."),
               ),
             );
           }
           // Pop with 'false' indicating not using credit
           Navigator.of(context).pop(false);
        },
        child: const Text('Get Quote via Form'), // Slightly updated text
      ),
    );


    return AlertDialog(
      title: Text(title, style: theme.textTheme.titleLarge),
      content: Text(contentText, style: theme.textTheme.bodyMedium),
      actions: actions, // Use the dynamically built actions list
    );
  }
}