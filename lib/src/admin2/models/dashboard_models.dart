import 'package:flutter/material.dart';

class DashboardData {
  final KPIMetrics kpiMetrics;
  final List<UserGrowthData> userGrowthData;
  final List<HourlyActivity> hourlyActivity;
  final GeographicData geographicData;
  final List<CategoryInsight> categoryInsights;
  final List<TopPost> topPosts;
  final ConversionFunnel conversionFunnel;

  DashboardData({
    required this.kpiMetrics,
    required this.userGrowthData,
    required this.hourlyActivity,
    required this.geographicData,
    required this.categoryInsights,
    required this.topPosts,
    required this.conversionFunnel,
  });
}

class KPIMetrics {
  final int totalMembers;
  final int totalNonMembers;
  final int dailyActiveUsers;
  final int creditsUsedToday;
  final int totalReferrals;
  final int postsViewedToday;

  // Growth percentages
  final double membersGrowth;
  final double nonMembersGrowth;
  final double dauGrowth;
  final double creditsGrowth;
  final double referralsGrowth;
  final double viewsGrowth;

  KPIMetrics({
    required this.totalMembers,
    required this.totalNonMembers,
    required this.dailyActiveUsers,
    required this.creditsUsedToday,
    required this.totalReferrals,
    required this.postsViewedToday,
    required this.membersGrowth,
    required this.nonMembersGrowth,
    required this.dauGrowth,
    required this.creditsGrowth,
    required this.referralsGrowth,
    required this.viewsGrowth,
  });
}

class UserGrowthData {
  final DateTime date;
  final int members;
  final int nonMembers;

  UserGrowthData({
    required this.date,
    required this.members,
    required this.nonMembers,
  });
}

class HourlyActivity {
  final int hour;
  final int activityCount;

  HourlyActivity({
    required this.hour,
    required this.activityCount,
  });
}

class GeographicData {
  final String level; // 'country', 'state', 'city', 'pincode'
  final String parentCode; // for drill-down
  final List<GeographicItem> items;

  GeographicData({
    required this.level,
    required this.parentCode,
    required this.items,
  });
}

class GeographicItem {
  final String code;
  final String name;
  final int userCount;
  final double percentage;
  final bool isGrowing;

  GeographicItem({
    required this.code,
    required this.name,
    required this.userCount,
    required this.percentage,
    required this.isGrowing,
  });
}

class CategoryInsight {
  final String category;
  final int totalPins;
  final int totalImages;
  final double growthPercentage;
  final List<TopPost> topPosts;
  final Color color;

  CategoryInsight({
    required this.category,
    required this.totalPins,
    required this.totalImages,
    required this.growthPercentage,
    required this.topPosts,
    required this.color,
  });
}

class TopPost {
  final String id;
  final String title;
  final String category;
  final int views;
  final int unlocks;
  final int saves;
  final int shares;
  final DateTime date;

  TopPost({
    required this.id,
    required this.title,
    required this.category,
    required this.views,
    required this.unlocks,
    required this.saves,
    required this.shares,
    required this.date,
  });
}

class ConversionFunnel {
  final FunnelStage signups;
  final FunnelStage firstLogin;
  final FunnelStage creditUse;
  final FunnelStage membership;

  ConversionFunnel({
    required this.signups,
    required this.firstLogin,
    required this.creditUse,
    required this.membership,
  });
}

class FunnelStage {
  final String name;
  final int users;
  final double percentage;
  final double changeFromPrevious;

  FunnelStage({
    required this.name,
    required this.users,
    required this.percentage,
    required this.changeFromPrevious,
  });
}

enum TimeRange { today, week7, month30, custom }
enum ExportFormat { csv, pdf, png }