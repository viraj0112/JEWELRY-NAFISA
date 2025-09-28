import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/models/menu_item.dart';
import 'package:jewelry_nafisa/src/admin/screens/dashboard_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/users_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/b2b_creators_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/analytics_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/monetization_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/referrals_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/settings_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/activity_logs_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/content_management_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/creator_analytics_screen.dart';


final List<MenuItem> menuItems = [
  MenuItem(
    title: 'Dashboard',
    icon: Icons.dashboard_outlined,
    screen: const DashboardScreen(),
  ),

  MenuItem(
    title: 'Users Management',
    icon: Icons.people_outline,
    screen: const UsersScreen(),
  ),

  MenuItem(
    title: 'B2B Creators',
    icon: Icons.palette_outlined,
    screen: const B2BCreatorsScreen(),
  ),

  MenuItem(
    title: 'Content Management',
    icon: Icons.folder_copy_outlined,
    screen: const ContentManagementScreen(),
  ),

  MenuItem(
    title: 'Analytics',
    icon: Icons.analytics_outlined,
    screen: const AnalyticsScreen(),
  ),

  MenuItem(
    title: 'Creator Analytics',
    icon: Icons.bar_chart_outlined,
    screen: const CreatorAnalyticsScreen(),
  ),

  MenuItem(
    title: 'Monetization',
    icon: Icons.monetization_on_outlined,
    screen: const MonetizationScreen(),
  ),

  MenuItem(
    title: 'Referrals',
    icon: Icons.share_outlined,
    screen: const ReferralsScreen(),
  ),

   MenuItem(
    title: 'Activity Logs',
    icon: Icons.history_toggle_off_outlined,
    screen: const ActivityLogsScreen(),
  ),

  MenuItem(
    title: 'Settings',
    icon: Icons.settings_outlined,
    screen: const SettingsScreen(),
  ),
];