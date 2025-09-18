import 'package:jewelry_nafisa/src/admin/models/admin_quote.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, int>> getDashboardMetrics() async {
    try {
      final results = await Future.wait([
        _supabase.rpc('get_total_users'),
        _supabase.rpc('get_daily_active_users'),
        _supabase.rpc('get_total_posts'),
        _supabase.rpc('get_total_referrals'),
      ]);

      final totalUsers = results[0] as int;
      final dailyActiveUsers = results[1] as int;
      final totalPosts = results[2] as int;
      final totalReferrals = results[3] as int;

      return {
        'totalUsers': totalUsers,
        'dailyActiveUsers': dailyActiveUsers,
        'totalPosts': totalPosts,
        'totalReferrals': totalReferrals,
      };
    } catch (e) {
      print('Error fetching dashboard information: $e');
      return {
        'totalUsers': 0,
        'dailyActiveUsers': 0,
        'totalPosts': 0,
        'totalReferrals': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getEngagementData() async {
    await Future.delayed(const Duration(milliseconds: 700));
    return [
      /*TODO implementation */
    ];
  }

  Future<List<Map<String, String>>> getTopPerformingContent() async {
    await Future.delayed(const Duration(milliseconds: 900));
    return [
      /*TODO Implementation */
    ];
  }

  Future<Map<String, int>> getDashboardSummary() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      /*TODO Implementation */
    };
  }

  Future<List<AdminUser>> getUsers(String filter) async {
    try {
      PostgrestFilterBuilder query = _supabase.from('Users').select();
      if (filter == 'Members') {
        query = query.eq('is_member', true);
      } else if (filter == 'Non-members') {
        query = query.eq('is_member', false);
      }

      final response = await query.order('created_at', ascending: false);
      final users = (response as List<dynamic>)
          .map((data) => AdminUser.fromMap(data as Map<String, dynamic>))
          .toList();

      return users;
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  Future<List<AdminQuote>> getQuotes() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      /*TODO implementation */
    ];
  }
}
