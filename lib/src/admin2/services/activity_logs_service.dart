import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_logs_models.dart';

class ActivityLogsService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Fetch Activity Summary
  static Future<ActivitySummary> fetchActivitySummary() async {
    try {
      final cacheKey = 'activity_summary';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as ActivitySummary;
      }

      // Calculate from existing tables
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Admin actions: count notifications as admin actions
      final adminActionsResponse = await _supabase.from('notifications').select('id');
      final adminActionsTodayResponse = await _supabase
          .from('notifications')
          .select('id')
          .gte('created_at', today.toIso8601String());

      // User activities: count views + likes + shares + quote_requests
      final viewsResponse = await _supabase.from('views').select('id');
      final likesResponse = await _supabase.from('likes').select('id');
      final sharesResponse = await _supabase.from('shares').select('id');
      final quotesResponse = await _supabase.from('quote_requests').select('id');

      final userActivities = viewsResponse.length + likesResponse.length +
          sharesResponse.length + quotesResponse.length;

      final viewsTodayResponse = await _supabase
          .from('views')
          .select('id')
          .gte('created_at', today.toIso8601String());
      final likesTodayResponse = await _supabase
          .from('likes')
          .select('id')
          .gte('created_at', today.toIso8601String());
      final sharesTodayResponse = await _supabase
          .from('shares')
          .select('id')
          .gte('created_at', today.toIso8601String());
      final quotesTodayResponse = await _supabase
          .from('quote_requests')
          .select('id')
          .gte('created_at', today.toIso8601String());

      final userActivitiesToday = viewsTodayResponse.length + likesTodayResponse.length +
          sharesTodayResponse.length + quotesTodayResponse.length;

      // Exports: for now, assume 0 since no export table
      const exportsGenerated = 0;
      const exportsToday = 0;

      // System health: hardcoded
      const systemHealth = 98.7;

      final summary = ActivitySummary(
        adminActions: adminActionsResponse.length,
        userActivities: userActivities,
        exportsGenerated: exportsGenerated,
        systemHealth: systemHealth,
        adminActionsToday: adminActionsTodayResponse.length,
        userActivitiesToday: userActivitiesToday,
        exportsToday: exportsToday,
      );

      _cacheResult(cacheKey, summary);
      return summary;
    } catch (e) {
      debugPrint('Error fetching activity summary: $e');
      return ActivitySummary(
        adminActions: 0,
        userActivities: 0,
        exportsGenerated: 0,
        systemHealth: 98.7,
        adminActionsToday: 0,
        userActivitiesToday: 0,
        exportsToday: 0,
      );
    }
  }

  /// Fetch Admin Logs
  static Future<List<ActivityLog>> fetchAdminLogs({
    String? searchTerm,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      final cacheKey = 'admin_logs_${searchTerm}_${category}_${startDate}_${endDate}_$limit';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<ActivityLog>;
      }

      final response = await _supabase
          .from('activity_logs')
          .select('*')
          .eq('log_type', 'admin')
          .order('timestamp', ascending: false)
          .limit(limit);

      List<ActivityLog> logs = response.map((json) => ActivityLog.fromJson(json)).toList();

      // Filter in code
      if (searchTerm != null && searchTerm.isNotEmpty) {
        logs = logs.where((log) =>
            (log.details?.toLowerCase().contains(searchTerm.toLowerCase()) ?? false) ||
            (log.actionType?.toLowerCase().contains(searchTerm.toLowerCase()) ?? false)).toList();
      }

      if (category != null && category != 'All Actions') {
        logs = logs.where((log) => log.category == category.toLowerCase()).toList();
      }

      if (startDate != null) {
        logs = logs.where((log) => log.timestamp.isAfter(startDate)).toList();
      }

      if (endDate != null) {
        logs = logs.where((log) => log.timestamp.isBefore(endDate)).toList();
      }

      _cacheResult(cacheKey, logs);
      return logs;
    } catch (e) {
      debugPrint('Error fetching admin logs: $e');
      return [];
    }
  }

  /// Fetch User Activity Logs
  static Future<List<ActivityLog>> fetchUserActivityLogs({
    String? searchTerm,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      final cacheKey = 'user_logs_${searchTerm}_${category}_${startDate}_${endDate}_$limit';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<ActivityLog>;
      }

      final response = await _supabase
          .from('activity_logs')
          .select('*')
          .eq('log_type', 'user')
          .order('timestamp', ascending: false)
          .limit(limit);

      List<ActivityLog> logs = response.map((json) => ActivityLog.fromJson(json)).toList();

      // Filter in code
      if (searchTerm != null && searchTerm.isNotEmpty) {
        logs = logs.where((log) =>
            (log.details?.toLowerCase().contains(searchTerm.toLowerCase()) ?? false) ||
            (log.actionType?.toLowerCase().contains(searchTerm.toLowerCase()) ?? false)).toList();
      }

      if (category != null && category != 'All Actions') {
        logs = logs.where((log) => log.category == category.toLowerCase()).toList();
      }

      if (startDate != null) {
        logs = logs.where((log) => log.timestamp.isAfter(startDate)).toList();
      }

      if (endDate != null) {
        logs = logs.where((log) => log.timestamp.isBefore(endDate)).toList();
      }

      _cacheResult(cacheKey, logs);
      return logs;
    } catch (e) {
      debugPrint('Error fetching user activity logs: $e');
      return [];
    }
  }

  /// Fetch Export Logs
  static Future<List<ActivityLog>> fetchExportLogs({
    String? format,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      final cacheKey = 'export_logs_${format}_${startDate}_${endDate}_$limit';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as List<ActivityLog>;
      }

      final response = await _supabase
          .from('activity_logs')
          .select('*')
          .eq('log_type', 'export')
          .order('timestamp', ascending: false)
          .limit(limit);

      List<ActivityLog> logs = response.map((json) => ActivityLog.fromJson(json)).toList();

      // Filter in code
      if (format != null && format != 'All Exports') {
        logs = logs.where((log) => log.format == format.toLowerCase()).toList();
      }

      if (startDate != null) {
        logs = logs.where((log) => log.timestamp.isAfter(startDate)).toList();
      }

      if (endDate != null) {
        logs = logs.where((log) => log.timestamp.isBefore(endDate)).toList();
      }

      _cacheResult(cacheKey, logs);
      return logs;
    } catch (e) {
      debugPrint('Error fetching export logs: $e');
      return [];
    }
  }

  /// Log Admin Action
  static Future<bool> logAdminAction({
    required String adminId,
    required String actionType,
    required String details,
    required String category,
    required String severity,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      await _supabase.from('activity_logs').insert({
        'admin_id': adminId,
        'action_type': actionType,
        'details': details,
        'category': category,
        'severity': severity,
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'log_type': 'admin',
      });
      clearCache();
      return true;
    } catch (e) {
      debugPrint('Error logging admin action: $e');
      return false;
    }
  }

  /// Log User Activity
  static Future<bool> logUserActivity({
    required String userId,
    required String actionType,
    required String details,
    required String category,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      await _supabase.from('activity_logs').insert({
        'user_id': userId,
        'action_type': actionType,
        'details': details,
        'category': category,
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'log_type': 'user',
      });
      clearCache();
      return true;
    } catch (e) {
      debugPrint('Error logging user activity: $e');
      return false;
    }
  }

  /// Log Export
  static Future<bool> logExport({
    required String userId,
    required String exportType,
    required String format,
    required int recordCount,
    required String fileSize,
    required String status,
  }) async {
    try {
      await _supabase.from('activity_logs').insert({
        'user_id': userId,
        'export_type': exportType,
        'format': format,
        'record_count': recordCount,
        'file_size': fileSize,
        'status': status,
        'log_type': 'export',
      });
      clearCache();
      return true;
    } catch (e) {
      debugPrint('Error logging export: $e');
      return false;
    }
  }

  static bool _isCacheValid(String key) {
    if (!_cache.containsKey(key) || !_cacheTimestamp.containsKey(key)) return false;
    final timestamp = _cacheTimestamp[key]!;
    return DateTime.now().difference(timestamp) < _cacheTimeout;
  }

  static void _cacheResult(String key, dynamic value) {
    _cache[key] = value;
    _cacheTimestamp[key] = DateTime.now();
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