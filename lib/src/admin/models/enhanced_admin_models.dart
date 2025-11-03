import 'package:flutter/material.dart';

// Enhanced User Models
class DashboardMetrics {
  final int totalUsers;
  final int totalMembers;
  final int totalNonMembers;
  final int totalBCreators;
  final int totalPosts;
  final int scrapedPosts;
  final int uploadedPosts;
  final int dailyCreditsUsed;
  final List<TopPost> topPerformingPosts;
  final EngagementData engagementGraph;

  DashboardMetrics({
    required this.totalUsers,
    required this.totalMembers,
    required this.totalNonMembers,
    required this.totalBCreators,
    required this.totalPosts,
    required this.scrapedPosts,
    required this.uploadedPosts,
    required this.dailyCreditsUsed,
    required this.topPerformingPosts,
    required this.engagementGraph,
  });
}

class EngagementData {
  final List<TimeSeriesPoint> views;
  final List<TimeSeriesPoint> unlocks;
  final List<TimeSeriesPoint> saves;
  final List<TimeSeriesPoint> shares;

  EngagementData({
    required this.views,
    required this.unlocks,
    required this.saves,
    required this.shares,
  });
}

class TimeSeriesPoint {
  final DateTime date;
  final int value;

  TimeSeriesPoint({required this.date, required this.value});
}

class TopPost {
  final String id;
  final String title;
  final String category;
  final int views;
  final int unlocks;
  final int saves;
  final int shares;
  final DateTime createdAt;
  final String source; // 'scraped' or 'b2b'

  TopPost({
    required this.id,
    required this.title,
    required this.category,
    required this.views,
    required this.unlocks,
    required this.saves,
    required this.shares,
    required this.createdAt,
    required this.source,
  });
}

// Enhanced User Management Models
class EnhancedUser {
  final String id;
  final String? email;
  final String? username;
  final String? fullName;
  final String role;
  final String status;
  final bool isMember;
  final DateTime createdAt;
  final DateTime? membershipExpiry;
  final int creditsRemaining;
  final String? referralCode;
  final String? referredBy;
  final String signupSource; // Organic, Referral, Social
  final int referralCount;
  final List<CreditUsage> creditHistory;

  EnhancedUser({
    required this.id,
    this.email,
    this.username,
    this.fullName,
    required this.role,
    required this.status,
    required this.isMember,
    required this.createdAt,
    this.membershipExpiry,
    required this.creditsRemaining,
    this.referralCode,
    this.referredBy,
    required this.signupSource,
    required this.referralCount,
    this.creditHistory = const [],
  });
}

class CreditUsage {
  final DateTime date;
  final int creditsUsed;
  final String action; // 'unlock', 'save', 'share'

  CreditUsage({
    required this.date,
    required this.creditsUsed,
    required this.action,
  });
}

class ReferralTree {
  final String userId;
  final String? username;
  final int level;
  final DateTime joinedAt;
  final List<ReferralTree> children;

  ReferralTree({
    required this.userId,
    this.username,
    required this.level,
    required this.joinedAt,
    this.children = const [],
  });
}

class EngagementHeatmap {
  final String userId;
  final Map<String, int> dailyActivity; // '2025-01-01': 5, etc.

  EngagementHeatmap({
    required this.userId,
    required this.dailyActivity,
  });
}

// Content Management Models
class ScrapedContent {
  final String id;
  final String title;
  final String category;
  final String source;
  final String status;
  final DateTime createdAt;
  final int views;
  final int engagement;
  final String? scrapeUrl;

  ScrapedContent({
    required this.id,
    required this.title,
    required this.category,
    required this.source,
    required this.status,
    required this.createdAt,
    required this.views,
    required this.engagement,
    this.scrapeUrl,
  });
}

class ContentSource {
  final String name;
  final String url;
  final int postsImported;
  final int totalTraffic;
  final double avgEngagement;

  ContentSource({
    required this.name,
    required this.url,
    required this.postsImported,
    required this.totalTraffic,
    required this.avgEngagement,
  });
}

