import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/membership/buy_membership_screen.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class GetQuoteDialog extends StatelessWidget {
  const GetQuoteDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProfile = context.watch<UserProfileProvider>();
    final credits = userProfile.creditsRemaining;
    final isMember = userProfile.isMember;

    String title = "Member Exclusive";
    String contentText = "";
    List<Widget> actions = [];

    // Logic for Members
    if (isMember) {
      title = "Get Item Details";
      if (credits > 0) {
        contentText = "You have $credits credits remaining.\nUsing one will reveal the product details.";
        if (credits == 1) {
          contentText += "\n\nYou're low on credits. Share to get more!";
        }
        actions.add(
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true), // Confirm credit use
            child: const Text('Use 1 Credit'),
          ),
        );
      } else {
        contentText = "You have 0 credits left.\nShare your referral code to get more points or wait for the daily refill.";
        actions.add(
          ElevatedButton(
            onPressed: () {
              Share.share("Join using my referral code to get exclusive benefits!");
              Navigator.of(context).pop();
            },
            child: const Text('Share Referral Code'),
          ),
        );
      }
    }
    // Logic for Non-Members
    else {
      if (credits > 0) {
        contentText = "You have 1 credit remaining.\nUsing it will reveal the product details and consume your only credit.";
        actions.add(
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true), // Confirm credit use
            child: const Text('Use Your Credit'),
          ),
        );
      } else {
        contentText = "You are out of credits.\nUpgrade to a membership for daily credits or share to earn more.";
        actions.addAll([
          ElevatedButton(
            onPressed: () {
              Share.share("Join using my referral code to get exclusive benefits!");
              Navigator.of(context).pop();
            },
            child: const Text('Share Code'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BuyMembershipScreen()),
              );
            },
            child: const Text('Upgrade'),
          ),
        ]);
      }
    }

    return AlertDialog(
      title: Text(title),
      content: Text(contentText, style: theme.textTheme.bodyMedium),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ...actions,
      ],
    );
  }
}