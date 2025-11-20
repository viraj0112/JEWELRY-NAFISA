// Comprehensive Analytics Service with Supabase Integration
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/analytics_models.dart';

class AnalyticsService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Fetch Top Posts from assets table
  static Future<List<TopPost>> fetchTopPosts(
      {String? timeRange,
      String? searchTerm,
      String? engagementType,
      bool? comparisonEnabled,
      int limit = 50}) async {
    try {
      final cacheKey = 'top_posts_${timeRange}_$limit';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<TopPost>;
      }

      final dateFilter = _getDateFilter(timeRange);
      var query = _supabase
          .from('assets')
          .select('id, title, category, thumb_url, tags, created_at');
      if (dateFilter != null) query = query.gte('created_at', dateFilter);
      final assetsResponse =
          await query.order('created_at', ascending: false).limit(limit);

      List<TopPost> posts = [];
      for (final asset in assetsResponse) {
        final assetId = asset['id'] as String;
        final analyticsData = await _supabase
            .from('analytics_daily')
            .select('views, likes, saves, quotes_requested, shares')
            .eq('asset_id', assetId);

        int totalViews = 0,
            totalLikes = 0,
            totalSaves = 0,
            totalQuotes = 0,
            totalShares = 0;
        for (final data in analyticsData) {
          totalViews += (data['views'] as int?) ?? 0;
          totalLikes += (data['likes'] as int?) ?? 0;
          totalSaves += (data['saves'] as int?) ?? 0;
          totalQuotes += (data['quotes_requested'] as int?) ?? 0;
          totalShares += (data['shares'] as int?) ?? 0;
        }

        posts.add(TopPost(
          id: assetId,
          title: asset['title'] ?? '',
          category: asset['category'] ?? 'Uncategorized',
          views: totalViews,
          likes: totalLikes,
          comments: totalQuotes, // Using quotes as comments for now
          saves: totalSaves,
          quotesRequested: totalQuotes,
          shares: totalShares,
          date: DateTime.parse(
              asset['created_at'] ?? DateTime.now().toIso8601String()),
          thumbUrl: asset['thumb_url'],
          thumbnail: asset['thumb_url'],
          tags: asset['tags'] is List ? List<String>.from(asset['tags']) : null,
        ));
      }
      posts.sort((a, b) => b.views.compareTo(a.views));
      _cacheResult(cacheKey, posts);
      return posts;
    } catch (e) {
      debugPrint('Error fetching top posts: $e');
      return [];
    }
  }

  /// Fetch Engagement Trends
  static Future<List<EngagementTrend>> fetchEngagementTrends(
      {String? timeRange}) async {
    try {
      final cacheKey = 'engagement_trends_${timeRange}';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<EngagementTrend>;
      }

      final dateFilter = _getDateFilter(timeRange);
      var query = _supabase
          .from('analytics_daily')
          .select('date, views, likes, saves, quotes_requested, shares');
      if (dateFilter != null)
        query = query.gte('date', dateFilter.split('T')[0]);
      final response = await query.order('date', ascending: true);

      final Map<String, Map<String, int>> dailyAggregates = {};
      for (final item in response) {
        final dateKey = item['date'] as String;
        if (!dailyAggregates.containsKey(dateKey)) {
          dailyAggregates[dateKey] = {
            'views': 0,
            'likes': 0,
            'saves': 0,
            'quotes_requested': 0,
            'shares': 0
          };
        }
        dailyAggregates[dateKey]!['views'] =
            (dailyAggregates[dateKey]!['views'] ?? 0) +
                ((item['views'] as int?) ?? 0);
        dailyAggregates[dateKey]!['likes'] =
            (dailyAggregates[dateKey]!['likes'] ?? 0) +
                ((item['likes'] as int?) ?? 0);
        dailyAggregates[dateKey]!['saves'] =
            (dailyAggregates[dateKey]!['saves'] ?? 0) +
                ((item['saves'] as int?) ?? 0);
        dailyAggregates[dateKey]!['quotes_requested'] =
            (dailyAggregates[dateKey]!['quotes_requested'] ?? 0) +
                ((item['quotes_requested'] as int?) ?? 0);
        dailyAggregates[dateKey]!['shares'] =
            (dailyAggregates[dateKey]!['shares'] ?? 0) +
                ((item['shares'] as int?) ?? 0);
      }

      List<EngagementTrend> trends = [];
      for (final entry in dailyAggregates.entries) {
        final date = DateTime.parse(entry.key);
        final data = entry.value;
        trends.add(EngagementTrend(
          date: date,
          views: data['views'] ?? 0,
          likes: data['likes'] ?? 0,
          saves: data['saves'] ?? 0,
          quotesRequested: data['quotes_requested'] ?? 0,
          shares: data['shares'] ?? 0,
        ));
      }
      _cacheResult(cacheKey, trends);
      return trends;
    } catch (e) {
      debugPrint('Error fetching engagement trends: $e');
      return [];
    }
  }

  /// Fetch Users by purchase probability
  static Future<List<PurchaseProbability>> fetchPurchaseProbability(
      {int minCredits = 0, int maxCredits = 1000000}) async {
    try {
      final cacheKey = 'purchase_probability_${minCredits}_${maxCredits}';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<PurchaseProbability>;
      }

      final response = await _supabase
          .from('users')
          .select('id, full_name, email, credits_remaining, is_member')
          .gte('credits_remaining', minCredits)
          .lte('credits_remaining', maxCredits)
          .order('credits_remaining', ascending: false);

      List<PurchaseProbability> users = [];
      for (final item in response) {
        final quotesResponse = await _supabase
            .from('quote_requests')
            .select('id')
            .eq('user_id', item['id']);
        users.add(PurchaseProbability(
          id: item['id'] ?? '',
          name: item['full_name'] ?? 'Unknown User',
          email: item['email'] ?? '',
          activityScore: (item['credits_remaining'] as int?) ?? 0,
          probability: quotesResponse.length * 10, // Simple calculation
          recentActions: ['Viewed assets', 'Made searches'],
          creditsRemaining: (item['credits_remaining'] as int?) ?? 0,
          quotesRequested: quotesResponse.length,
          isMember: item['is_member'] ?? false,
        ));
      }
      _cacheResult(cacheKey, users);
      return users;
    } catch (e) {
      debugPrint('Error fetching purchase probability: $e');
      return [];
    }
  }

  /// Fetch Conversion Funnel
  static Future<List<ConversionFunnelStage>> fetchConversionFunnel() async {
    try {
      final cacheKey = 'conversion_funnel';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<ConversionFunnelStage>;
      }

      final totalUsers = await _supabase.from('users').select('id');
      final members =
          await _supabase.from('users').select('id').eq('is_member', true);
      final approved =
          await _supabase.from('users').select('id').eq('is_approved', true);
      final active =
          await _supabase.from('users').select('id').gt('credits_remaining', 0);

      final total = totalUsers.length;
      final memberCount = members.length;
      final approvedCount = approved.length;
      final activeCount = active.length;

      final funnelStages = [
        ConversionFunnelStage(
            stage: 'Total Users',
            users: total,
            percentage: 100.0,
            fill: const Color(0xFFe0e7ff)),
        ConversionFunnelStage(
            stage: 'Approved',
            users: approvedCount,
            percentage: total > 0 ? (approvedCount / total * 100) : 0,
            fill: const Color(0xFFc7d2fe)),
        ConversionFunnelStage(
            stage: 'Active',
            users: activeCount,
            percentage: total > 0 ? (activeCount / total * 100) : 0,
            fill: const Color(0xFFa5b4fc)),
        ConversionFunnelStage(
            stage: 'Members',
            users: memberCount,
            percentage: total > 0 ? (memberCount / total * 100) : 0,
            fill: const Color(0xFF8b5cf6)),
      ];
      _cacheResult(cacheKey, funnelStages);
      return funnelStages;
    } catch (e) {
      debugPrint('Error fetching conversion funnel: $e');
      return [];
    }
  }

  /// Fetch Top Members
  static Future<List<TopMember>> fetchTopMembers({int limit = 10}) async {
    try {
      final cacheKey = 'top_members_$limit';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<TopMember>;
      }

      final usersResponse = await _supabase
          .from('users')
          .select('id, username, avatar_url, role')
          .order('created_at', ascending: false)
          .limit(limit);
      List<TopMember> members = [];

      for (final user in usersResponse) {
        final assetsResponse = await _supabase
            .from('assets')
            .select('id')
            .eq('owner_id', user['id']);
        int totalViews = 0, totalLikes = 0;

        for (final asset in assetsResponse) {
          final analytics = await _supabase
              .from('analytics_daily')
              .select('views, likes')
              .eq('asset_id', asset['id']);
          for (final data in analytics) {
            totalViews += (data['views'] as int?) ?? 0;
            totalLikes += (data['likes'] as int?) ?? 0;
          }
        }

        members.add(TopMember(
          id: user['id'] ?? '',
          username: user['username'] ?? 'Unknown',
          avatarUrl: user['avatar_url'],
          avatar: user['username']?.substring(0, 1).toUpperCase() ?? 'U',
          name: user['username'] ?? 'Unknown',
          posts: assetsResponse.length,
          saves: totalLikes,
          engagement: totalViews,
          assetsCount: assetsResponse.length,
          totalViews: totalViews,
          totalLikes: totalLikes,
          role: user['role'],
        ));
      }
      members.sort((a, b) => b.totalViews.compareTo(a.totalViews));
      _cacheResult(cacheKey, members);
      return members;
    } catch (e) {
      debugPrint('Error fetching top members: $e');
      return [];
    }
  }

  /// Fetch Category Preferences
  static Future<List<CategoryPreference>> fetchCategoryPreferences() async {
    try {
      final cacheKey = 'category_preferences';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<CategoryPreference>;
      }

      final response =
          await _supabase.from('assets').select('category').order('category');
      Map<String, int> categoryCount = {};

      for (final item in response) {
        final category = item['category'] ?? 'Uncategorized';
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }

      int totalAssets = categoryCount.isEmpty
          ? 0
          : categoryCount.values.reduce((a, b) => a + b);
      List<CategoryPreference> preferences = [];
      int index = 0;

      categoryCount.forEach((category, count) {
        final percentage = totalAssets > 0 ? (count / totalAssets * 100) : 0.0;
        final colors = [
          const Color(0xFF8b5cf6), // Purple
          const Color(0xFFec4899), // Pink
          const Color(0xFF06b6d4), // Cyan
          const Color(0xFFf59e0b), // Amber
          const Color(0xFF10b981), // Green
        ];
        preferences.add(CategoryPreference(
          name: category,
          category: category,
          assetCount: count,
          members: count, // Using asset count as members for now
          value: count.toDouble(),
          percentage: percentage,
          color: colors[index % colors.length],
        ));
        index++;
      });

      preferences.sort((a, b) => b.assetCount.compareTo(a.assetCount));
      _cacheResult(cacheKey, preferences);
      return preferences;
    } catch (e) {
      debugPrint('Error fetching category preferences: $e');
      return [];
    }
  }

  /// Fetch Credit Users
  static Future<List<CreditUser>> fetchCreditUsers(
      {int minCredits = 0, int maxCredits = 1000000, int limit = 100}) async {
    try {
      final cacheKey = 'credit_users_${minCredits}_${maxCredits}_$limit';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<CreditUser>;
      }

      final response = await _supabase
          .from('users')
          .select(
              'id, username, email, credits_remaining, last_credit_refresh, is_member, created_at')
          .gte('credits_remaining', minCredits)
          .lte('credits_remaining', maxCredits)
          .order('credits_remaining', ascending: false)
          .limit(limit);

      List<CreditUser> users = [];
      for (final item in response) {
        users.add(CreditUser(
          id: item['id'] ?? '',
          username: item['username'] ?? '',
          email: item['email'] ?? '',
          creditsRemaining: (item['credits_remaining'] as int?) ?? 0,
          currentCredits: (item['credits_remaining'] as int?) ?? 0,
          lastCreditRefresh: item['last_credit_refresh'] != null
              ? DateTime.parse(item['last_credit_refresh'])
              : null,
          isMember: item['is_member'] ?? false,
          createdAt: DateTime.parse(
              item['created_at'] ?? DateTime.now().toIso8601String()),
          source: CreditSource.admin, // Default to admin
          lastEarned: 0, // Default value
        ));
      }
      _cacheResult(cacheKey, users);
      return users;
    } catch (e) {
      debugPrint('Error fetching credit users: $e');
      return [];
    }
  }

  static bool _isCacheValid(String key) {
    if (!_cache.containsKey(key) || !_cacheTimestamp.containsKey(key))
      return false;
    final timestamp = _cacheTimestamp[key]!;
    return DateTime.now().difference(timestamp).inMilliseconds <
        _cacheTimeout.inMilliseconds;
  }

  static void _cacheResult(String key, dynamic value) {
    _cache[key] = value;
    _cacheTimestamp[key] = DateTime.now();
  }

  static String? _getDateFilter(String? timeRange) {
    if (timeRange == null || timeRange == 'all') return null;
    final now = DateTime.now();
    final startDate = switch (timeRange) {
      '1d' => now.subtract(const Duration(days: 1)),
      '7d' => now.subtract(const Duration(days: 7)),
      '30d' => now.subtract(const Duration(days: 30)),
      '90d' => now.subtract(const Duration(days: 90)),
      _ => null,
    };
    return startDate?.toIso8601String();
  }

  static void clearCache() {
    _cache.clear();
    _cacheTimestamp.clear();
  }

  static void clearCacheKey(String key) {
    _cache.remove(key);
    _cacheTimestamp.remove(key);
  }

  /// Get Credit Distribution
  static List<CreditDistribution> getCreditDistribution(List<CreditUser> users) {
    final distribution = <String, int>{};
    
    for (final user in users) {
      final range = _getCreditRange(user.currentCredits);
      distribution[range] = (distribution[range] ?? 0) + 1;
    }
    
    return distribution.entries
        .map((entry) => CreditDistribution(range: entry.key, users: entry.value))
        .toList()
      ..sort((a, b) => a.range.compareTo(b.range));
  }

  /// Get Credit Summary Cards
  static List<CreditSummary> getCreditSummaryCards(List<CreditUser> users) {
    if (users.isEmpty) {
      return [];
    }
    
    final totalCredits = users.fold<int>(0, (sum, user) => sum + user.currentCredits);
    final averageCredits = (totalCredits / users.length).round();
    final totalUsers = users.length;
    final memberUsers = users.where((user) => user.isMember).length;
    
    return [
      CreditSummary(
        label: 'Total Credits',
        value: totalCredits.formatted,
        color: const Color(0xFF8b5cf6),
        icon: FontAwesomeIcons.coins,
      ),
      CreditSummary(
        label: 'Average Credits',
        value: averageCredits.toString(),
        color: const Color(0xFF06b6d4),
        icon: FontAwesomeIcons.chartLine,
      ),
      CreditSummary(
        label: 'Total Users',
        value: totalUsers.toString(),
        color: const Color(0xFF10b981),
        icon: FontAwesomeIcons.users,
      ),
      CreditSummary(
        label: 'Member Users',
        value: memberUsers.toString(),
        color: const Color(0xFFf59e0b),
        icon: FontAwesomeIcons.crown,
      ),
    ];
  }

  /// Add Credits to User
  static Future<bool> addCredits(String userId, int amount, CreditSource source) async {
    try {
      // First get the current credits
      final userResponse = await _supabase
          .from('users')
          .select('credits_remaining')
          .eq('id', userId)
          .single();
      
      final currentCredits = userResponse['credits_remaining'] as int? ?? 0;
      final newCredits = currentCredits + amount;
      
      // Update the user with new credit amount
      await _supabase
          .from('users')
          .update({
            'credits_remaining': newCredits,
            'last_credit_refresh': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      
      // Log the credit transaction
      await _supabase.from('credit_transactions').insert({
        'user_id': userId,
        'amount': amount,
        'source': source.name,
        'type': 'credit',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      debugPrint('Error adding credits: $e');
      return false;
    }
  }

  /// Send Bulk Message to Users
  static Future<bool> sendBulkMessage(List<String> userIds, String message) async {
    try {
      // In a real implementation, this would send notifications/messages
      // For now, we'll just simulate success
      await Future.delayed(const Duration(seconds: 1));
      
      // Log the bulk message
      await _supabase.from('bulk_messages').insert({
        'user_ids': userIds,
        'message': message,
        'sent_at': DateTime.now().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      debugPrint('Error sending bulk message: $e');
      return false;
    }
  }

  static String _getCreditRange(int credits) {
    if (credits >= 500) return '500+';
    if (credits >= 300) return '300-499';
    if (credits >= 100) return '100-299';
    if (credits >= 50) return '50-99';
    return '0-49';
  }
}

extension DateTimeFormat on DateTime {
  String get formattedDate =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  String get formattedDateTime =>
      '$formattedDate ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
