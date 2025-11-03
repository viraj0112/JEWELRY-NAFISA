import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/admin/models/enhanced_admin_models.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart' as old_models;

class EnhancedAdminService {
  final _supabase = Supabase.instance.client;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  late final RealtimeChannel _channel;

  EnhancedAdminService() {
    _channel = _supabase.channel('enhanced_dashboard');
    _channel
        .onBroadcast(
          event: 'metrics-update',
          callback: (payload) async {
            final metrics = await fetchDashboardMetrics();
            if (!_controller.isClosed) {
              _controller.add({
                'totalUsers': metrics.totalUsers,
                'totalMembers': metrics.totalMembers,
                'totalPosts': metrics.totalPosts,
                'dailyCreditsUsed': metrics.dailyCreditsUsed,
              });
            }
          },
        )
        .subscribe();
  }

  // ===== DASHBOARD OVERVIEW =====
  Future<DashboardMetrics> fetchDashboardMetrics() async {
    try {
      // Get counts using proper Supabase queries
      final totalUsersResponse = await _supabase
          .from('users')
          .select('id')
          .count(CountOption.exact);
       
      final totalMembersResponse = await _supabase
          .from('users')
          .select('id') // FIX: Changed from '*' to 'id'
          .eq('is_member', true)
          .count(CountOption.exact); // FIX: Moved count() here
           
      final totalNonMembersResponse = await _supabase
          .from('users')
          .select('id') // FIX: Changed from '*' to 'id'
          .eq('is_member', false)
          .neq('role', 'designer')
          .count(CountOption.exact); // FIX: Moved count() here
           
      final totalBCreatorsResponse = await _supabase
          .from('users')
          .select('id') // FIX: Changed from '*' to 'id'
          .eq('role', 'designer')
          .count(CountOption.exact); // FIX: Moved count() here
           
      final totalPostsResponse = await _supabase
          .from('assets')
          .select('id') // FIX: Changed from '*' to 'id'
          .count(CountOption.exact); // FIX: Moved count() here
           
      final scrapedPostsResponse = await _supabase
          .from('assets')
          .select('id') // FIX: Changed from '*' to 'id'
          .eq('source', 'scraped')
          .count(CountOption.exact); // FIX: Moved count() here
           
      final uploadedPostsResponse = await _supabase
          .from('assets')
          .select('id') // FIX: Changed from '*' to 'id'
          .eq('source', 'b2b_upload')
          .count(CountOption.exact); // FIX: Moved count() here

      final dailyCreditsUsed = await _getDailyCreditsUsed();
      final topPosts = await getTopPerformingPosts('today');
      final engagementGraph = await getEngagementGraph('today');

      // FIX: These .count properties are now correct because the queries were fixed
      return DashboardMetrics(
        totalUsers: totalUsersResponse.count,
        totalMembers: totalMembersResponse.count,
        totalNonMembers: totalNonMembersResponse.count,
        totalBCreators: totalBCreatorsResponse.count,
        totalPosts: totalPostsResponse.count,
        scrapedPosts: scrapedPostsResponse.count,
        uploadedPosts: uploadedPostsResponse.count,
        dailyCreditsUsed: dailyCreditsUsed,
        topPerformingPosts: topPosts,
        engagementGraph: engagementGraph,
      );
    } catch (e) {
      debugPrint('Error fetching dashboard metrics: $e');
      rethrow;
    }
  }

  Future<int> _getDailyCreditsUsed() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final response = await _supabase
          .from('user_unlocked_items')
          .select('id') // FIX: Changed from '*' to 'id'
          .gte('unlocked_at', startOfDay.toIso8601String())
          .count(CountOption.exact); // FIX: Moved count() here