class B2BCreatorUpload {
  final String id;
  final String creatorId;
  final String creatorName;
  final String title;
  final String status;
  final DateTime uploadedAt;
  final int views;
  final int unlocks;
  final String format;
  final bool isFeatured;

  B2BCreatorUpload({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    required this.status,
    required this.uploadedAt,
    required this.views,
    required this.unlocks,
    required this.format,
    required this.isFeatured,
  });
}

class UserBoard {
  final String id;
  final String name;
  final String userId;
  final String userName;
  final DateTime createdAt;
  final int savedPosts;
  final int shares;
  final double engagementRate;

  UserBoard({
    required this.id,
    required this.name,
    required this.userId,
    required this.userName,
    required this.createdAt,
    required this.savedPosts,
    required this.shares,
    required this.engagementRate,
  });
}

// Analytics Models
class PostAnalytics {
  final String id;
  final String title;
  final String category;
  final String source;
  final String creator;
  final int views;
  final int unlocks;
  final int saves;
  final int shares;
  final double ctr;
  final DateTime createdAt;
  final List<String> topRegions;

  PostAnalytics({
    required this.id,
    required this.title,
    required this.category,
    required this.source,
    required this.creator,
    required this.views,
    required this.unlocks,
    required this.saves,
    required this.shares,
    required this.ctr,
    required this.createdAt,
    this.topRegions = const [],
  });
}

class UserBehavior {
  final String userId;
  final double avgSessionLength;
  final int repeatVisits;
  final List<String> popularActions;
  final Map<String, double> dropOffRates; // 'view_to_unlock': 0.25, etc.

  UserBehavior({
    required this.userId,
    required this.avgSessionLength,
    required this.repeatVisits,
    required this.popularActions,
    required this.dropOffRates,
  });
}

class CreditAnalytics {
  final int totalIssued;
  final int totalConsumed;
  final Map<String, int> dailyUsage;
  final Map<String, double> avgCreditsPerUserType;
  final Map<String, int> peakUsageTimes;
  final int referralImpact;

  CreditAnalytics({
    required this.totalIssued,
    required this.totalConsumed,
    required this.dailyUsage,
    required this.avgCreditsPerUserType,
    required this.peakUsageTimes,
    required this.referralImpact,
  });
}

class EngagementSegment {
  final String segmentName;
  final double engagementRate;
  final Map<String, double> contentTypeEngagement;

  EngagementSegment({
    required this.segmentName,
    required this.engagementRate,
    required this.contentTypeEngagement,
  });
}

// B2B Creator Analytics
class CreatorAnalytics {
  final String creatorId;
  final String creatorName;
  final int totalWorksUploaded;
  final List<TopPerformingWork> topWorks;
  final int totalUnlocksByMembers;
  final int totalSaves;
  final int contactClicks;
  final PerformanceTrend trend;
  final Map<String, int> audienceBreakdown;
  final List<String> topRegions;

  CreatorAnalytics({
    required this.creatorId,
    required this.creatorName,
    required this.totalWorksUploaded,
    required this.topWorks,
    required this.totalUnlocksByMembers,
    required this.totalSaves,
    required this.contactClicks,
    required this.trend,
    required this.audienceBreakdown,
    this.topRegions = const [],
  });
}

class TopPerformingWork {
  final String workId;
  final String title;
  final int views;
  final int unlocks;
  final int saves;
  final int shares;
  final DateTime createdAt;

  TopPerformingWork({
    required this.workId,
    required this.title,
    required this.views,
    required this.unlocks,
    required this.saves,
    required this.shares,
    required this.createdAt,
  });
}

class PerformanceTrend {
  final List<TimeSeriesPoint> last30Days;
  final double trendDirection; // positive, negative, neutral

  PerformanceTrend({
    required this.last30Days,
    required this.trendDirection,
  });
}

// Monetization Models
class MembershipAnalytics {
  final int activeSubscriptions;
  final int expiredSubscriptions;
  final double growthRate;
  final double totalRevenue;
  final Map<String, int> subscriptionBreakdown;
  final ConversionFunnel conversionFunnel;

