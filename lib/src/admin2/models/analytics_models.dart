// Analytics Data Models
import 'package:flutter/material.dart';

class TopPost {
  final String id;
  final String title;
  final String category;
  final int views;
  final int likes;
  final int comments;
  final int saves;
  final int quotesRequested;
  final int shares;
  final DateTime date;
  final String? thumbUrl;
  final String? thumbnail;
  final List<String>? tags;

  TopPost({
    required this.id,
    required this.title,
    required this.category,
    required this.views,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.quotesRequested,
    required this.shares,
    required this.date,
    this.thumbUrl,
    this.thumbnail,
    this.tags,
  });

  factory TopPost.fromJson(Map<String, dynamic> json) => TopPost(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        category: json['category'] ?? '',
        views: json['views']?.toInt() ?? 0,
        likes: json['likes']?.toInt() ?? 0,
        comments: json['comments']?.toInt() ?? 0,
        saves: json['saves']?.toInt() ?? 0,
        quotesRequested: json['quotes_requested']?.toInt() ?? 0,
        shares: json['shares']?.toInt() ?? 0,
        date: DateTime.parse(json['date'] ??
            json['created_at'] ??
            DateTime.now().toIso8601String()),
        thumbUrl: json['thumb_url'],
        thumbnail: json['thumbnail'],
        tags: json['tags'] is List ? List<String>.from(json['tags']) : null,
      );

  // Extension properties for easier access
  String get displayThumbnail => thumbnail ?? thumbUrl ?? '';
}

class EngagementTrend {
  final DateTime date;
  final int views;
  final int likes;
  final int saves;
  final int quotesRequested;
  final int shares;
  final int? thisWeek;
  final int? lastWeek;

  EngagementTrend({
    required this.date,
    required this.views,
    required this.likes,
    required this.saves,
    required this.quotesRequested,
    required this.shares,
    this.thisWeek,
    this.lastWeek,
  });

  factory EngagementTrend.fromJson(Map<String, dynamic> json) =>
      EngagementTrend(
        date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
        views: json['views']?.toInt() ?? 0,
        likes: json['likes']?.toInt() ?? 0,
        saves: json['saves']?.toInt() ?? 0,
        quotesRequested: json['quotes_requested']?.toInt() ?? 0,
        shares: json['shares']?.toInt() ?? 0,
        thisWeek: json['this_week']?.toInt(),
        lastWeek: json['last_week']?.toInt(),
      );
}

class PurchaseProbability {
  final String id;
  final String name;
  final String email;
  final int activityScore;
  final int probability;
  final List<String> recentActions;
  final int creditsRemaining;
  final int quotesRequested;
  final bool isMember;

  PurchaseProbability({
    required this.id,
    required this.name,
    required this.email,
    required this.activityScore,
    required this.probability,
    required this.recentActions,
    required this.creditsRemaining,
    required this.quotesRequested,
    required this.isMember,
  });

  factory PurchaseProbability.fromJson(Map<String, dynamic> json) =>
      PurchaseProbability(
        id: json['id'] ?? '',
        name: json['name'] ?? json['full_name'] ?? '',
        email: json['email'] ?? '',
        activityScore: json['activity_score']?.toInt() ?? 0,
        probability: json['probability']?.toInt() ?? 0,
        recentActions: json['recent_actions'] is List 
            ? List<String>.from(json['recent_actions']) 
            : [],
        creditsRemaining: json['credits_remaining']?.toInt() ?? 0,
        quotesRequested: json['quotes_requested']?.toInt() ?? 0,
        isMember: json['is_member'] ?? false,
      );
}

class ConversionFunnelStage {
  final String stage;
  final int users;
  final double percentage;
  final Color fill;

  ConversionFunnelStage({
    required this.stage,
    required this.users,
    required this.percentage,
    required this.fill,
  });
}

class TopMember {
  final String id;
  final String username;
  final String? avatarUrl;
  final String avatar;
  final String name;
  final int posts;
  final int saves;
  final int engagement;
  final int assetsCount;
  final int totalViews;
  final int totalLikes;
  final String? role;

  TopMember({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.avatar,
    required this.name,
    required this.posts,
    required this.saves,
    required this.engagement,
    required this.assetsCount,
    required this.totalViews,
    required this.totalLikes,
    this.role,
  });

