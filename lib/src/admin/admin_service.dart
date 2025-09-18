import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_quote.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final _supabase = Supabase.instance.client;

  Stream<Map<String, int>> getDashboardMetrics() {
    return Stream.periodic(const Duration(seconds: 30), (_) {
      return _fetchDashboardMetrics();
    }).asyncMap((event) async => await event);
  }

  Future<Map<String, int>> _fetchDashboardMetrics() async {
    try {
      final results = await Future.wait([
        _supabase.rpc('get_total_users'),
        _supabase.rpc('get_daily_active_users'),
        _supabase.rpc('get_total_posts'),
        _supabase.rpc('get_total_referrals'),
      ]);

      return {
        'totalUsers': results[0] as int,
        'dailyActiveUsers': results[1] as int,
        'totalPosts': results[2] as int,
        'totalReferrals': results[3] as int,
      };
    } catch (e) {
      debugPrint('Error fetching dashboard metrics: $e');
      return {};
    }
  }

  // Placeholder for fetching chart data
  Future<Map<String, List<double>>> getChartData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'dailyCredits': [20, 40, 60, 80, 50, 70, 90], // Sample data
      'memberships': [10, 15, 12, 18, 25, 22, 30], // Sample data
    };
  }

  // Placeholder for fetching alerts
  Future<Map<String, int>> getPendingAlerts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {'pendingAccounts': 34, 'pendingPosts': 346};
  }

  Future<List<AdminUser>> getUsers(String filter) async {
    try {
      var query = _supabase.from('users').select();

      if (filter == 'Members') {
        query = query.eq('is_member', true);
      } else if (filter == 'Non-Members') {
        query = query.eq('is_member', false);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((data) => AdminUser.fromMap(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
    }
  }

  Future<List<AdminQuote>> getQuotes() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }
}
