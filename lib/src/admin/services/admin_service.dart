import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/widgets/filter_component.dart';

class AdminService {
  final _supabase = Supabase.instance.client;

  // Helper to calculate percentage change safely
  double _calculateChange(num current, num previous) {
    if (previous == 0) {
      return current > 0 ? 100.0 : 0.0;
    }
    return ((current - previous) / previous) * 100;
  }

  // Helper function to create a polling stream for functions
  Stream<T> _createPollingStream<T>(Future<T> Function() futureFunction) {
    late StreamController<T> controller;
    Timer? timer;

    void fetchData() async {
      try {
        final result = await futureFunction();
        if (controller.isClosed) return;
        controller.add(result);
      } catch (e) {
        if (controller.isClosed) return;
        controller.addError(e);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        fetchData();
        timer = Timer.periodic(const Duration(seconds: 30), (_) => fetchData());
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<Map<String, dynamic>> getDashboardMetricsStream() {
    return _createPollingStream(() async {
      // Fetch current and previous month's data in parallel
      final responses = await Future.wait([
        _supabase.rpc('get_total_users'),
        _supabase.rpc('get_total_posts'),
        _supabase.rpc('get_total_referrals'),
        _supabase.rpc('get_total_users_previous_month'),
        _supabase.rpc('get_total_posts_previous_month'),
      ]);

      final totalUsers = responses[0] as int? ?? 0;
      final totalPosts = responses[1] as int? ?? 0;
      final totalReferrals = responses[2] as int? ?? 0;
      final prevTotalUsers = responses[3] as int? ?? 0;
      final prevTotalPosts = responses[4] as int? ?? 0;

      // Calculate percentage changes
      final usersChange = _calculateChange(totalUsers, prevTotalUsers);
      final postsChange = _calculateChange(totalPosts, prevTotalPosts);

      // --- Credits Used Calculation ---
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final creditsUsedRes = await _supabase
          .from('analytics_daily')
          .select('quotes_requested')
          .gte('date', startOfMonth.toIso8601String());
      int creditsUsed = 0;
      for (var row in creditsUsedRes) {
        creditsUsed += (row['quotes_requested'] as int?) ?? 0;
      }

      // Note: Historical data for credits and referrals isn't available in the schema,
      // so their change percentages remain static for now.
      return {
        'totalUsers': totalUsers,
        'totalPosts': totalPosts,
        'creditsUsed': creditsUsed,
        'totalReferrals': totalReferrals,
        'usersChange': usersChange,
        'postsChange': postsChange,
        'creditsChange': -3.1, // Placeholder
        'referralsChange': 18.9, // Placeholder
      };
    });
  }
    // ... (rest of your AdminService code remains the same)
  Stream<List<Map<String, dynamic>>> getUserGrowthStream() {
    return _createPollingStream(() async {
      final response = await _supabase.rpc('get_new_users_per_month');
      // The RPC returns a list of objects, which is exactly what we need.
      return (response as List).map((item) => item as Map<String, dynamic>).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getPostCategoriesStream() {
    // This can listen to real-time changes as post counts change frequently.
    return _supabase.from('assets').stream(primaryKey: ['id']).map((listOfPosts) {
      final categoryCounts = <String, int>{};
      for (final post in listOfPosts) {
        final category = post['category'] as String? ?? 'Other';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }
      return categoryCounts.entries
          .map((entry) => {'cat': entry.key, 'val': entry.value})
          .toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getDailyAnalyticsStream() {
    return _createPollingStream(() async {
      final response = await _supabase
          .from('analytics_daily')
          .select('date, views')
          .gte('date', DateTime.now().subtract(const Duration(days: 30)).toIso8601String())
          .order('date');

      return (response as List).map((item) {
        return {
          'day': item['date'],
          'val': item['views'] ?? 0,
        };
      }).toList();
    });
  }

  Stream<double> getConversionRateStream() {
    return _createPollingStream(() async {
      final response = await _supabase.from('users').select('is_member');
      if (response.isEmpty) return 0.0;
      final totalUsers = response.length;
      final memberCount = response.where((user) => user['is_member'] == true).length;
      return (memberCount / totalUsers) * 100;
    });
  }
  
  // ... (rest of your AdminService code remains the same)
  // Fetches the top referrers from the database.
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