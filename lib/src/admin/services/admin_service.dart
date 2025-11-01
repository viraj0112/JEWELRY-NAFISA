import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart'
    show TimeSeriesData;

final adminServiceProvider = Provider((ref) => AdminService());

class AdminService {
  final _supabase = Supabase.instance.client;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  late final RealtimeChannel _channel;

  AdminService() {
    _channel = _supabase.channel('dashboard');

    _channel
        .onBroadcast(
          event: 'metrics-update',
          callback: (payload) async {
            final metrics = await fetchDashboardMetrics();
            if (!_controller.isClosed) {
              _controller.add(metrics);
            }
          },
        )
        .subscribe();
  }

  Stream<List<AppUser>> getPendingCreators() {
    return _supabase
        .from('users')
        .select()
        .eq('role', 'designer')
        .eq('is_approved', false)
        .order('created_at', ascending: true)
        .asStream()
        .map((response) =>
            response.map((map) => AppUser.fromJson(map)).toList());
  }

  Stream<Map<String, dynamic>> getDashboardMetricsStream() {
    return _createPollingStream(fetchDashboardMetrics);
  }

  Future<Map<String, dynamic>> fetchDashboardMetrics() async {
    final responses = await Future.wait([
      _supabase.rpc('get_total_users'),
      _supabase.rpc('get_total_posts'),
      _supabase.rpc('get_total_referrals'),
      _supabase.rpc('get_total_users_previous_month'),
      _supabase.rpc('get_total_posts_previous_month'),
      _supabase.rpc('get_total_referrals_previous_month'),
      _supabase.rpc('get_total_credits_used_previous_month'),
    ]);

    final totalUsers = responses[0] as int? ?? 0;
    final totalPosts = responses[1] as int? ?? 0;
    final totalReferrals = responses[2] as int? ?? 0;
    final prevTotalUsers = responses[3] as int? ?? 0;
    final prevTotalPosts = responses[4] as int? ?? 0;
    final prevTotalReferrals = responses[5] as int? ?? 0;
    final prevCreditsUsed = responses[6] as int? ?? 0;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final int creditsUsed = await _supabase
        .from('quotes')
        .count(CountOption.exact)
        .gte('created_at', startOfMonth.toIso8601String());

    final usersChange = _calculateChange(totalUsers, prevTotalUsers);
    final postsChange = _calculateChange(totalPosts, prevTotalPosts);
    final referralsChange =
        _calculateChange(totalReferrals, prevTotalReferrals);
    final creditsChange = _calculateChange(creditsUsed, prevCreditsUsed);

    return {
      'totalUsers': totalUsers,
      'totalPosts': totalPosts,
      'creditsUsed': creditsUsed,
      'totalReferrals': totalReferrals,
      'usersChange': usersChange,
      'postsChange': postsChange,
      'creditsChange': creditsChange,
      'referralsChange': referralsChange,
    };
  }

  double _calculateChange(num current, num previous) {
    if (previous == 0) {
      return current > 0 ? 100.0 : 0.0;
    }
    return ((current - previous) / previous) * 100;
  }

  void dispose() {
    _supabase.removeChannel(_channel);
    _controller.close();
  }

  Stream<List<Map<String, dynamic>>> getUserGrowthStream() {
    return _createPollingStream(() async {
      final response = await _supabase.rpc('get_new_users_per_month');
      return List<Map<String, dynamic>>.from(response as List);
    });
  }

  Stream<List<Asset>> getB2BProducts() {
    return _supabase
        .from('assets')
        .stream(primaryKey: ['id'])
        .eq('source', 'b2b_upload')
        .order('created_at', ascending: false)
        .map((maps) => maps.map((map) => Asset.fromJson(map)).toList());
  }

  Future<void> updateAssetStatus(String assetId, String status) async {
    await _supabase.from('assets').update({'status': status}).eq('id', assetId);
  }

  Stream<List<Map<String, dynamic>>> getPostCategoriesStream() {
    return _supabase
        .from('assets')
        .stream(primaryKey: ['id']).map((listOfPosts) {
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
          .gte(
              'date',
              DateTime.now()
                  .subtract(const Duration(days: 30))
                  .toIso8601String())
          .order('date');

      return List<Map<String, dynamic>>.from(response as List).map((item) {
        return {
          'day': item['date'],
          'val': item['views'] ?? 0,
        };
      }).toList();
    });
  }

