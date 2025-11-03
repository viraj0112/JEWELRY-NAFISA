import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/models/menu_item.dart';
import 'package:jewelry_nafisa/src/admin/screens/dashboard_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/members_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/non_members_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/b2b_creators_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/content_management_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/scraped_content_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/b2b_uploads_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/boards_management_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/post_analytics_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/user_behavior_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/credit_analytics_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/engagement_segments_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/b2b_creator_analytics_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/monetization_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/membership_analytics_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/referrals_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/referral_analytics_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/settings_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/activity_logs_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/product_upload_screen.dart';

final List<MenuItem> menuItems = [
  MenuItem(
    title: 'Dashboard Overview',
    icon: Icons.dashboard_outlined,
    screen: const DashboardScreen(),
  ),
  // ===== 2. USERS MANAGEMENT =====
  MenuItem(
    title: 'Users Management',
    icon: Icons.people_outline,
    subItems: [
      MenuItem(
        title: 'Members (Premium)',
        icon: Icons.star_outline,
        screen: const MembersScreen(),
      ),
      MenuItem(
        title: 'Non-Members (Free)',
        icon: Icons.person_outline,
        screen: const NonMembersScreen(),
      ),
      MenuItem(
        title: 'B2B Creators',
        icon: Icons.palette_outlined,
        screen: const B2BCreatorsScreen(),
      ),
    ],
  ),
  // ===== 3. CONTENT MANAGEMENT =====
  MenuItem(
    title: 'Content Management',
    icon: Icons.folder_copy_outlined,
    subItems: [
      MenuItem(
        title: 'Scraped Content',
        icon: Icons.web_asset_outlined,
        screen: const ScrapedContentScreen(),
      ),
      MenuItem(
        title: 'B2B Creator Uploads',
        icon: Icons.upload_file_outlined,
        screen: const B2BUploadsScreen(),
      ),
      MenuItem(
        title: 'User Boards',
        icon: Icons.collections_bookmark_outlined,
        screen: const BoardsManagementScreen(),
      ),
    ],
  ),
  // ===== 4. ANALYTICS & INSIGHTS =====
  MenuItem(
    title: 'Analytics & Insights',
    icon: Icons.analytics_outlined,
    subItems: [
      MenuItem(
        title: 'Post-Level Analytics',
        icon: Icons.bar_chart_outlined,
        screen: const PostAnalyticsScreen(),
      ),
      MenuItem(
        title: 'User Behavior',
        icon: Icons.insights_outlined,
        screen: const UserBehaviorScreen(),
      ),
      MenuItem(
        title: 'Credit Usage',
        icon: Icons.credit_card_outlined,
        screen: const CreditAnalyticsScreen(),
      ),
      MenuItem(
        title: 'Engagement Segments',
        icon: Icons.pie_chart,
        screen: const EngagementSegmentsScreen(),
      ),
    ],
  ),
  // ===== 5. B2B CREATORS ANALYTICS =====
  MenuItem(
    title: 'B2B Creator Analytics',
    icon: Icons.account_tree_outlined,
    subItems: [
      MenuItem(
        title: 'Creator Performance',
        icon: Icons.trending_up_outlined,
        screen: const B2BCreatorAnalyticsScreen(),
      ),
    ],
  ),
  // ===== 6. MONETIZATION & MEMBERSHIP =====
  MenuItem(
    title: 'Monetization & Membership',
    icon: Icons.monetization_on_outlined,
    subItems: [
      MenuItem(
        title: 'Membership Analytics',
        icon: Icons.subscriptions_outlined,
        screen: const MembershipAnalyticsScreen(),
      ),
      MenuItem(
        title: 'Revenue Dashboard',
        icon: Icons.attach_money_outlined,
        screen: const MonetizationScreen(),
      ),
    ],
  ),
  // ===== 7. REFERRALS & GROWTH =====
  MenuItem(
    title: 'Referrals & Growth',
    icon: Icons.group_add_outlined,
    subItems: [
      MenuItem(
        title: 'Referral Analytics',
        icon: Icons.share_outlined,
        screen: const ReferralAnalyticsScreen(),
      ),
      MenuItem(
        title: 'Growth Tracking',
        icon: Icons.trending_up_outlined,
        screen: const ReferralsScreen(),
      ),
    ],
  ),
  // ===== SYSTEM MANAGEMENT =====
  MenuItem(
    title: 'System Management',
    icon: Icons.admin_panel_settings_outlined,
    subItems: [
      MenuItem(
        title: 'System Settings',
        icon: Icons.settings_outlined,
        screen: const SettingsScreen(),
      ),
      MenuItem(
        title: 'Activity Logs',
        icon: Icons.history_outlined,
        screen: const ActivityLogsScreen(),
      ),
      MenuItem(
        title: 'Content Upload',
        icon: Icons.cloud_upload_outlined,
        screen: const ProductUploadScreen(),
      ),
    ],
  ),
];
