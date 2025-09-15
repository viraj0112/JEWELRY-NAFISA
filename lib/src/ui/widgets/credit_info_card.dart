import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/widgets/animated_credit_indicator.dart';

class CreditInfoCard extends StatelessWidget {
  const CreditInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final userProfile = context.watch<UserProfileProvider>();
    final theme = Theme.of(context);

    // Determine total credits based on membership status
    final totalCredits = userProfile.isMember ? 3 : 1;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Credits Left For Your Account',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Referral Code- ${userProfile.referralCode ?? "N/A"}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            AnimatedCreditIndicator(
              currentCredits: userProfile.creditsRemaining,
              totalCredits: totalCredits,
            ),
          ],
        ),
      ),
    );
  }
}