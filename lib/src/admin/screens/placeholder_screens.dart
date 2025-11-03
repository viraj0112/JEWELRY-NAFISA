import 'package:flutter/material.dart';

// Placeholder screens for the comprehensive admin panel
class ScrapedContentScreen extends StatelessWidget {
  const ScrapedContentScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'Scraped Content',
        description: 'Manage scraped content and import queues',
      );
}

class B2BUploadsScreen extends StatelessWidget {
  const B2BUploadsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'B2B Creator Uploads',
        description: 'Manage B2B creator uploads and approval workflow',
      );
}

class BoardsManagementScreen extends StatelessWidget {
  const BoardsManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'User Boards',
        description: 'Manage user-generated boards and collections',
      );
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'Analytics Overview',
        description: 'View overall platform analytics and insights',
      );
}

class PostAnalyticsScreen extends StatelessWidget {
  const PostAnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'Post-Level Analytics',
        description: 'Analyze individual post performance and engagement',
      );
}

class UserBehaviorScreen extends StatelessWidget {
  const UserBehaviorScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'User Behavior',
        description: 'Track user sessions, actions, and drop-off funnels',
      );
}

class CreditAnalyticsScreen extends StatelessWidget {
  const CreditAnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'Credit Usage Analytics',
        description: 'Analyze credit consumption patterns and trends',
      );
}

class EngagementSegmentsScreen extends StatelessWidget {
  const EngagementSegmentsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'Engagement Segments',
        description: 'Analyze engagement by user segments and content types',
      );
}

class B2BCreatorAnalyticsScreen extends StatelessWidget {
  const B2BCreatorAnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'B2B Creator Analytics',
        description: 'Detailed analytics for B2B creators and their content',
      );
}

class MonetizationScreen extends StatelessWidget {
  const MonetizationScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'Revenue Dashboard',
        description: 'Track revenue, subscriptions, and monetization metrics',
      );
}

class MembershipAnalyticsScreen extends StatelessWidget {
  const MembershipAnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'Membership Analytics',
        description: 'Analyze membership growth, retention, and conversion',
      );
}

class ReferralsScreen extends StatelessWidget {
  const ReferralsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'Growth Tracking',
        description: 'Track referral codes, growth metrics, and conversion rates',
      );
}

class ReferralAnalyticsScreen extends StatelessWidget {
  const ReferralAnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'Referral Analytics',
        description: 'Detailed referral performance and top referrers',
      );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'System Settings',
        description: 'Configure credit logic, user roles, and system parameters',
      );
}

class ActivityLogsScreen extends StatelessWidget {
  const ActivityLogsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'Activity Logs',
        description: 'View system activity logs and audit trails',
      );
}

class ProductUploadScreen extends StatelessWidget {
  const ProductUploadScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderScreen(
        title: 'Content Upload',
        description: 'Upload and manage content manually',
      );
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final String description;

  const _PlaceholderScreen({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.construction,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This feature is under development',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This screen will be fully implemented in the next phase',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}