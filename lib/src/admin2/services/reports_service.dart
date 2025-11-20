// Reports Service with Supabase Integration
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reports_models.dart';

class ReportsService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Fetch Report Overview Data
  static Future<ReportOverview> fetchReportOverview() async {
    try {
      final cacheKey = 'report_overview';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as ReportOverview;
      }

      // For now, using mock data since we don't have a reports table
      // In a real implementation, this would query a reports table
      final overview = ReportOverview(
        totalReportsGenerated: 1250,
        downloadsThisMonth: 340,
        averageFileSize: 2.5,
      );

      _cacheResult(cacheKey, overview);
      return overview;
    } catch (e) {
      debugPrint('Error fetching report overview: $e');
      return ReportOverview(
        totalReportsGenerated: 0,
        downloadsThisMonth: 0,
        averageFileSize: 0.0,
      );
    }
  }

  /// Fetch Platform Report Summary
  static Future<PlatformReportSummary> fetchPlatformReportSummary() async {
    try {
      final cacheKey = 'platform_report_summary';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as PlatformReportSummary;
      }

      // Calculate total sales from quote_requests (simplified)
      final quotesResponse = await _supabase.from('quote_requests').select('id');
      final totalQuotes = quotesResponse.length;

      // Calculate active users (users with credits > 0)
      final activeUsersResponse = await _supabase
          .from('users')
          .select('id')
          .gt('credits_remaining', 0);

      final summary = PlatformReportSummary(
        totalSales: totalQuotes * 500.0, // Mock calculation
        activeUsers: activeUsersResponse.length,
      );

      _cacheResult(cacheKey, summary);
      return summary;
    } catch (e) {
      debugPrint('Error fetching platform report summary: $e');
      return PlatformReportSummary(totalSales: 0.0, activeUsers: 0);
    }
  }

  /// Fetch Platform Growth Data (6 months)
  static Future<List<PlatformGrowthData>> fetchPlatformGrowthData() async {
    try {
      final cacheKey = 'platform_growth_data';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<PlatformGrowthData>;
      }

      final now = DateTime.now();
      List<PlatformGrowthData> growthData = [];

      // Generate last 6 months data
      for (int i = 5; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final startDate = date;
        final endDate = DateTime(date.year, date.month + 1, 0);

        // Count users created in this month
        final usersResponse = await _supabase
            .from('users')
            .select('id')
            .gte('created_at', startDate.toIso8601String())
            .lte('created_at', endDate.toIso8601String());

        // Count assets created in this month
        final assetsResponse = await _supabase
            .from('assets')
            .select('id')
            .gte('created_at', startDate.toIso8601String())
            .lte('created_at', endDate.toIso8601String());

        growthData.add(PlatformGrowthData(
          date: date,
          users: usersResponse.length,
          posts: assetsResponse.length,
        ));
      }

      _cacheResult(cacheKey, growthData);
      return growthData;
    } catch (e) {
      debugPrint('Error fetching platform growth data: $e');
      return [];
    }
  }

  /// Fetch Platform Performance Metrics (6 months)
  static Future<List<PlatformPerformanceMetric>> fetchPlatformPerformanceMetrics() async {
    try {
      final cacheKey = 'platform_performance_metrics';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<PlatformPerformanceMetric>;
      }

      final now = DateTime.now();
      List<PlatformPerformanceMetric> metrics = [];

      for (int i = 5; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final startDate = date;
        final endDate = DateTime(date.year, date.month + 1, 0);

        // Users up to this month
        final usersResponse = await _supabase
            .from('users')
            .select('id')
            .lte('created_at', endDate.toIso8601String());

        // Posts created this month
        final postsResponse = await _supabase
            .from('assets')
            .select('id')
            .gte('created_at', startDate.toIso8601String())
            .lte('created_at', endDate.toIso8601String());

        // Calculate engagement score (simplified)
        final totalViews = await _calculateTotalViews(startDate, endDate);
        final engagementScore = usersResponse.isNotEmpty
            ? (totalViews / usersResponse.length) * 10
            : 0.0;

        // Growth rate (compared to previous month)
        final prevMonth = DateTime(date.year, date.month - 1, 1);
        final prevUsersResponse = await _supabase
            .from('users')
            .select('id')
            .lte('created_at', prevMonth.toIso8601String());
        final growthRate = prevUsersResponse.isNotEmpty
            ? ((usersResponse.length - prevUsersResponse.length) / prevUsersResponse.length) * 100
            : 0.0;

        metrics.add(PlatformPerformanceMetric(
          month: '${date.year}-${date.month.toString().padLeft(2, '0')}',
          totalUsers: usersResponse.length,
          postsCreated: postsResponse.length,
          engagementScore: engagementScore.clamp(0, 100),
          growthRate: growthRate,
        ));
      }

      _cacheResult(cacheKey, metrics);
      return metrics;
    } catch (e) {
      debugPrint('Error fetching platform performance metrics: $e');
      return [];
    }
  }

  /// Fetch User Growth Data (6 months)
  static Future<List<UserGrowthData>> fetchUserGrowthData() async {
    try {
      final cacheKey = 'user_growth_data';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<UserGrowthData>;
      }

      final now = DateTime.now();
      List<UserGrowthData> growthData = [];

      for (int i = 5; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final startDate = date;
        final endDate = DateTime(date.year, date.month + 1, 0);

        // New users this month
        final newUsersResponse = await _supabase
            .from('users')
            .select('id')
            .gte('created_at', startDate.toIso8601String())
            .lte('created_at', endDate.toIso8601String());

        // Active users (users with activity this month)
        final activeUsersResponse = await _supabase
            .from('views')
            .select('user_id')
            .gte('created_at', startDate.toIso8601String())
            .lte('created_at', endDate.toIso8601String());

        final uniqueActiveUsers = activeUsersResponse
            .map((v) => v['user_id'])
            .where((id) => id != null)
            .toSet()
            .length;

        // Churn rate (simplified calculation)
        final prevMonthActive = i < 5 ? growthData.last.activeUsers : uniqueActiveUsers;
        final churnRate = prevMonthActive > 0
            ? ((prevMonthActive - uniqueActiveUsers) / prevMonthActive) * 100
            : 0.0;

        growthData.add(UserGrowthData(
          date: date,
          newUsers: newUsersResponse.length,
          activeUsers: uniqueActiveUsers,
          churnRate: churnRate.clamp(-100, 100),
        ));
      }

      _cacheResult(cacheKey, growthData);
      return growthData;
    } catch (e) {
      debugPrint('Error fetching user growth data: $e');
      return [];
    }
  }

  /// Fetch Available User Reports
  static Future<List<AvailableUserReport>> fetchAvailableUserReports() async {
    try {
      final cacheKey = 'available_user_reports';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<AvailableUserReport>;
      }

      // Mock data for available reports
      final reports = [
        AvailableUserReport(
          name: 'Monthly User Activity',
          type: 'Activity',
          generatedDate: DateTime.now().subtract(const Duration(days: 1)),
          downloadCount: 45,
          fileSize: 1.2,
          format: 'PDF',
        ),
        AvailableUserReport(
          name: 'Member Demographics',
          type: 'Demographics',
          generatedDate: DateTime.now().subtract(const Duration(days: 3)),
          downloadCount: 32,
          fileSize: 0.8,
          format: 'Excel',
        ),
        AvailableUserReport(
          name: 'User Referral Stats',
          type: 'Referrals',
          generatedDate: DateTime.now().subtract(const Duration(days: 7)),
          downloadCount: 28,
          fileSize: 1.5,
          format: 'PDF',
        ),
        AvailableUserReport(
          name: 'User Subscription Trends',
          type: 'Subscriptions',
          generatedDate: DateTime.now().subtract(const Duration(days: 14)),
          downloadCount: 19,
          fileSize: 2.1,
          format: 'Excel',
        ),
      ];

      _cacheResult(cacheKey, reports);
      return reports;
    } catch (e) {
      debugPrint('Error fetching available user reports: $e');
      return [];
    }
  }

  /// Fetch Content Reports
  static Future<List<ContentReport>> fetchContentReports() async {
    try {
      final cacheKey = 'content_reports';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<ContentReport>;
      }

      // Mock data for content reports
      final reports = [
        ContentReport(
          name: 'Top Performing Posts',
          type: 'Performance',
          generatedDate: DateTime.now().subtract(const Duration(days: 2)),
          downloadCount: 67,
          fileSize: 3.2,
          format: 'PDF',
        ),
        ContentReport(
          name: 'Content Engagement Metrics',
          type: 'Engagement',
          generatedDate: DateTime.now().subtract(const Duration(days: 5)),
          downloadCount: 41,
          fileSize: 1.8,
          format: 'Excel',
        ),
        ContentReport(
          name: 'B2B Creator Portfolio Stats',
          type: 'B2B',
          generatedDate: DateTime.now().subtract(const Duration(days: 10)),
          downloadCount: 23,
          fileSize: 4.1,
          format: 'PDF',
        ),
        ContentReport(
          name: 'Content Moderation Report',
          type: 'Moderation',
          generatedDate: DateTime.now().subtract(const Duration(days: 15)),
          downloadCount: 18,
          fileSize: 2.7,
          format: 'Excel',
        ),
      ];

      _cacheResult(cacheKey, reports);
      return reports;
    } catch (e) {
      debugPrint('Error fetching content reports: $e');
      return [];
    }
  }

  /// Generate Custom Report
  static Future<bool> generateCustomReport(CustomReportConfig config) async {
    try {
      // In a real implementation, this would generate and store the report
      // For now, we'll simulate the generation process
      await Future.delayed(const Duration(seconds: 2));

      // Log the report generation
      await _supabase.from('generated_reports').insert({
        'report_type': config.reportType,
        'start_date': config.startDate.toIso8601String(),
        'end_date': config.endDate.toIso8601String(),
        'metrics': config.metrics,
        'format': config.format,
        'generated_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('Error generating custom report: $e');
      return false;
    }
  }

  /// Helper method to calculate total views for a date range
  static Future<int> _calculateTotalViews(DateTime startDate, DateTime endDate) async {
    try {
      final response = await _supabase
          .from('analytics_daily')
          .select('views')
          .gte('date', startDate.toIso8601String().split('T')[0])
          .lte('date', endDate.toIso8601String().split('T')[0]);

      return response.fold<int>(0, (sum, item) => sum + (item['views'] as int? ?? 0));
    } catch (e) {
      debugPrint('Error calculating total views: $e');
      return 0;
    }
  }

  static bool _isCacheValid(String key) {
    if (!_cache.containsKey(key) || !_cacheTimestamp.containsKey(key)) return false;
    final timestamp = _cacheTimestamp[key]!;
    return DateTime.now().difference(timestamp).inMilliseconds < _cacheTimeout.inMilliseconds;
  }

  static void _cacheResult(String key, dynamic value) {
    _cache[key] = value;
    _cacheTimestamp[key] = DateTime.now();
  }

  /// Export Platform Growth Data
  static Future<String> exportPlatformGrowthData(List<PlatformGrowthData> data, String format) async {
    try {
      // In a real implementation, this would generate and return a file URL or path
      // For now, we'll simulate the export process
      await Future.delayed(const Duration(seconds: 1));

      // Mock export URL
      return 'https://example.com/exports/platform_growth_${DateTime.now().millisecondsSinceEpoch}.$format';
    } catch (e) {
      debugPrint('Error exporting platform growth data: $e');
      throw Exception('Failed to export platform growth data');
    }
  }

  /// Export User Growth Data
  static Future<String> exportUserGrowthData(List<UserGrowthData> data, String format) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return 'https://example.com/exports/user_growth_${DateTime.now().millisecondsSinceEpoch}.$format';
    } catch (e) {
      debugPrint('Error exporting user growth data: $e');
      throw Exception('Failed to export user growth data');
    }
  }

  /// Export Platform Performance Metrics
  static Future<String> exportPlatformPerformanceMetrics(List<PlatformPerformanceMetric> data, String format) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return 'https://example.com/exports/platform_metrics_${DateTime.now().millisecondsSinceEpoch}.$format';
    } catch (e) {
      debugPrint('Error exporting platform performance metrics: $e');
      throw Exception('Failed to export platform performance metrics');
    }
  }

  /// Export Available User Reports
  static Future<String> exportAvailableUserReports(List<AvailableUserReport> data, String format) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return 'https://example.com/exports/user_reports_${DateTime.now().millisecondsSinceEpoch}.$format';
    } catch (e) {
      debugPrint('Error exporting available user reports: $e');
      throw Exception('Failed to export available user reports');
    }
  }

  /// Export Content Reports
  static Future<String> exportContentReports(List<ContentReport> data, String format) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return 'https://example.com/exports/content_reports_${DateTime.now().millisecondsSinceEpoch}.$format';
    } catch (e) {
      debugPrint('Error exporting content reports: $e');
      throw Exception('Failed to export content reports');
    }
  }

  static void clearCache() {
    _cache.clear();
    _cacheTimestamp.clear();
  }

  static void clearCacheKey(String key) {
    _cache.remove(key);
    _cacheTimestamp.remove(key);
  }
}