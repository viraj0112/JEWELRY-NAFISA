import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/widgets/filter_component.dart';

class AdminService {
  final _supabase = Supabase.instance.client;

  /// Fetches various KPIs for the main dashboard.
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    try {
      final totalUsersRes = await _supabase.rpc('get_total_users');
      final totalPostsRes = await _supabase.rpc('get_total_posts');
      final totalReferralsRes = await _supabase.rpc('get_total_referrals');

      return {
        'totalUsers': totalUsersRes ?? 0,
        'totalPosts': totalPostsRes ?? 0,
        'creditsUsed': 2341, // Placeholder
        'totalReferrals': totalReferralsRes ?? 0,
      };
    } catch (e) {
      debugPrint('Error fetching dashboard metrics: $e');
      rethrow;
    }
  }

  /// Fetches the top referrers from the database.
  Future<List<TopReferrer>> getTopReferrers({int limit = 10}) async {
    try {
      final response = await _supabase
          .rpc('get_top_referrers', params: {'limit_count': limit});
      return (response as List)
          .map((data) => TopReferrer.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Error fetching top referrers: $e');
      rethrow;
    }
  }

  /// Fetches all system settings.
  Future<Map<String, String>> getSettings() async {
    try {
      final response = await _supabase.rpc('get_settings');
      return Map<String, String>.from(response);
    } catch (e) {
      debugPrint('Error fetching settings: $e');
      rethrow;
    }
  }

  /// Updates a specific setting.
  Future<void> updateSetting(String key, String value) async {
    try {
      await _supabase
          .rpc('update_setting', params: {'p_key': key, 'p_value': value});
    } catch (e) {
      debugPrint('Error updating setting $key: $e');
      rethrow;
    }
  }

  /// Fetches users based on their role and membership status, with optional filters.
  Future<List<AppUser>> getUsers(
      {required String userType, FilterState? filterState}) async {
    try {
      var query = _supabase.from('users').select();

      switch (userType) {
        case 'Members':
          query = query.eq('is_member', true);
          break;
        case 'Non-Members':
          query = query.eq('is_member', false).eq('role', 'member');
          break;
        case 'B2B Creators':
          query = query.eq('role', 'designer');
          break;
      }

      // Apply filters if they exist
      if (filterState != null) {
        if (filterState.customDateRange != null) {
          query = query.gte('created_at',
              filterState.customDateRange!.start.toIso8601String());
          query = query.lte(
              'created_at', filterState.customDateRange!.end.toIso8601String());
        }
        if (filterState.status != 'All Status') {
          query = query.eq('approval_status', filterState.status.toLowerCase());
        }
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).map((data) => AppUser.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Error fetching users ($userType): $e');
      rethrow;
    }
  }

  /// Fetches B2B creators who are awaiting profile approval.
  Future<List<AppUser>> getPendingCreators() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('role', 'designer')
          .eq('approval_status', 'pending')
          .order('created_at', ascending: true);
      return (response as List).map((data) => AppUser.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Error fetching pending creators: $e');
      rethrow;
    }
  }

  /// Updates a creator's approval status.
  Future<void> updateCreatorStatus(String userId, String newStatus) async {
    try {
      await _supabase
          .from('users')
          .update({'approval_status': newStatus}).eq('id', userId);
    } catch (e) {
      debugPrint('Error updating creator status: $e');
      rethrow;
    }
  }

  /// Deletes a user from the database.
  Future<void> deleteUser(String userId) async {
    try {
      await _supabase.from('users').delete().eq('id', userId);
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  /// Fetches all B2B creators (approved).
  Future<List<AppUser>> getApprovedCreators() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('role', 'designer')
          .eq('approval_status', 'approved')
          .order('created_at', ascending: false);
      return (response as List).map((data) => AppUser.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Error fetching approved creators: $e');
      rethrow;
    }
  }

  /// Fetches all assets uploaded by creators.
  Future<List<Asset>> getUploadedContent() async {
    try {
      final response = await _supabase
          .from('assets')
          .select('*, users(username)')
          .order('created_at', ascending: false);
      return (response as List).map((data) => Asset.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Error fetching uploaded content: $e');
      rethrow;
    }
  }

  /// Fetches post-level analytics data.
  Future<List<PostAnalytic>> getPostAnalytics() async {
    try {
      final response = await _supabase.rpc('get_all_post_analytics');
      return (response as List)
          .map((data) => PostAnalytic.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Error fetching post analytics: $e');
      rethrow;
    }
  }

  /// Fetches monetization KPIs.
  Future<Map<String, dynamic>> getMonetizationMetrics() async {
    try {
      final response = await _supabase.rpc('get_monetization_metrics');
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error fetching monetization metrics: $e');
      rethrow;
    }
  }
}
