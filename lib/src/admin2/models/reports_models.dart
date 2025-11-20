// Reports Data Models
import 'package:flutter/material.dart';

class ReportOverview {
  final int totalReportsGenerated;
  final int downloadsThisMonth;
  final double averageFileSize; // in MB

  ReportOverview({
    required this.totalReportsGenerated,
    required this.downloadsThisMonth,
    required this.averageFileSize,
  });

  factory ReportOverview.fromJson(Map<String, dynamic> json) => ReportOverview(
        totalReportsGenerated: json['total_reports'] ?? 0,
        downloadsThisMonth: json['downloads_this_month'] ?? 0,
        averageFileSize: (json['avg_file_size'] ?? 0.0).toDouble(),
      );
}

class PlatformReportSummary {
  final double totalSales;
  final int activeUsers;

  PlatformReportSummary({
    required this.totalSales,
    required this.activeUsers,
  });

  factory PlatformReportSummary.fromJson(Map<String, dynamic> json) =>
      PlatformReportSummary(
        totalSales: (json['total_sales'] ?? 0.0).toDouble(),
        activeUsers: json['active_users'] ?? 0,
      );
}

class PlatformGrowthData {
  final DateTime date;
  final int users;
  final int posts;

  PlatformGrowthData({
    required this.date,
    required this.users,
    required this.posts,
  });

  factory PlatformGrowthData.fromJson(Map<String, dynamic> json) =>
      PlatformGrowthData(
        date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
        users: json['users'] ?? 0,
        posts: json['posts'] ?? 0,
      );
}

class PlatformPerformanceMetric {
  final String month;
  final int totalUsers;
  final int postsCreated;
  final double engagementScore;
  final double growthRate;

  PlatformPerformanceMetric({
    required this.month,
    required this.totalUsers,
    required this.postsCreated,
    required this.engagementScore,
    required this.growthRate,
  });

  factory PlatformPerformanceMetric.fromJson(Map<String, dynamic> json) =>
      PlatformPerformanceMetric(
        month: json['month'] ?? '',
        totalUsers: json['total_users'] ?? 0,
        postsCreated: json['posts_created'] ?? 0,
        engagementScore: (json['engagement_score'] ?? 0.0).toDouble(),
        growthRate: (json['growth_rate'] ?? 0.0).toDouble(),
      );
}

class UserGrowthData {
  final DateTime date;
  final int newUsers;
  final int activeUsers;
  final double churnRate;

  UserGrowthData({
    required this.date,
    required this.newUsers,
    required this.activeUsers,
    required this.churnRate,
  });

  factory UserGrowthData.fromJson(Map<String, dynamic> json) => UserGrowthData(
        date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
        newUsers: json['new_users'] ?? 0,
        activeUsers: json['active_users'] ?? 0,
        churnRate: (json['churn_rate'] ?? 0.0).toDouble(),
      );
}

class AvailableUserReport {
  final String name;
  final String type;
  final DateTime generatedDate;
  final int downloadCount;
  final double fileSize; // in MB
  final String format;

  AvailableUserReport({
    required this.name,
    required this.type,
    required this.generatedDate,
    required this.downloadCount,
    required this.fileSize,
    required this.format,
  });

  factory AvailableUserReport.fromJson(Map<String, dynamic> json) =>
      AvailableUserReport(
        name: json['name'] ?? '',
        type: json['type'] ?? '',
        generatedDate: DateTime.parse(
            json['generated_date'] ?? DateTime.now().toIso8601String()),
        downloadCount: json['download_count'] ?? 0,
        fileSize: (json['file_size'] ?? 0.0).toDouble(),
        format: json['format'] ?? 'PDF',
      );
}

class ContentReport {
  final String name;
  final String type;
  final DateTime generatedDate;
  final int downloadCount;
  final double fileSize;
  final String format;

  ContentReport({
    required this.name,
    required this.type,
    required this.generatedDate,
    required this.downloadCount,
    required this.fileSize,
    required this.format,
  });

  factory ContentReport.fromJson(Map<String, dynamic> json) => ContentReport(
        name: json['name'] ?? '',
        type: json['type'] ?? '',
        generatedDate: DateTime.parse(
            json['generated_date'] ?? DateTime.now().toIso8601String()),
        downloadCount: json['download_count'] ?? 0,
        fileSize: (json['file_size'] ?? 0.0).toDouble(),
        format: json['format'] ?? 'PDF',
      );
}

class CustomReportConfig {
  final String reportType;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> metrics;
  final String format;

  CustomReportConfig({
    required this.reportType,
    required this.startDate,
    required this.endDate,
    required this.metrics,
    required this.format,
  });
}

enum ReportType { platform, users, content, custom }
enum ReportFormat { pdf, excel, csv }
enum MetricType {
  userGrowth,
  engagement,
  contentStats,
  b2bMetrics,
  referrals
}

// Extension for formatted numbers
extension ReportExtensions on int {
  String get formatted {
    if (this >= 1000000) {
      return '${(this / 1000000).toStringAsFixed(1)}M';
    } else if (this >= 1000) {
      return '${(this / 1000).toStringAsFixed(1)}K';
    }
    return toString();
  }
}

extension DoubleExtensions on double {
  String get formatted {
    if (this >= 1000000) {
      return '${(this / 1000000).toStringAsFixed(1)}M';
    } else if (this >= 1000) {
      return '${(this / 1000).toStringAsFixed(1)}K';
    }
    return toStringAsFixed(1);
  }
}