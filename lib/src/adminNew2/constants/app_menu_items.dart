import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/adminNew2/models/menu_item.dart';
import 'package:jewelry_nafisa/src/adminNew2/screens/activity_logs_screen.dart';
import 'package:jewelry_nafisa/src/adminNew2/screens/analytics_screen.dart';
import 'package:jewelry_nafisa/src/adminNew2/screens/b2b_creators_screen.dart';
import 'package:jewelry_nafisa/src/adminNew2/screens/dashboard_screen.dart';
import 'package:jewelry_nafisa/src/adminNew2/screens/emails_screen.dart';
import 'package:jewelry_nafisa/src/adminNew2/screens/reports_screen.dart';
import 'package:jewelry_nafisa/src/adminNew2/screens/settings_screen.dart';
import 'package:jewelry_nafisa/src/adminNew2/screens/users_screen.dart';
import 'package:jewelry_nafisa/src/adminNew2/screens/notifications_screen.dart';

final List<MenuItem> menuItems = [
  MenuItem(title: 'Dashboard', icon: Icons.dashboard_outlined, screen: const DashboardScreen()),
  MenuItem(
    title: 'Analytics',
    icon: Icons.analytics_outlined,
    screen: const AnalyticsScreen(),
    subItems: [
      MenuItem(title: 'Post Analytics', icon: Icons.remove_red_eye_outlined),
      MenuItem(title: 'Members Behavior', icon: Icons.auto_graph),
      MenuItem(title: 'Credit System', icon: Icons.credit_score),
      MenuItem(title: 'Referral Tracking', icon: Icons.trending_up_sharp),
      MenuItem(title: 'Search & Filters', icon: Icons.search_outlined),
      MenuItem(title: 'Geo Analytics', icon: Icons.map_outlined),
    ],
  ),
  MenuItem(
    title: 'Users',
    icon: Icons.people_outline,
    screen: const UsersScreen(),
    subItems: [
      MenuItem(title: 'Members', icon: Icons.person_add_outlined),
      MenuItem(title: 'Non-Members', icon: Icons.person_add_disabled_outlined),
      MenuItem(title: 'Referrals', icon: Icons.share_outlined),
    ],
  ),
  MenuItem(
    title: 'B2B Creators',
    icon: Icons.palette_outlined,
    screen: const B2BCreatorsScreen(),
    subItems: [
      MenuItem(title: '3D Artists', icon: Icons.palette_outlined),
      MenuItem(title: 'Sketch Designers', icon: Icons.brush_outlined),
      MenuItem(title: 'Uploads', icon: Icons.file_upload_outlined),
    ],
  ),
  MenuItem(
    title: 'Notifications',
    icon: Icons.message_outlined,
    screen: NotificationsScreen(),
    subItems: [
      MenuItem(title: 'Admin Notifications', icon: Icons.shield_outlined),
      MenuItem(title: 'User Notifications', icon: Icons.person_outline_rounded),
      MenuItem(title: 'Alerts', icon: Icons.add_alert_sharp),
    ],
  ),
  MenuItem(
    title: 'Reports',
    icon: Icons.add_chart,
    screen: ReportsScreen(),
    subItems: [
      MenuItem(title: 'Platform Reports', icon: Icons.bar_chart),
      MenuItem(title: 'User Reports', icon: Icons.stacked_line_chart),
      MenuItem(title: 'Content Reports', icon: Icons.person_pin_outlined),
      MenuItem(title: 'Revenue Reports', icon: Icons.monetization_on_outlined),
    ],
  ),
  MenuItem(
    title: 'Activity Logs',
    icon: Icons.settings_backup_restore_outlined,
    screen: ActivityLogsScreen(),
    subItems: [
      MenuItem(title: 'Admin Logs', icon: Icons.admin_panel_settings_outlined),
      MenuItem(title: 'User Logs', icon: Icons.supervised_user_circle_outlined),
      MenuItem(title: 'Export Logs', icon: Icons.download_outlined),
    ],
  ),
  MenuItem(title: 'Emails', icon: Icons.email_outlined, screen: const EmailScreen()),
  MenuItem(
    title: 'Settings',
    icon: Icons.settings,
    screen: const SettingsScreen(),
    subItems: [
      MenuItem(title: 'User Roles & Permissions', icon: Icons.shield_outlined),
      MenuItem(title: 'Webhooks', icon: Icons.web_asset),
    ],
  ),
];
