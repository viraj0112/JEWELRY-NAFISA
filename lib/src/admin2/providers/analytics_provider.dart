// Riverpod Providers for Analytics
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analytics_models.dart';
import '../services/analytics_service.dart';

// Time range state provider
final analyticsTimeRangeProvider = StateProvider<String>((ref) => '7d');

// Top Posts Provider
final analyticsTopPostsProvider =
    FutureProvider.family<List<TopPost>, String?>((ref, timeRange) async {
  return AnalyticsService.fetchTopPosts(timeRange: timeRange);
});

// Engagement Trends Provider
final analyticsEngagementTrendsProvider =
    FutureProvider.family<List<EngagementTrend>, String?>(
        (ref, timeRange) async {
  return AnalyticsService.fetchEngagementTrends(timeRange: timeRange);
});

// Purchase Probability Provider
final analyticsPurchaseProbabilityProvider =
    FutureProvider<List<PurchaseProbability>>((ref) async {
  return AnalyticsService.fetchPurchaseProbability();
});

// Conversion Funnel Provider
final analyticsConversionFunnelProvider =
    FutureProvider<List<ConversionFunnelStage>>((ref) async {
  return AnalyticsService.fetchConversionFunnel();
});

// Top Members Provider
final analyticsTopMembersProvider =
    FutureProvider<List<TopMember>>((ref) async {
  return AnalyticsService.fetchTopMembers();
});

// Category Preferences Provider
final analyticsCategoryPreferencesProvider =
    FutureProvider<List<CategoryPreference>>((ref) async {
  return AnalyticsService.fetchCategoryPreferences();
});

// Credit Users Provider
final analyticsCreditUsersProvider =
    FutureProvider<List<CreditUser>>((ref) async {
  return AnalyticsService.fetchCreditUsers();
});

// Combined Analytics Data Provider
final analyticsDataProvider = FutureProvider<
    ({
      List<TopPost> topPosts,
      List<EngagementTrend> trends,
      List<PurchaseProbability> purchaseProbabilities,
      List<ConversionFunnelStage> funnel,
      List<TopMember> members,
      List<CategoryPreference> categories,
      List<CreditUser> creditUsers,
    })>((ref) async {
  final timeRange = ref.watch(analyticsTimeRangeProvider);

  final topPosts = await ref.watch(analyticsTopPostsProvider(timeRange).future);
  final trends =
      await ref.watch(analyticsEngagementTrendsProvider(timeRange).future);
  final purchaseProbabilities =
      await ref.watch(analyticsPurchaseProbabilityProvider.future);
  final funnel = await ref.watch(analyticsConversionFunnelProvider.future);
  final members = await ref.watch(analyticsTopMembersProvider.future);
  final categories =
      await ref.watch(analyticsCategoryPreferencesProvider.future);
  final creditUsers = await ref.watch(analyticsCreditUsersProvider.future);

  return (
    topPosts: topPosts,
    trends: trends,
    purchaseProbabilities: purchaseProbabilities,
    funnel: funnel,
    members: members,
    categories: categories,
    creditUsers: creditUsers,
  );
});

// Refresh function providers
final refreshTopPostsProvider =
    FutureProvider.family<void, String?>((ref, timeRange) async {
  ref.invalidate(analyticsTopPostsProvider);
  await ref.watch(analyticsTopPostsProvider(timeRange).future);
});

final refreshAllAnalyticsProvider = FutureProvider<void>((ref) async {
  ref.invalidate(analyticsTopPostsProvider);
  ref.invalidate(analyticsEngagementTrendsProvider);
  ref.invalidate(analyticsPurchaseProbabilityProvider);
  ref.invalidate(analyticsConversionFunnelProvider);
  ref.invalidate(analyticsTopMembersProvider);
  ref.invalidate(analyticsCategoryPreferencesProvider);
  ref.invalidate(analyticsCreditUsersProvider);
  ref.invalidate(analyticsDataProvider);
});
