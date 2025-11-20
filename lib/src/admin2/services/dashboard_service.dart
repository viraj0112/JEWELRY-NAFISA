import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dashboard_models.dart';

class DashboardService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Fetch complete dashboard data
  static Future<DashboardData> fetchDashboardData(
      {String timeRange = '7d'}) async {
    try {
      final kpiMetrics = await _fetchKPIMetrics();
      final userGrowthData = await _fetchUserGrowthData(timeRange);
      final hourlyActivity = await _fetchHourlyActivity();
      final geographicData = await _fetchGeographicData('country', '');
      final categoryInsights = await _fetchCategoryInsights();
      final topPosts = await _fetchTopPosts();
      final conversionFunnel = await _fetchConversionFunnel();

      return DashboardData(
        kpiMetrics: kpiMetrics,
        userGrowthData: userGrowthData,
        hourlyActivity: hourlyActivity,
        geographicData: geographicData,
        categoryInsights: categoryInsights,
        topPosts: topPosts,
        conversionFunnel: conversionFunnel,
      );
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      throw Exception('Failed to load dashboard data');
    }
  }

  /// Fetch KPI Metrics
  static Future<KPIMetrics> _fetchKPIMetrics() async {
    final cacheKey = 'kpi_metrics';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey] as KPIMetrics;
    }

    try {
      // Total Members
      final membersResponse =
          await _supabase.from('users').select('id').eq('is_member', true);
      final totalMembers = membersResponse.length;

      // Total Non-Members
      final nonMembersResponse =
          await _supabase.from('users').select('id').neq('is_member', true);
      final totalNonMembers = nonMembersResponse.length;

      // Daily Active Users (users with activity today)
      final today = DateTime.now().toIso8601String().split('T')[0];
      final dauResponse = await _supabase
          .from('views')
          .select('user_id')
          .gte('created_at', today)
          .not('user_id', 'is', null);
      final dailyActiveUsers =
          dauResponse.map((e) => e['user_id']).toSet().length;

      // Credits Used Today
      final creditsUsedResponse = await _supabase
          .from('user_unlocked_items')
          .select('id')
          .gte('unlocked_at', today);
      final creditsUsedToday = creditsUsedResponse.length;

      // Total Referrals
      final referralsResponse = await _supabase.from('referrals').select('id');
      final totalReferrals = referralsResponse.length;

      // Posts Viewed Today
      final postsViewedResponse =
          await _supabase.from('views').select('id').gte('created_at', today);
      final postsViewedToday = postsViewedResponse.length;

      // Calculate growth percentages (simplified - comparing to yesterday)
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .split('T')[0];

      final yesterdayMembers = (await _supabase
              .from('users')
              .select('id')
              .eq('is_member', true)
              .lt('created_at', today))
          .length;

      final yesterdayViews = (await _supabase
              .from('views')
              .select('id')
              .gte('created_at', yesterday)
              .lt('created_at', today))
          .length;

      final membersGrowth = yesterdayMembers > 0
          ? ((totalMembers - yesterdayMembers) / yesterdayMembers) * 100
          : 0.0;
      final viewsGrowth = yesterdayViews > 0
          ? ((postsViewedToday - yesterdayViews) / yesterdayViews) * 100
          : 0.0;

      final kpiMetrics = KPIMetrics(
        totalMembers: totalMembers,
        totalNonMembers: totalNonMembers,
        dailyActiveUsers: dailyActiveUsers,
        creditsUsedToday: creditsUsedToday,
        totalReferrals: totalReferrals,
        postsViewedToday: postsViewedToday,
        membersGrowth: membersGrowth.toDouble(),
        nonMembersGrowth: 0.0, // Simplified
        dauGrowth: 0.0, // Simplified
        creditsGrowth: 0.0, // Simplified
        referralsGrowth: 0.0, // Simplified
        viewsGrowth: viewsGrowth.toDouble(),
      );

      _cacheResult(cacheKey, kpiMetrics);
      return kpiMetrics;
    } catch (e) {
      debugPrint('Error fetching KPI metrics: $e');
      return KPIMetrics(
        totalMembers: 0,
        totalNonMembers: 0,
        dailyActiveUsers: 0,
        creditsUsedToday: 0,
        totalReferrals: 0,
        postsViewedToday: 0,
        membersGrowth: 0,
        nonMembersGrowth: 0,
        dauGrowth: 0,
        creditsGrowth: 0,
        referralsGrowth: 0,
        viewsGrowth: 0,
      );
    }
  }

  /// Fetch User Growth Data
  static Future<List<UserGrowthData>> _fetchUserGrowthData(
      String timeRange) async {
    final cacheKey = 'user_growth_$timeRange';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey] as List<UserGrowthData>;
    }

    try {
      final days = _getDaysFromTimeRange(timeRange);
      final startDate = DateTime.now().subtract(Duration(days: days));

      List<UserGrowthData> growthData = [];

      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];

        final membersResponse = await _supabase
            .from('users')
            .select('id')
            .eq('is_member', true)
            .lte('created_at', '${dateStr}T23:59:59');

        final nonMembersResponse = await _supabase
            .from('users')
            .select('id')
            .neq('is_member', true)
            .lte('created_at', '${dateStr}T23:59:59');

        growthData.add(UserGrowthData(
          date: date,
          members: membersResponse.length,
          nonMembers: nonMembersResponse.length,
        ));
      }

      _cacheResult(cacheKey, growthData);
      return growthData;
    } catch (e) {
      debugPrint('Error fetching user growth data: $e');
      return [];
    }
  }

  /// Fetch Hourly Activity
  static Future<List<HourlyActivity>> _fetchHourlyActivity() async {
    final cacheKey = 'hourly_activity';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey] as List<HourlyActivity>;
    }

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await _supabase
          .from('views')
          .select('created_at')
          .gte('created_at', today);

      Map<int, int> hourlyData = {};

      for (final view in response) {
        final createdAt = DateTime.parse(view['created_at']);
        final hour = createdAt.hour;
        hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
      }

      List<HourlyActivity> activity = [];
      for (int hour = 0; hour < 24; hour++) {
        activity.add(HourlyActivity(
          hour: hour,
          activityCount: hourlyData[hour] ?? 0,
        ));
      }

      _cacheResult(cacheKey, activity);
      return activity;
    } catch (e) {
      debugPrint('Error fetching hourly activity: $e');
      return List.generate(
          24, (hour) => HourlyActivity(hour: hour, activityCount: 0));
    }
  }

  /// Fetch Geographic Data
  static Future<GeographicData> _fetchGeographicData(
      String level, String parentCode) async {
    final cacheKey = 'geographic_${level}_$parentCode';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey] as GeographicData;
    }

    try {
      String column;
      switch (level) {
        case 'country':
          column = 'country';
          break;
        case 'state':
          column = 'region'; // Assuming region maps to state
          break;
        default:
          column = 'country';
      }

      final response = await _supabase
          .from('views')
          .select('$column, user_id')
          .not(column, 'is', null);

      Map<String, int> geoCounts = {};
      int totalUsers = response.length;

      for (final view in response) {
        final code = view[column] ?? 'Unknown';
        geoCounts[code] = (geoCounts[code] ?? 0) + 1;
      }

      List<GeographicItem> items = geoCounts.entries.map((entry) {
        final percentage =
            totalUsers > 0 ? (entry.value / totalUsers) * 100 : 0.0;
        return GeographicItem(
          code: entry.key,
          name: entry.key,
          userCount: entry.value,
          percentage: percentage.toDouble(),
          isGrowing: true, // Simplified
        );
      }).toList();

      items.sort((a, b) => b.userCount.compareTo(a.userCount));

      final geoData = GeographicData(
        level: level,
        parentCode: parentCode,
        items: items,
      );

      _cacheResult(cacheKey, geoData);
      return geoData;
    } catch (e) {
      debugPrint('Error fetching geographic data: $e');
      return GeographicData(
        level: level,
        parentCode: parentCode,
        items: [],
      );
    }
  }

  /// Fetch Category Insights
  static Future<List<CategoryInsight>> _fetchCategoryInsights() async {
    const cacheKey = 'category_insights';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey] as List<CategoryInsight>;
    }

    try {
      final assetsResponse = await _supabase
          .from('assets')
          .select('id, title, category, created_at')
          .order('created_at', ascending: false);

      if (assetsResponse.isEmpty) {
        _cacheResult(cacheKey, <CategoryInsight>[]);
        return [];
      }

      final Map<String, List<Map<String, dynamic>>> groupedByCategory = {};
      for (final asset in assetsResponse) {
        final rawCategory = (asset['category'] as String?)?.trim();
        final category = (rawCategory == null || rawCategory.isEmpty)
            ? 'Uncategorized'
            : rawCategory;
        groupedByCategory.putIfAbsent(category, () => []).add(asset);
      }

      final sortedCategories = groupedByCategory.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

      final palette = [
        Colors.purple,
        Colors.teal,
        Colors.orange,
        Colors.blue,
        Colors.pink,
        Colors.amber,
      ];

      final List<CategoryInsight> insights = [];
      final recentThreshold = DateTime.now().subtract(const Duration(days: 30));

      for (int i = 0; i < sortedCategories.length && i < 6; i++) {
        final entry = sortedCategories[i];
        final category = entry.key;
        final assets = entry.value;

        final recentCount = assets.where((asset) {
          final createdAt = DateTime.tryParse(asset['created_at'] ?? '');
          return createdAt != null && createdAt.isAfter(recentThreshold);
        }).length;

        final previousCount = assets.length - recentCount;
        final growth = previousCount == 0
            ? 100.0
            : ((recentCount - previousCount) / previousCount) * 100;

        final assetIds =
            assets.take(10).map((asset) => asset['id'] as String).toList();

        final analyticsResponse = assetIds.isEmpty
            ? <dynamic>[]
            : await _analyticsQuery(
                assetIds,
                'asset_id, views, likes, saves, shares, quotes_requested',
              );

        final Map<String, Map<String, int>> metricsByAsset = {};
        for (final metric in analyticsResponse) {
          final assetId = metric['asset_id'] as String?;
          if (assetId == null) continue;
          metricsByAsset.putIfAbsent(
              assetId,
              () => {
                    'views': 0,
                    'likes': 0,
                    'saves': 0,
                    'shares': 0,
                    'quotes': 0,
                  });
          metricsByAsset[assetId]!['views'] =
              metricsByAsset[assetId]!['views']! +
                  (metric['views'] as int? ?? 0);
          metricsByAsset[assetId]!['likes'] =
              metricsByAsset[assetId]!['likes']! +
                  (metric['likes'] as int? ?? 0);
          metricsByAsset[assetId]!['saves'] =
              metricsByAsset[assetId]!['saves']! +
                  (metric['saves'] as int? ?? 0);
          metricsByAsset[assetId]!['shares'] =
              metricsByAsset[assetId]!['shares']! +
                  (metric['shares'] as int? ?? 0);
          metricsByAsset[assetId]!['quotes'] =
              metricsByAsset[assetId]!['quotes']! +
                  (metric['quotes_requested'] as int? ?? 0);
        }

        final topPosts = assets.take(4).map((asset) {
          final id = asset['id'] as String? ?? '';
          final createdAt =
              DateTime.tryParse(asset['created_at'] ?? '') ?? DateTime.now();
          final metrics = metricsByAsset[id] ?? {};
          return TopPost(
            id: id,
            title: asset['title'] ?? 'Untitled',
            category: category,
            views: metrics['views'] ?? 0,
            unlocks: metrics['quotes'] ?? 0,
            saves: metrics['saves'] ?? 0,
            shares: metrics['shares'] ?? 0,
            date: createdAt,
          );
        }).toList();

        insights.add(
          CategoryInsight(
            category: category,
            totalPins: assets.length,
            totalImages: assets.length,
            growthPercentage: growth,
            topPosts: topPosts,
            color: palette[i % palette.length],
          ),
        );
      }

      _cacheResult(cacheKey, insights);
      return insights;
    } catch (e) {
      debugPrint('Error fetching category insights: $e');
      return [];
    }
  }

  /// Fetch Top Posts
  static Future<List<TopPost>> _fetchTopPosts({int limit = 5}) async {
    final cacheKey = 'top_posts_$limit';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey] as List<TopPost>;
    }

    try {
      final response = await _supabase
          .from('assets')
          .select('id, title, category, created_at')
          .order('created_at', ascending: false)
          .limit(limit);

      List<TopPost> posts = response.map((post) {
        return TopPost(
          id: post['id'],
          title: post['title'] ?? 'Untitled',
          category: post['category'] ?? 'Uncategorized',
          views: 0, // Would need analytics join
          unlocks: 0,
          saves: 0,
          shares: 0,
          date: DateTime.parse(post['created_at']),
        );
      }).toList();

      _cacheResult(cacheKey, posts);
      return posts;
    } catch (e) {
      debugPrint('Error fetching top posts: $e');
      return [];
    }
  }

  /// Fetch Conversion Funnel
  static Future<ConversionFunnel> _fetchConversionFunnel() async {
    final cacheKey = 'conversion_funnel';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey] as ConversionFunnel;
    }

    try {
      final totalUsers = await _supabase.from('users').select('id');
      final signups = totalUsers.length;

      final firstLogins = await _supabase
          .from('users')
          .select('id')
          .not('last_credit_refresh', 'is', null);
      final firstLoginCount = firstLogins.length;

      final creditUsers =
          await _supabase.from('users').select('id').gt('credits_remaining', 0);
      final creditUseCount = creditUsers.length;

      final members =
          await _supabase.from('users').select('id').eq('is_member', true);
      final membershipCount = members.length;

      // Calculate percentages and changes (simplified)
      final funnel = ConversionFunnel(
        signups: FunnelStage(
          name: 'Signups',
          users: signups,
          percentage: 100,
          changeFromPrevious: 0,
        ),
        firstLogin: FunnelStage(
          name: 'First Login',
          users: firstLoginCount,
          percentage: signups > 0 ? (firstLoginCount / signups) * 100 : 0,
          changeFromPrevious: 0,
        ),
        creditUse: FunnelStage(
          name: 'Credit Use',
          users: creditUseCount,
          percentage: signups > 0 ? (creditUseCount / signups) * 100 : 0,
          changeFromPrevious: 0,
        ),
        membership: FunnelStage(
          name: 'Membership',
          users: membershipCount,
          percentage: signups > 0 ? (membershipCount / signups) * 100 : 0,
          changeFromPrevious: 0,
        ),
      );

      _cacheResult(cacheKey, funnel);
      return funnel;
    } catch (e) {
      debugPrint('Error fetching conversion funnel: $e');
      return ConversionFunnel(
        signups: FunnelStage(
            name: 'Signups', users: 0, percentage: 0, changeFromPrevious: 0),
        firstLogin: FunnelStage(
            name: 'First Login',
            users: 0,
            percentage: 0,
            changeFromPrevious: 0),
        creditUse: FunnelStage(
            name: 'Credit Use', users: 0, percentage: 0, changeFromPrevious: 0),
        membership: FunnelStage(
            name: 'Membership', users: 0, percentage: 0, changeFromPrevious: 0),
      );
    }
  }

  static bool _isCacheValid(String key) {
    if (!_cache.containsKey(key) || !_cacheTimestamp.containsKey(key))
      return false;
    final timestamp = _cacheTimestamp[key]!;
    return DateTime.now().difference(timestamp) < _cacheTimeout;
  }

  static void _cacheResult(String key, dynamic value) {
    _cache[key] = value;
    _cacheTimestamp[key] = DateTime.now();
  }

  static int _getDaysFromTimeRange(String timeRange) {
    switch (timeRange) {
      case '1d':
        return 1;
      case '7d':
        return 7;
      case '30d':
        return 30;
      default:
        return 7;
    }
  }

  static void clearCache() {
    _cache.clear();
    _cacheTimestamp.clear();
  }

  static Future<List<dynamic>> _analyticsQuery(
      List<String> assetIds, String columns) {
    var query = _supabase.from('analytics_daily').select(columns);
    if (assetIds.isEmpty) {
      return query;
    }

    if (assetIds.length == 1) {
      query = query.eq('asset_id', assetIds.first);
    } else {
      final formattedIds = '(${assetIds.map((id) => '"$id"').join(',')})';
      query = query.filter('asset_id', 'in', formattedIds);
    }
    return query;
  }
}
