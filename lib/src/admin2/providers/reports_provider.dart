// Riverpod Providers for Reports
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reports_models.dart';
import '../services/reports_service.dart';

// Time range state provider
final reportsTimeRangeProvider = StateProvider<String>((ref) => '30d');

// Report Overview Provider
final reportOverviewProvider = FutureProvider<ReportOverview>((ref) async {
  return ReportsService.fetchReportOverview();
});

// Platform Report Summary Provider
final platformReportSummaryProvider = FutureProvider<PlatformReportSummary>((ref) async {
  return ReportsService.fetchPlatformReportSummary();
});

// Platform Growth Data Provider
final platformGrowthDataProvider = FutureProvider<List<PlatformGrowthData>>((ref) async {
  return ReportsService.fetchPlatformGrowthData();
});

// Platform Performance Metrics Provider
final platformPerformanceMetricsProvider = FutureProvider<List<PlatformPerformanceMetric>>((ref) async {
  return ReportsService.fetchPlatformPerformanceMetrics();
});

// User Growth Data Provider
final userGrowthDataProvider = FutureProvider<List<UserGrowthData>>((ref) async {
  return ReportsService.fetchUserGrowthData();
});

// Available User Reports Provider
final availableUserReportsProvider = FutureProvider<List<AvailableUserReport>>((ref) async {
  return ReportsService.fetchAvailableUserReports();
});

// Content Reports Provider
final contentReportsProvider = FutureProvider<List<ContentReport>>((ref) async {
  return ReportsService.fetchContentReports();
});

// Combined Reports Data Provider
final reportsDataProvider = FutureProvider<
    ({
      ReportOverview overview,
      PlatformReportSummary platformSummary,
      List<PlatformGrowthData> platformGrowth,
      List<PlatformPerformanceMetric> platformMetrics,
      List<UserGrowthData> userGrowth,
      List<AvailableUserReport> userReports,
      List<ContentReport> contentReports,
    })>((ref) async {
  final overview = await ref.watch(reportOverviewProvider.future);
  final platformSummary = await ref.watch(platformReportSummaryProvider.future);
  final platformGrowth = await ref.watch(platformGrowthDataProvider.future);
  final platformMetrics = await ref.watch(platformPerformanceMetricsProvider.future);
  final userGrowth = await ref.watch(userGrowthDataProvider.future);
  final userReports = await ref.watch(availableUserReportsProvider.future);
  final contentReports = await ref.watch(contentReportsProvider.future);

  return (
    overview: overview,
    platformSummary: platformSummary,
    platformGrowth: platformGrowth,
    platformMetrics: platformMetrics,
    userGrowth: userGrowth,
    userReports: userReports,
    contentReports: contentReports,
  );
});

// Custom Report Generation Provider
final generateCustomReportProvider = FutureProvider.family<bool, CustomReportConfig>((ref, config) async {
  return ReportsService.generateCustomReport(config);
});

// Refresh functions
final refreshReportOverviewProvider = FutureProvider<void>((ref) async {
  ref.invalidate(reportOverviewProvider);
  await ref.watch(reportOverviewProvider.future);
});

final refreshAllReportsProvider = FutureProvider<void>((ref) async {
  ref.invalidate(reportOverviewProvider);
  ref.invalidate(platformReportSummaryProvider);
  ref.invalidate(platformGrowthDataProvider);
  ref.invalidate(platformPerformanceMetricsProvider);
  ref.invalidate(userGrowthDataProvider);
  ref.invalidate(availableUserReportsProvider);
  ref.invalidate(contentReportsProvider);
  ref.invalidate(reportsDataProvider);
});