  MembershipAnalytics({
    required this.activeSubscriptions,
    required this.expiredSubscriptions,
    required this.growthRate,
    required this.totalRevenue,
    required this.subscriptionBreakdown,
    required this.conversionFunnel,
  });
}

class ConversionFunnel {
  final double visitorToSignupRate;
  final double signupToMemberRate;
  final double memberRetentionRate;

  ConversionFunnel({
    required this.visitorToSignupRate,
    required this.signupToMemberRate,
    required this.memberRetentionRate,
  });
}

class RevenueAnalytics {
  final double totalRevenue;
  final double monthlyRecurringRevenue;
  final double averageRevenuePerUser;
  final Map<String, double> revenueBySource;

  RevenueAnalytics({
    required this.totalRevenue,
    required this.monthlyRecurringRevenue,
    required this.averageRevenuePerUser,
    required this.revenueBySource,
  });
}

// Referral Analytics
class ReferralAnalytics {
  final int totalReferrals;
  final List<TopReferrerDetailed> topReferrers;
  final double conversionRate;
  final int creditsRewarded;
  final Map<String, int> referralSourcePerformance;

  ReferralAnalytics({
    required this.totalReferrals,
    required this.topReferrers,
    required this.conversionRate,
    required this.creditsRewarded,
    required this.referralSourcePerformance,
  });
}

class TopReferrerDetailed {
  final String userId;
  final String username;
  final int referralCount;
  final int creditsEarned;
  final DateTime joinedAt;
  final List<ReferredUserDetailed> referredUsers;

  TopReferrerDetailed({
    required this.userId,
    required this.username,
    required this.referralCount,
    required this.creditsEarned,
    required this.joinedAt,
    this.referredUsers = const [],
  });
}

class ReferredUserDetailed {
  final String userId;
  final String username;
  final DateTime joinedAt;
  final bool becameMember;
  final int creditsUsed;

  ReferredUserDetailed({
    required this.userId,
    required this.username,
    required this.joinedAt,
    required this.becameMember,
    required this.creditsUsed,
  });
}

// Settings Models
class SystemSettings {
  final CreditSettings creditSettings;
  final UserRoleSettings roleSettings;
  final ScraperSettings scraperSettings;
  final AISettings aiSettings;

  SystemSettings({
    required this.creditSettings,
    required this.roleSettings,
    required this.scraperSettings,
    required this.aiSettings,
  });
}

class CreditSettings {
  final int dailyCreditReset;
  final int signupBonus;
  final int referralBonus;
  final String resetTime; // HH:mm format

  CreditSettings({
    required this.dailyCreditReset,
    required this.signupBonus,
    required this.referralBonus,
    required this.resetTime,
  });
}

class UserRoleSettings {
  final List<String> adminRoles;
  final List<String> moderatorRoles;
  final List<String> creatorRoles;
  final List<String> memberRoles;
  final List<String> freeUserRoles;

  UserRoleSettings({
    required this.adminRoles,
    required this.moderatorRoles,
    required this.creatorRoles,
    required this.memberRoles,
    required this.freeUserRoles,
  });
}

class ScraperSettings {
  final List<String> enabledSources;
  final String scrapingFrequency;
  final List<String> captureFields;

  ScraperSettings({
    required this.enabledSources,
    required this.scrapingFrequency,
    required this.captureFields,
  });
}

class AISettings {
  final double searchThreshold;
  final int maxResults;
  final bool enableAutoTagging;

  AISettings({
    required this.searchThreshold,
    required this.maxResults,
    required this.enableAutoTagging,
  });
}

// Quick Insights Model
class QuickInsights {
  final String postId;
  final int uniqueViews;
  final int repeatViews;
  final int unlocks;
  final int saves;
  final int shares;
  final List<String> topRegions;
  final List<TimeSeriesPoint> last7DaysPerformance;
  final double engagementTrend;

  QuickInsights({
    required this.postId,
    required this.uniqueViews,
    required this.repeatViews,
    required this.unlocks,
    required this.saves,
    required this.shares,
    this.topRegions = const [],
    required this.last7DaysPerformance,
    required this.engagementTrend,
  });
}