  Future<List<TimeSeriesData>> getUserGrowth(DateTimeRange dateRange) async {
    try {
      final List<dynamic> data = await _supabase.rpc(
        'get_user_growth_over_time',
        params: {
          'start_date': dateRange.start.toIso8601String(),
          'end_date': dateRange.end.toIso8601String(),
        },
      );
      return data
          .map((item) => TimeSeriesData.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e, s) {
      debugPrint('Error fetching user growth data: $e\n$s');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getDailyCreditsStream() {
    return _createPollingStream(() async {
      final response = await _supabase
          .from('analytics_daily')
          .select('date, quotes_requested')
          .gte(
              'date',
              DateTime.now()
                  .subtract(const Duration(days: 30))
                  .toIso8601String())
          .order('date');

      return List<Map<String, dynamic>>.from(response as List).map((item) {
        return {
          'day': item['date'],
          'val': item['quotes_requested'] ?? 0,
        };
      }).toList();
    });
  }

  Stream<double> getConversionRateStream() {
    return _createPollingStream(() async {
      final response = await _supabase.from('users').select('is_member');
      if (response.isEmpty) return 0.0;
      final totalUsers = response.length;
      final memberCount =
          response.where((user) => user['is_member'] == true).length;
      return (memberCount / totalUsers);
    });
  }

  Future<List<TopReferrer>> getTopReferrers({int limit = 10}) async {
    try {
      final response = await _supabase
          .rpc('get_top_referrers', params: {'limit_count': limit});
      return List<Map<String, dynamic>>.from(response as List)
          .map((data) => TopReferrer.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Error fetching top referrers: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> getSettings() async {
    try {
      final response = await _supabase.rpc('get_settings');
      if (response == null) return {};
      return Map<String, String>.from(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error fetching settings: $e');
      rethrow;
    }
  }

  Future<void> updateSetting(String key, String value) async {
    try {
      await _supabase
          .rpc('update_setting', params: {'p_key': key, 'p_value': value});
    } catch (e) {
      debugPrint('Error updating setting $key: $e');
      rethrow;
    }
  }

  // Future<List<CreditHistory>> getUserCreditHistory(String userId) async {
  //   try {
  //     final response = await _supabase
  //         .rpc('get_user_credit_history', params: {'p_user_id': userId});
  //     return List<Map<String, dynamic>>.from(response as List)
  //         .map((e) => CreditHistory.fromJson(e))
  //         .toList();
  //   } catch (e) {
  //     debugPrint("Error fetching credit history (RPC might be missing): $e");
  //     return [];
  //   }
  // }

  // Future<List<ReferralNode>> getReferralTree(String userId) async {
  //   try {
  //     final response = await _supabase
  //         .rpc('get_referral_tree', params: {'p_user_id': userId});
  //     final validData = List<Map<String, dynamic>>.from(response as List)
  //         .where((e) => e['user_id'] != null && e['level'] != null);

  //     return validData
  //         .map((e) => ReferralNode.fromJson(e))
  //         .toList();

  //   } catch (e) {
  //     debugPrint("Error fetching referral tree (RPC might be missing): $e");
  //     return [];
  //   }
  // }

  Future<List<CreditUsageLog>> getUserCreditUsage(String userId) async {
    try {
      final response = await _supabase
          .from('quotes') //
          .select('product_id, created_at, status')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20); // Get last 20 uses

      return response.map((e) => CreditUsageLog.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error fetching credit usage: $e");
      return [];
    }
  }

  Future<List<ReferredUser>> getUsersReferredBy(String userId) async {
    try {
      final response = await _supabase
          .from('referrals') //
          // We select the 'users' table data for the person who was referred
          .select('created_at, users!referrals_referred_id_fkey(username)')
          .eq('referrer_id', userId) //
          .order('created_at', ascending: false);

      return response.map((e) => ReferredUser.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error fetching referred users: $e");
      return [];
    }
  }

  Stream<List<Asset>> getScrapedContent() {
    return _supabase
        .from('assets')
        .stream(primaryKey: ['id'])
        .eq('source', 'scraped')
        .order('created_at', ascending: false)
        .map((maps) => maps.map((map) => Asset.fromJson(map)).toList());
  }

  Stream<List<Board>> getBoards() {
    return _supabase
        .from('boards')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((maps) => maps.map((map) => Board.fromJson(map)).toList());
  }

  Future<CreatorDashboard> getCreatorDashboard(String creatorId) async {
    try {
      final response = await _supabase
          .rpc('get_creator_dashboard', params: {'p_creator_id': creatorId});
      if (response == null) {
        throw Exception('No dashboard data found for creator.');
      }
      return CreatorDashboard.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint("Error fetching creator dashboard: $e");
      rethrow;
    }
  }

  Stream<List<AppUser>> getUsers({
    required String userType,
    required FilterState filterState,
  }) {
    // var baseQuery = _supabase.from('users').select();
    var baseQuery =
        _supabase.from('users').select('*, credits_remaining, referral_code');

    switch (userType) {
      case 'Members':
        baseQuery = baseQuery.eq('is_member', true);
        break;
      case 'Non-Members':
        baseQuery = baseQuery.eq('is_member', false);
        break;
      case 'B2B Creators':
        // B2B Creators are users with role 'designer'
        baseQuery = baseQuery.eq('role', 'designer');
        break;
    }

    final range = filterState.dateRange;
    if (range != null) {
      final endOfDay =
          DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);

      baseQuery = baseQuery
          .gte('created_at', range.start.toIso8601String())
          .lte('created_at', endOfDay.toIso8601String());
    }

    if (filterState.status != 'All Status') {
      // Map UI status to database values
      bool statusValue = (filterState.status == 'Approved');
      baseQuery = baseQuery.eq('is_approved', statusValue);
    }

    return baseQuery.order('created_at', ascending: false).asStream().map(
        (response) =>
            response.map((map) => _mapUserFromDatabase(map)).toList());
  }

  // Helper method to map database fields to AppUser model
  AppUser _mapUserFromDatabase(Map<String, dynamic> map) {
    // Map database role enum to string
    String? role = map['role']?.toString();

    return AppUser(
      id: map['id'],
      email: map['email'],
      username: map['username'] ??
          map['full_name'], // Use username if available, fallback to full_name
      role: role,
      approvalStatus: map['approval_status'],
      isMember: map['is_member'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
      businessName: map['business_name'],
      avatarUrl: map['avatar_url'],
      membershipPlan: map['membership_plan'],
      membershipStatus: map['is_member'] == true ? 'Active' : 'Inactive',
      creditsRemaining: map['credits_remaining'] ?? 0,
      referralCode: map['referral_code'],
    );
  }

  Future<void> updateCreatorStatus(String userId, String newStatus) async {
    try {
      Map<String, dynamic> updates;

      if (newStatus == 'approved') {
        updates = {'is_approved': true, 'role': 'designer'};
      } else if (newStatus == 'rejected') {
        updates = {'is_approved': false, 'role': 'member'};
      } else {
        updates = {'is_approved': (newStatus == 'approved')};
      }

      await _supabase.from('users').update(updates).eq('id', userId);
    } catch (e) {
      debugPrint('Error updating creator status: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      // User deletion should be handled by a secure backend function.
      debugPrint(
          'Attempted to delete user: $userId. Implement this via a backend function.');
      throw UnimplementedError(
          'User deletion should be handled by a secure backend function.');
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  Future<List<AppUser>> getApprovedCreators() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('role', 'designer')
          .eq('is_approved', true)
          .order('created_at', ascending: false);
      return response.map((data) => AppUser.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Error fetching approved creators: $e');
      rethrow;
    }
  }

  Stream<List<Asset>> getUploadedContent() {
    return _supabase
        .from('assets')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((maps) => maps.map((map) => Asset.fromJson(map)).toList());
  }

  Stream<List<AdminNotification>> getActivityLogs() {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(100)
        .map((maps) =>
            maps.map((map) => AdminNotification.fromMap(map)).toList());
  }

  Future<List<PostAnalytic>> getPostAnalytics(FilterState filterState) async {
    try {
      final dateRange = filterState.dateRange;

      // Default to a 30-day range if no custom range is set
      // (This is a fallback, but FilterState.defaultFilters should handle this)
      final startDate = dateRange?.start.toIso8601String() ??
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final endDate =
          dateRange?.end.toIso8601String() ?? DateTime.now().toIso8601String();

      // Pass the date range to your RPC
      final response = await _supabase.rpc(
        'get_all_post_analytics',
        params: {
          'start_date': startDate,
          'end_date': endDate,
        },
      );

      if (response == null || response is! List) return [];
      return List<Map<String, dynamic>>.from(response as List)
          .map((data) => PostAnalytic.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Error fetching post analytics: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMonetizationMetrics() async {
    try {
      final response = await _supabase.rpc('get_monetization_metrics');
      if (response == null || response is! Map) return {};
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error fetching monetization metrics: $e');
      rethrow;
    }
  }

  Stream<T> _createPollingStream<T>(Future<T> Function() futureFunction) {
    late StreamController<T> controller;
    Timer? timer;

    void fetchData() async {
      try {
        final result = await futureFunction();
        if (!controller.isClosed) {
          controller.add(result);
        }
      } catch (e, s) {
        if (!controller.isClosed) {
          controller.addError(e, s);
        }
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
}

class AdminNotification {
  final String id;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  AdminNotification({
    required this.id,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AdminNotification.fromMap(Map<String, dynamic> map) {
    return AdminNotification(
      id: map['id'] as String,
      message: map['message'] as String,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
