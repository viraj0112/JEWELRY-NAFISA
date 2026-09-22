import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

    // Default to 1, but we should actually fetch this from settings if possible.
    // For now, let's just make it dynamic based on the actual setting.
    // To avoid blocking, we could use a FutureBuilder or just assume 5 if not available.
    // But since the requirement is to use the global setting, we should fetch it.

    return FutureBuilder<int>(
      future: Supabase.instance.client
          .from('settings')
          .select('value')
          .eq('key', 'credit_deduction_amount')
          .maybeSingle()
          .then((res) => int.tryParse(res?['value'] ?? '5') ?? 5),
      builder: (context, snapshot) {
        final int deductionAmount =
            snapshot.data ?? 5; // Default to 5 as per admin settings

        String title = "Get Item Details";
        String contentText =
            "You have $credits credits remaining.\nUsing $deductionAmount will reveal the product details.";
        if (credits < deductionAmount) {
          contentText =
              "You have $credits credits remaining, but $deductionAmount are required to reveal the product details.\n\nYou're low on credits. Share to get more!";
        }

        return AlertDialog(
          title: Text(title, style: theme.textTheme.titleLarge),
          content: Text(contentText, style: theme.textTheme.bodyMedium),
          // --- MODIFIED: Actions list now only has one button ---
          actions: [
            if (credits >= deductionAmount)
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(true), // Pop with 'true'
                child: Text(
                    'Use $deductionAmount Credit${deductionAmount > 1 ? 's' : ''}'),
              ),
            if (credits < deductionAmount)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
          ],
          // --- END MODIFIED ---
        );
      },
    );
  }
}