      return response.count;
    } catch (e) {
      debugPrint('Error getting daily credits: $e');
      return 0;
    }
  }

  Future<List<TopPost>> getTopPerformingPosts(String period) async {
    try {
      final endDate = DateTime.now();
      final startDate = _getStartDateFromPeriod(period, endDate);

      final response = await _supabase
          .from('analytics_daily')
          .select('asset_id, assets(title, category, source), views, quotes_requested, saves, shares, date')
          .gte('date', startDate.toIso8601String())
          .lte('date', endDate.toIso8601String())
          .order('views', ascending: false)
          .limit(10);
      
      final responseList = response is List ? response : [];

      if (responseList.isEmpty) return []; // No need for null check, Supabase returns List

      return responseList.map((data) {
            final assets = data['assets'] as Map<String, dynamic>?;
            return TopPost(
              id: data['asset_id'] as String,
              title: assets?['title'] ?? 'Unknown',
              category: assets?['category'] ?? 'Other',
              views: (data['views'] as num?)?.toInt() ?? 0,
              unlocks: (data['quotes_requested'] as num?)?.toInt() ?? 0,
              saves: (data['saves'] as num?)?.toInt() ?? 0,
              shares: (data['shares'] as num?)?.toInt() ?? 0,
              createdAt: DateTime.parse(data['date']),
              source: assets?['source'] ?? 'unknown',
            );
          }).toList();
    } catch (e) {
      debugPrint('Error fetching top performing posts: $e');
      return [];
    }
  }

  Future<EngagementData> getEngagementGraph(String period) async {
    try {
      final endDate = DateTime.now();
      final startDate = _getStartDateFromPeriod(period, endDate);

      final response = await _supabase
          .from('analytics_daily')
          .select('date, views, saves, shares, quotes_requested')
          .gte('date', startDate.toIso8601String())
          .lte('date', endDate.toIso8601String())
          .order('date');

      final data = response is List ? response : [];
      
      if (data.isEmpty) { // No need for null check
        return EngagementData(views: [], unlocks: [], saves: [], shares: []);
      }

      final views = data.map((item) => TimeSeriesPoint(
            date: DateTime.parse(item['date']),
            value: (item['views'] as num?)?.toInt() ?? 0,
          )).toList();

      final unlocks = data.map((item) => TimeSeriesPoint(
            date: DateTime.parse(item['date']),
            value: (item['quotes_requested'] as num?)?.toInt() ?? 0,
          )).toList();

      final saves = data.map((item) => TimeSeriesPoint(
            date: DateTime.parse(item['date']),
            value: (item['saves'] as num?)?.toInt() ?? 0,
          )).toList();

      final shares = data.map((item) => TimeSeriesPoint(
            date: DateTime.parse(item['date']),
            value: (item['shares'] as num?)?.toInt() ?? 0,
          )).toList();

      return EngagementData(views: views, unlocks: unlocks, saves: saves, shares: shares);
    } catch (e) {
      debugPrint('Error fetching engagement graph: $e');
      return EngagementData(views: [], unlocks: [], saves: [], shares: []);
    }
  }

  DateTime _getStartDateFromPeriod(String period, DateTime endDate) {
    switch (period) {
      case 'today':
        return DateTime(endDate.year, endDate.month, endDate.day);
      case 'week':
        return endDate.subtract(const Duration(days: 7));
      case 'month':
        return endDate.subtract(const Duration(days: 30));
      default:
        return endDate.subtract(const Duration(days: 30));
    }
  }

  // ===== USERS MANAGEMENT =====
  Future<List<EnhancedUser>> getEnhancedUsersList({
    required String userType,
    required old_models.FilterState filterState,
  }) async {
    try {
      var query = _supabase.from('users').select('*');

      switch (userType) {
        case 'Members':
          query = query.eq('is_member', true);
          break;
        case 'Non-Members':
          query = query.eq('is_member', false).neq('role', 'designer');
          break;
        case 'B2B Creators':
          query = query.eq('role', 'designer');
          break;
      }

      final range = filterState.dateRange;
      if (range != null) {
        final endOfDay = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
        query = query
            .gte('created_at', range.start.toIso8601String())
            .lte('created_at', endOfDay.toIso8601String());
      }

      if (filterState.status != 'All Status') {
        bool statusValue = (filterState.status == 'Approved');
        query = query.eq('is_approved', statusValue);
      }

      final response = await query.order('created_at', ascending: false);
      
      final responseList = response is List ? response : [];

      if (responseList.isEmpty) return [];

      return responseList.map((map) => _mapEnhancedUserFromDatabase(map)).toList();
    } catch (e) {
      debugPrint('Error fetching enhanced users: $e');
      return [];
    }
  }

  EnhancedUser _mapEnhancedUserFromDatabase(Map<String, dynamic> map) {
    return EnhancedUser(
      id: map['id'],
      email: map['email'],
      username: map['username'] ?? map['full_name'],
      fullName: map['full_name'],
      role: map['role'] ?? 'member',
      status: map['approval_status'] ?? 'pending',
      isMember: map['is_member'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
      membershipExpiry: null, // Would need membership_expiry field
      creditsRemaining: (map['credits_remaining'] as num?)?.toInt() ?? 0,
      referralCode: map['referral_code'],
      referredBy: map['referred_by'],
      signupSource: 'Organic', // Would need signup_source field
      referralCount: 0, // Would need referral count calculation
      creditHistory: [],
    );
  }

  // ===== CONTENT MANAGEMENT =====
  Future<List<ScrapedContent>> getScrapedContentList() async {
    try {
      final response = await _supabase
          .from('assets')
          .select('id, title, category, source, status, created_at')
          .eq('source', 'scraped')
          .order('created_at', ascending: false);

      final responseList = response is List ? response : [];
      
      if (responseList.isEmpty) return [];

      return responseList.map((item) => ScrapedContent(
            id: item['id'] as String,
            title: item['title'] as String? ?? 'Unknown',
            category: item['category'] as String? ?? 'Other',
            source: item['source'] as String? ?? 'Unknown',
            status: item['status'] as String? ?? 'pending',
            createdAt: DateTime.parse(item['created_at'] as String),
            views: 0, // Would need join with analytics
            engagement: 0, // Would need calculation
            scrapeUrl: item['scraped_url'] as String?,
          )).toList();
    } catch (e) {
      debugPrint('Error fetching scraped content: $e');
      return [];
    }
  }

  Future<List<B2BCreatorUpload>> getB2BCreatorUploadsList() async {
    try {
      final response = await _supabase
          .from('assets')
          .select('''
            id, title, status, created_at, source,
            users!assets_owner_id_fkey(business_name, full_name)
          ''')
          .eq('source', 'b2b_upload')
          .order('created_at', ascending: false);

      final responseList = response is List ? response : [];
      
      if (responseList.isEmpty) return [];

      return responseList.map((item) {
            final users = item['users'] as Map<String, dynamic>?;
            final businessName = users != null ? users['business_name'] as String? : null;
            final fullName = users != null ? users['full_name'] as String? : null;
            return B2BCreatorUpload(
              id: item['id'] as String,
              creatorId: '', // Would need to be added to query
              creatorName: businessName ?? fullName ?? 'Unknown',
              title: item['title'] as String? ?? 'Unknown',
              status: item['status'] as String? ?? 'pending',
              uploadedAt: DateTime.parse(item['created_at'] as String),
              views: 0, // Would need analytics join
              unlocks: 0, // Would need analytics join
              format: item['file_format'] as String? ?? 'image',
              isFeatured: item['is_featured'] as bool? ?? false,
            );
          }).toList();
    } catch (e) {
      debugPrint('Error fetching B2B creator uploads: $e');
      return [];
    }
  }

  // ===== ANALYTICS & INSIGHTS =====
  Future<List<PostAnalytics>> getPostAnalytics(old_models.FilterState filterState) async {
    try {
      final dateRange = filterState.dateRange;
      final startDate = dateRange != null
          ? dateRange.start.toIso8601String()
          : DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final endDate = dateRange != null
          ? dateRange.end.toIso8601String()
          : DateTime.now().toIso8601String();

      final response = await _supabase
          .from('assets')
          .select('''
            id, title, category, source, status, created_at,
            users!assets_owner_id_fkey(username, business_name)
          ''')
          .gte('created_at', startDate)
          .lte('created_at', endDate);

      final responseList = response is List ? response : [];
      
      if (responseList.isEmpty) return [];

      return responseList.map((asset) {
        final users = asset['users'] as Map<String, dynamic>?;
        final businessName = users != null ? users['business_name'] as String? : null;
        final username = users != null ? users['username'] as String? : null;
        return PostAnalytics(
          id: asset['id'] as String,
          title: asset['title'] as String? ?? 'Unknown',
          category: asset['category'] as String? ?? 'Other',
          source: asset['source'] as String? ?? 'unknown',
          creator: businessName ?? username ?? 'Unknown',
          views: 0, // Would need analytics join
          unlocks: 0, // Would need analytics join
          saves: 0, // Would need analytics join
          shares: 0, // Would need analytics join
          ctr: 0.0, // Would need calculation
          createdAt: DateTime.parse(asset['created_at'] as String),
          topRegions: [], // Would need geo analytics
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching post analytics: $e');
      return [];
    }
  }

  // ===== B2B CREATOR ANALYTICS =====
  Future<CreatorAnalytics> getCreatorAnalytics(String creatorId) async {
    try {
      final creatorResponse = await _supabase
          .from('users')
          .select('business_name, full_name')
          .eq('id', creatorId)
          .single();

      final assetsResponse = await _supabase
          .from('assets')
          .select('id, title, created_at')
          .eq('owner_id', creatorId);

      final assetsList = assetsResponse is List ? assetsResponse : [];

      final businessName = creatorResponse['business_name'] as String?;
      final fullName = creatorResponse['full_name'] as String?;
      
      return CreatorAnalytics(
        creatorId: creatorId,
        creatorName: businessName ?? fullName ?? 'Unknown',
        totalWorksUploaded: assetsList.length, // FIX: Access .length directly
        topWorks: [], // Would need analytics
        totalUnlocksByMembers: 0, // Would need analytics
        totalSaves: 0, // Would need analytics
        contactClicks: 0, // Would need tracking
        trend: PerformanceTrend(
          last30Days: [], // Would need 30-day trend data
          trendDirection: 0.0,
        ),
        audienceBreakdown: {},
        topRegions: [], // Would need geo analytics
      );
    } catch (e) {
      debugPrint('Error fetching creator analytics: $e');
      return CreatorAnalytics(
        creatorId: creatorId,
        creatorName: 'Unknown',
        totalWorksUploaded: 0,
        topWorks: [],
        totalUnlocksByMembers: 0,
        totalSaves: 0,
        contactClicks: 0,
        trend: PerformanceTrend(last30Days: [], trendDirection: 0.0),
        audienceBreakdown: {},
      );
    }
  }

  // ===== MONETIZATION & MEMBERSHIP =====
  Future<MembershipAnalytics> getMembershipAnalytics() async {
    try {
      final activeMembersResponse = await _supabase
          .from('users')
          .select('id') // FIX: Changed from '*' to 'id'
          .eq('is_member', true)
          .count(CountOption.exact); // FIX: Moved count() here

      final activeMembers = activeMembersResponse.count;

      return MembershipAnalytics(
        activeSubscriptions: activeMembers,
        expiredSubscriptions: 0, // Would need expiry tracking
        growthRate: 0.0, // Would need calculation
        totalRevenue: 0.0, // Would need payment integration
        subscriptionBreakdown: {
          'monthly': activeMembers, // All monthly assumption
          'yearly': 0,
        },
        conversionFunnel: ConversionFunnel(
          visitorToSignupRate: 0.0,
          signupToMemberRate: 0.0,
          memberRetentionRate: 0.0,
        ),
      );
    } catch (e) {
      debugPrint('Error fetching membership analytics: $e');
      return MembershipAnalytics(
        activeSubscriptions: 0,
        expiredSubscriptions: 0,
        growthRate: 0.0,
        totalRevenue: 0.0,
        subscriptionBreakdown: {},
        conversionFunnel: ConversionFunnel(
          visitorToSignupRate: 0.0,
          signupToMemberRate: 0.0,
          memberRetentionRate: 0.0,
        ),
      );
    }
  }

  // ===== REFERRAL ANALYTICS =====
  Future<ReferralAnalytics> getReferralAnalytics() async {
    try {
      final totalReferralsResponse = await _supabase
          .from('referrals')
          .select('id') // FIX: Changed from '*' to 'id'
          .count(CountOption.exact); // FIX: Moved count() here

      return ReferralAnalytics(
        totalReferrals: totalReferralsResponse.count,
        topReferrers: [], // Would need detailed query
        conversionRate: 0.0, // Would need calculation
        creditsRewarded: 0, // Would need calculation
        referralSourcePerformance: {
          'organic': 60,
          'social': 25,
          'referral': 15,
        },
      );
    } catch (e) {
      debugPrint('Error fetching referral analytics: $e');
      return ReferralAnalytics(
        totalReferrals: 0,
        topReferrers: [],
        conversionRate: 0.0,
        creditsRewarded: 0,
        referralSourcePerformance: {},
      );
    }
  }

  // ===== SYSTEM SETTINGS =====
  Future<SystemSettings> getSystemSettings() async {
    try {
      final response = await _supabase
          .from('settings')
          .select('key, value');

      final responseList = response is List ? response : [];
      
      if (responseList.isEmpty) {
        return _getDefaultSettings();
      }

      final settingsMap = {for (var item in responseList) item['key']: item['value']};

      return SystemSettings(
        creditSettings: CreditSettings(
          dailyCreditReset: int.tryParse(settingsMap['daily_credit_reset']?.toString() ?? '10') ?? 10,
          signupBonus: int.tryParse(settingsMap['signup_bonus']?.toString() ?? '20') ?? 20,
          referralBonus: int.tryParse(settingsMap['referral_bonus']?.toString() ?? '50') ?? 50,
          resetTime: settingsMap['credit_reset_time']?.toString() ?? '00:00',
        ),
        roleSettings: UserRoleSettings(
          adminRoles: ['admin'],
          moderatorRoles: ['moderator'],
          creatorRoles: ['designer'],
          memberRoles: ['member'],
          freeUserRoles: ['free'],
        ),
        scraperSettings: ScraperSettings(
          enabledSources: (settingsMap['enabled_scraper_sources'] ?? '').split(',').where((s) => s.isNotEmpty).toList(),
          scrapingFrequency: settingsMap['scraping_frequency'] ?? 'daily',
          captureFields: (settingsMap['scraper_capture_fields'] ?? '').split(',').where((s) => s.isNotEmpty).toList(),
        ),
        aiSettings: AISettings(
          searchThreshold: double.tryParse(settingsMap['ai_search_threshold']?.toString() ?? '0.7') ?? 0.7,
          maxResults: int.tryParse(settingsMap['ai_max_results']?.toString() ?? '50') ?? 50,
          enableAutoTagging: settingsMap['ai_auto_tagging']?.toString().toLowerCase() == 'true',
        ),
      );
    } catch (e) {
      debugPrint('Error fetching system settings: $e');
      return _getDefaultSettings();
    }
  }

  SystemSettings _getDefaultSettings() {
    return SystemSettings(
      creditSettings: CreditSettings(dailyCreditReset: 10, signupBonus: 20, referralBonus: 50, resetTime: '00:00'),
      roleSettings: UserRoleSettings(adminRoles: [], moderatorRoles: [], creatorRoles: [], memberRoles: [], freeUserRoles: []),
      scraperSettings: ScraperSettings(enabledSources: [], scrapingFrequency: 'daily', captureFields: []),
      aiSettings: AISettings(searchThreshold: 0.7, maxResults: 50, enableAutoTagging: false),
    );
  }

  Future<void> updateSystemSettings(SystemSettings settings) async {
    try {
      await _supabase.from('settings').upsert([
        {'key': 'daily_credit_reset', 'value': settings.creditSettings.dailyCreditReset.toString()},
        {'key': 'signup_bonus', 'value': settings.creditSettings.signupBonus.toString()},
        {'key': 'referral_bonus', 'value': settings.creditSettings.referralBonus.toString()},
        {'key': 'credit_reset_time', 'value': settings.creditSettings.resetTime},
        {'key': 'ai_search_threshold', 'value': settings.aiSettings.searchThreshold.toString()},
        {'key': 'ai_max_results', 'value': settings.aiSettings.maxResults.toString()},
        {'key': 'ai_auto_tagging', 'value': settings.aiSettings.enableAutoTagging.toString()},
        {'key': 'enabled_scraper_sources', 'value': settings.scraperSettings.enabledSources.join(',')},
        {'key': 'scraping_frequency', 'value': settings.scraperSettings.scrapingFrequency},
        {'key': 'scraper_capture_fields', 'value': settings.scraperSettings.captureFields.join(',')},
      ]);
    } catch (e) {
      debugPrint('Error updating system settings: $e');
      rethrow;
    }
  }

  // ===== QUICK INSIGHTS =====
  Future<QuickInsights> getQuickInsights(String postId) async {
    try {
      final response = await _supabase
          .from('analytics_daily')
          .select('date, views, quotes_requested, saves, shares, region_counts')
          .eq('asset_id', postId)
          .gte('date', DateTime.now().subtract(const Duration(days: 7)).toIso8601String());

      final responseList = response is List ? response : [];
      
      if (responseList.isEmpty) {
        return QuickInsights(
          postId: postId,
          uniqueViews: 0,
          repeatViews: 0,
          unlocks: 0,
          saves: 0,
          shares: 0,
          last7DaysPerformance: [],
          engagementTrend: 0.0,
        );
      }

      int totalViews = 0;
      int totalUnlocks = 0;
      int totalSaves = 0;
      int totalShares = 0;
      final performanceData = <TimeSeriesPoint>[];

      for (var analytic in responseList) {
        final views = (analytic['views'] as num?)?.toInt() ?? 0;
        final unlocks = (analytic['quotes_requested'] as num?)?.toInt() ?? 0;
        final saves = (analytic['saves'] as num?)?.toInt() ?? 0;
        final shares = (analytic['shares'] as num?)?.toInt() ?? 0;

        totalViews += views;
        totalUnlocks += unlocks;
        totalSaves += saves;
        totalShares += shares;

        performanceData.add(TimeSeriesPoint(
          date: DateTime.parse(analytic['date'] as String),
          value: (views + unlocks + saves + shares).toInt(),
        ));
      }

      return QuickInsights(
        postId: postId,
        uniqueViews: totalViews,
        repeatViews: (totalViews * 0.3).round(), // Estimate
        unlocks: totalUnlocks,
        saves: totalSaves,
        shares: totalShares,
        topRegions: [], // Would need geo analytics
        last7DaysPerformance: performanceData,
        engagementTrend: performanceData.isNotEmpty ? 1.0 : 0.0, // Would need trend calculation
      );
    } catch (e) {
      debugPrint('Error fetching quick insights: $e');
      return QuickInsights(
        postId: postId,
        uniqueViews: 0,
        repeatViews: 0,
        unlocks: 0,
        saves: 0,
        shares: 0,
        last7DaysPerformance: [],
        engagementTrend: 0.0,
      );
    }
  }

  // ===== UTILITY METHODS =====
  Stream<Map<String, dynamic>> getDashboardMetricsStream() {
    return _createPollingStream(() async {
      final metrics = await fetchDashboardMetrics();
      return {
        'totalUsers': metrics.totalUsers,
        'totalMembers': metrics.totalMembers,
        'totalPosts': metrics.totalPosts,
        'dailyCreditsUsed': metrics.dailyCreditsUsed,
      };
    });
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

  void dispose() {
    _supabase.removeChannel(_channel);
    _controller.close();
  }
}