  factory TopMember.fromJson(Map<String, dynamic> json) => TopMember(
        id: json['id'] ?? '',
        username: json['username'] ?? '',
        avatarUrl: json['avatar_url'],
        avatar: json['avatar'] ?? json['username']?.substring(0, 1).toUpperCase() ?? 'U',
        name: json['name'] ?? json['username'] ?? '',
        posts: json['posts']?.toInt() ?? json['assets_count']?.toInt() ?? 0,
        saves: json['saves']?.toInt() ?? 0,
        engagement: json['engagement']?.toInt() ?? 0,
        assetsCount: json['assets_count']?.toInt() ?? 0,
        totalViews: json['total_views']?.toInt() ?? 0,
        totalLikes: json['total_likes']?.toInt() ?? 0,
        role: json['role'],
      );
}

class CategoryPreference {
  final String name;
  final String category;
  final int assetCount;
  final int members;
  final double value;
  final double percentage;
  final Color color;

  CategoryPreference({
    required this.name,
    required this.category,
    required this.assetCount,
    required this.members,
    required this.value,
    required this.percentage,
    required this.color,
  });

  factory CategoryPreference.fromJson(Map<String, dynamic> json, int index) =>
      CategoryPreference(
        name: json['name'] ?? json['category'] ?? 'Unknown',
        category: json['category'] ?? 'Unknown',
        assetCount: json['asset_count']?.toInt() ?? 0,
        members: json['members']?.toInt() ?? 0,
        value: json['value']?.toDouble() ?? json['percentage']?.toDouble() ?? 0.0,
        percentage: json['percentage']?.toDouble() ?? 0.0,
        color: _getColorByIndex(index),
      );

  static Color _getColorByIndex(int index) {
    const colors = [
      Color(0xFF8b5cf6), // Purple
      Color(0xFFec4899), // Pink
      Color(0xFF06b6d4), // Cyan
      Color(0xFFf59e0b), // Amber
      Color(0xFF10b981), // Green
    ];
    return colors[index % colors.length];
  }
}

class CreditUser {
  final String id;
  final String username;
  final String email;
  final int creditsRemaining;
  final int currentCredits;
  final DateTime? lastCreditRefresh;
  final bool isMember;
  final DateTime createdAt;
  final CreditSource source;
  final int lastEarned;

  CreditUser({
    required this.id,
    required this.username,
    required this.email,
    required this.creditsRemaining,
    required this.currentCredits,
    this.lastCreditRefresh,
    required this.isMember,
    required this.createdAt,
    required this.source,
    required this.lastEarned,
  });

  factory CreditUser.fromJson(Map<String, dynamic> json) => CreditUser(
        id: json['id'] ?? '',
        username: json['username'] ?? '',
        email: json['email'] ?? '',
        creditsRemaining: json['credits_remaining']?.toInt() ?? 0,
        currentCredits: json['current_credits']?.toInt() ?? json['credits_remaining']?.toInt() ?? 0,
        lastCreditRefresh: json['last_credit_refresh'] != null
            ? DateTime.parse(json['last_credit_refresh'])
            : null,
        isMember: json['is_member'] ?? false,
        createdAt: DateTime.parse(
            json['created_at'] ?? DateTime.now().toIso8601String()),
        source: CreditSource.fromString(json['source'] ?? 'admin'),
        lastEarned: json['last_earned']?.toInt() ?? 0,
      );
}

class CreditDistribution {
  final String range;
  final int users;

  CreditDistribution({
    required this.range,
    required this.users,
  });
}

class CreditSummary {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  CreditSummary({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

// Credit Source enum
enum CreditSource {
  admin,
  referral,
  bonus;

  static CreditSource fromString(String source) {
    switch (source.toLowerCase()) {
      case 'admin':
        return CreditSource.admin;
      case 'referral':
        return CreditSource.referral;
      case 'bonus':
        return CreditSource.bonus;
      default:
        return CreditSource.admin;
    }
  }
}

// Extension for int formatting
extension IntExtensions on int {
  String get formatted {
    if (this >= 1000000) {
      return '${(this / 1000000).toStringAsFixed(1)}M';
    } else if (this >= 1000) {
      return '${(this / 1000).toStringAsFixed(1)}K';
    }
    return toString();
  }
}

// Extension for formatted number access on TopPost
extension TopPostExtensions on TopPost {
  int get comments => this.comments;
  String get displayThumbnail => thumbnail ?? thumbUrl ?? '';
}
