import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProfile = context.watch<UserProfileProvider>();
    final referralCode = userProfile.referralCode ?? 'Generating...';

    // Use LayoutBuilder to create a responsive layout
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          // Desktop layout
          return _buildDesktopLayout(context, referralCode);
        } else {
          // Mobile layout
          return _buildMobileLayout(context, referralCode);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, String referralCode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildReferralCard(context, referralCode),
          const SizedBox(height: 24),
          _buildReferralHistory(context),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, String referralCode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: _buildReferralCard(context, referralCode),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 3,
            child: _buildReferralHistory(context),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard(BuildContext context, String referralCode) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Share Your Code, Get Credits!',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Invite friends to join with your unique referral code. When they sign up, you both get rewarded with extra credits!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text(
              'Your Referral Code:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: referralCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Referral code copied!')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: theme.colorScheme.secondary),
                ),
                child: Text(
                  referralCode,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement sharing functionality
              },
              icon: const Icon(Icons.share),
              label: const Text('Share My Code'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralHistory(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Referral History',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        // This would be replaced with actual data from your provider
        _buildHistoryItem(
          context,
          username: 'NewUser123',
          date: '2023-10-27',
          creditsEarned: '+5 Credits',
        ),
        _buildHistoryItem(
          context,
          username: 'AnotherFriend',
          date: '2023-10-25',
          creditsEarned: '+5 Credits',
        ),
        // Placeholder for when there's no history
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: Center(
            child: Text(
              'No referrals yet. Share your code to get started!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(BuildContext context,
      {required String username,
      required String date,
      required String creditsEarned}) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person),
        ),
        title: Text('$username joined!'),
        subtitle: Text('On $date'),
        trailing: Text(
          creditsEarned,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}