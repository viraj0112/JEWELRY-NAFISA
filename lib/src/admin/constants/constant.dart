import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/models/menu_item.dart';
import 'package:jewelry_nafisa/src/admin/screens/dashboard_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/users_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/b2b_creators_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/analytics_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/monetization_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/referrals_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/settings_screen.dart';
// Note: Some screens might share sections or be simple placeholders for now.
// For example, Activity Logs might be a separate screen or part of another.
// Based on the doc, making it a main item.
import 'package:jewelry_nafisa/src/admin/screens/activity_logs_screen.dart';


final List<MenuItem> menuItems = [
  // 1. Dashboard
  MenuItem(
    title: 'Dashboard',
    icon: Icons.dashboard_outlined,
    screen: const DashboardScreen(),
  ),

  // 2. Users Management
  MenuItem(
    title: 'Users Management',
    icon: Icons.people_outline,
    screen: const UsersScreen(), // Main screen shows all users
  ),

  // 3. B2B Creators
  MenuItem(
    title: 'B2B Creators',
    icon: Icons.palette_outlined,
    screen: const B2BCreatorsScreen(),
  ),

  // 4. Analytics & Insights
  MenuItem(
    title: 'Analytics',
    icon: Icons.analytics_outlined,
    screen: const AnalyticsScreen(),
  ),
  
  // 5. Monetization & Membership
  MenuItem(
    title: 'Monetization',
    icon: Icons.monetization_on_outlined,
    screen: const MonetizationScreen(),
  ),

  // 6. Referrals & Growth
  MenuItem(
    title: 'Referrals',
    icon: Icons.share_outlined,
    screen: const ReferralsScreen(),
  ),
  
  // 7. Activity Logs (as a separate item based on your previous code)
   MenuItem(
    title: 'Activity Logs',
    icon: Icons.history_toggle_off_outlined,
    screen: const ActivityLogsScreen(),
  ),
  
  // 8. System Settings
  MenuItem(
    title: 'Settings',
    icon: Icons.settings_outlined,
    screen: const SettingsScreen(),
  ),
];