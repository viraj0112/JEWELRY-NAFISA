import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/widgets/animated_credit_indicator.dart';

class CreditInfoCard extends StatelessWidget {
  const CreditInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Use a Consumer to listen for changes in UserProfileProvider
    return Consumer<UserProfileProvider>(
      builder: (context, userProfile, child) {
        final theme = Theme.of(context);
        final totalCredits = userProfile.isMember ? 3 : 1;

        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      // Display the referral code from the provider
                      Text(
                        'Referral Code: ${userProfile.referralCode ?? "Generating..."}',
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
      },
    );
  }
}
