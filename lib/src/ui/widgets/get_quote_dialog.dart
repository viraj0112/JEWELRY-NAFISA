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
    final userProfile =
        Provider.of<UserProfileProvider>(context, listen: false);
    final credits = userProfile.creditsRemaining;
    final isMember = userProfile.isMember;

    String title = "Member Exclusive";
    String contentText = "";
    List<Widget> actions = [];

    if (isMember) {
      title = "Get Item Details";
      if (credits > 0) {
        contentText =
            "You have $credits credits remaining.\nUsing one will reveal the product details.";
        if (credits == 1) {
          contentText += "\n\nYou're low on credits. Share to get more!";
        }

        actions.add(
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Use 1 Credit'),
          ),
        );
      } else {
        contentText =
            "You have 0 credits left.\nShare your referral code to get more points or wait for the daily refill.";
      }
    } else {
      title = "Get Quote";
      contentText = "Submit your details to receive a quote.";
    }

    actions.add(
      ElevatedButton(
        onPressed: () async {
          if (await canLaunch(googleFormLink)) {
            await launch(googleFormLink);
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
        },
        child: const Text('Get Quote'),
      ),
    );

    return AlertDialog(
      title: Text(title, style: theme.textTheme.titleLarge),
      content: Text(contentText, style: theme.textTheme.bodyMedium),
      actions: actions,
    );
  }
}
