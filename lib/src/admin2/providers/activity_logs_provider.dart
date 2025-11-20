import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_logs_models.dart';
import '../services/activity_logs_service.dart';

// Activity Summary Provider
final activitySummaryProvider = FutureProvider<ActivitySummary>((ref) async {
  return ActivityLogsService.fetchActivitySummary();
});

// Admin Logs Provider
final adminLogsProvider = FutureProvider.family<List<ActivityLog>, Map<String, dynamic>>((ref, filters) async {
  return ActivityLogsService.fetchAdminLogs(
    searchTerm: filters['searchTerm'],
    category: filters['category'],
    startDate: filters['startDate'],
    endDate: filters['endDate'],
    limit: filters['limit'] ?? 100,
  );
});

// User Activity Logs Provider
final userActivityLogsProvider = FutureProvider.family<List<ActivityLog>, Map<String, dynamic>>((ref, filters) async {
  return ActivityLogsService.fetchUserActivityLogs(
    searchTerm: filters['searchTerm'],
    category: filters['category'],
    startDate: filters['startDate'],
    endDate: filters['endDate'],
    limit: filters['limit'] ?? 100,
  );
});

// Export Logs Provider
final exportLogsProvider = FutureProvider.family<List<ActivityLog>, Map<String, dynamic>>((ref, filters) async {
  return ActivityLogsService.fetchExportLogs(
    format: filters['format'],
    startDate: filters['startDate'],
    endDate: filters['endDate'],
    limit: filters['limit'] ?? 100,
  );
});

// State providers for filters
final activityLogsSearchProvider = StateProvider<String?>((ref) => null);
final activityLogsCategoryProvider = StateProvider<String?>((ref) => null);
final activityLogsDateRangeProvider = StateProvider<Map<String, DateTime?>?>((ref) => null);
final activityLogsFormatProvider = StateProvider<String?>((ref) => null);

// Combined provider for current tab data
final currentActivityLogsProvider = FutureProvider.family<List<ActivityLog>, String>((ref, tab) async {
  final search = ref.watch(activityLogsSearchProvider);
  final category = ref.watch(activityLogsCategoryProvider);
  final dateRange = ref.watch(activityLogsDateRangeProvider);
  final format = ref.watch(activityLogsFormatProvider);

  final filters = {
    'searchTerm': search,
    'category': category,
    'startDate': dateRange?['start'],
    'endDate': dateRange?['end'],
    'format': format,
  };

  switch (tab) {
    case 'admin':
      return ref.watch(adminLogsProvider(filters).future);
    case 'user':
      return ref.watch(userActivityLogsProvider(filters).future);
    case 'export':
      return ref.watch(exportLogsProvider(filters).future);
    default:
      return [];
  }
});

// Refresh providers
final refreshActivitySummaryProvider = FutureProvider<void>((ref) async {
  ref.invalidate(activitySummaryProvider);
  await ref.watch(activitySummaryProvider.future);
});

final refreshActivityLogsProvider = FutureProvider<void>((ref) async {
  ref.invalidate(adminLogsProvider);
  ref.invalidate(userActivityLogsProvider);
  ref.invalidate(exportLogsProvider);
  ref.invalidate(currentActivityLogsProvider);
});