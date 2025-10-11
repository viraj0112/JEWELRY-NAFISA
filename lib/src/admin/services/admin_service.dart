import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:flutter/material.dart';

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

  Stream<Map<String, dynamic>> getDashboardMetricsStream() {
    fetchDashboardMetrics().then((metrics) {
      if (!_controller.isClosed) {
        _controller.add(metrics);
      }
    });
    return _controller.stream;
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
    final creditsUsedRes = await _supabase
        .from('analytics_daily')
        .select('quotes_requested')
        .gte('date', startOfMonth.toIso8601String());

    int creditsUsed = 0;
    for (var row in creditsUsedRes) {
      creditsUsed += (row['quotes_requested'] as int?) ?? 0;
    }

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
      return (response as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
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
      final memberCount =
          response.where((user) => user['is_member'] == true).length;
      return (memberCount / totalUsers);
    });
  }

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

  Future<Map<String, String>> getSettings() async {
    try {
      final response = await _supabase.rpc('get_settings');
      return Map<String, String>.from(response);
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

  Future<List<CreditHistory>> getUserCreditHistory(String userId) async {
    final response = await _supabase
        .rpc('get_user_credit_history', params: {'p_user_id': userId});
    return (response as List).map((e) => CreditHistory.fromJson(e)).toList();
  }

  Future<List<ReferralNode>> getReferralTree(String userId) async {
    final response =
        await _supabase.rpc('get_referral_tree', params: {'p_user_id': userId});
    return (response as List).map((e) => ReferralNode.fromJson(e)).toList();
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
    final response = await _supabase
        .rpc('get_creator_dashboard', params: {'p_creator_id': creatorId});
    return CreatorDashboard.fromJson(response);
  }

  Stream<List<AppUser>> getUsers({
    required String userType,
    required FilterState filterState,
  }) {
    // Start with select query
    var baseQuery = _supabase.from('users').select();

    switch (userType) {
      case 'Members':
        baseQuery = baseQuery.eq('is_member', true);
        break;
      case 'Non-Members':
        baseQuery = baseQuery.eq('is_member', false);
        break;
      case 'B2B Creators':
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
      baseQuery =
          baseQuery.eq('approval_status', filterState.status.toLowerCase());
    }

    // Apply stream() at the end with all filters already applied
    return baseQuery.order('created_at', ascending: false).asStream().map(
        (response) =>
            (response as List).map((map) => AppUser.fromJson(map)).toList());
  }

  Stream<List<AppUser>> getPendingCreators() {
    return _supabase
        .from('users')
        .select()
        .eq('role', 'designer')
        .eq('approval_status', 'pending')
        .order('created_at', ascending: true)
        .asStream()
        .map((response) =>
            (response as List).map((map) => AppUser.fromJson(map)).toList());
  }

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

  Future<void> deleteUser(String userId) async {
    try {
      await _supabase.from('users').delete().eq('id', userId);
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
          .eq('approval_status', 'approved')
          .order('created_at', ascending: false);
      return (response as List).map((data) => AppUser.fromJson(data)).toList();
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

  Stream<List<Notification>> getActivityLogs() {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(100)
        .map((maps) => maps.map((map) => Notification.fromMap(map)).toList());
  }

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

  Future<Map<String, dynamic>> getMonetizationMetrics() async {
    try {
      final response = await _supabase.rpc('get_monetization_metrics');
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
        controller.close();
      },
    );

    return controller.stream;
  }
}

class Notification {
  final String id;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  Notification({
    required this.id,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'],
      message: map['message'],
      isRead: map['is_read'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
