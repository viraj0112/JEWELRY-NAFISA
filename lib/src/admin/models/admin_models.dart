import 'package:flutter/material.dart';

enum DateRangeType { today, thisWeek, thisMonth, custom }

extension DateRangeTypeExtension on DateRangeType {
  String get name {
    switch (this) {
      case DateRangeType.today:
        return 'Today';
      case DateRangeType.thisWeek:
        return 'This Week';
      case DateRangeType.thisMonth:
        return 'This Month';
      case DateRangeType.custom:
        return 'Custom';
    }
  }
}

class FilterState {
  final DateRangeType dateRangeType;
  final DateTimeRange? customDateRange;
  final String category;
  final String status;

  FilterState({
    required this.dateRangeType,
    this.customDateRange,
    required this.category,
    required this.status,
  });

  /// **FIX ADDED**: A getter to compute the effective date range.
  DateTimeRange? get dateRange {
    final now = DateTime.now();
    switch (dateRangeType) {
      case DateRangeType.today:
        final startOfDay = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: startOfDay, end: now);
      case DateRangeType.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfDay =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return DateTimeRange(start: startOfDay, end: now);
      case DateRangeType.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: startOfMonth, end: now);
      case DateRangeType.custom:
        return customDateRange;
    }
  }

  factory FilterState.defaultFilters() {
    return FilterState(
      dateRangeType: DateRangeType.thisMonth,
      category: 'All Categories',
      status: 'All Status',
    );
  }

  FilterState copyWith({
    DateRangeType? dateRangeType,
    DateTimeRange? customDateRange,
    String? category,
    String? status,
  }) {
    return FilterState(
      dateRangeType: dateRangeType ?? this.dateRangeType,
      customDateRange: customDateRange ?? this.customDateRange,
      category: category ?? this.category,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterState &&
          runtimeType == other.runtimeType &&
          dateRangeType == other.dateRangeType &&
          customDateRange == other.customDateRange &&
          category == other.category &&
          status == other.status;

  @override
  int get hashCode =>
      dateRangeType.hashCode ^
      customDateRange.hashCode ^
      category.hashCode ^
      status.hashCode;
}

class AppUser {
  final String id;
  final String? email;
  final String? username;
  final String? role;
  final String? approvalStatus;
  final bool isMember;
  final DateTime createdAt;
  final String? businessName;
  final String? avatarUrl;
  final String? membershipPlan; // <-- ADDED
  final String? membershipStatus; // <-- ADDED

  AppUser({
    required this.id,
    this.email,
    this.username,
    this.role,
    this.approvalStatus,
    this.isMember = false,
    required this.createdAt,
    this.businessName,
    this.avatarUrl,
    this.membershipPlan, // <-- ADDED
    this.membershipStatus, // <-- ADDED
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      role: json['role'],
      approvalStatus: json['approval_status'],
      isMember: json['is_member'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      businessName: json['business_name'],
      avatarUrl: json['avatar_url'],
      membershipPlan: json['membership_plan'], // <-- ADDED
      membershipStatus: json['membership_status'], // <-- ADDED
    );
  }

  Color get statusColor {
    switch (approvalStatus) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class TopReferrer {
  final String userId;
  final String? username;
  final String? email;
  final int referralCount;

  TopReferrer({
    required this.userId,
    this.username,
    this.email,
    required this.referralCount,
  });

  factory TopReferrer.fromJson(Map<String, dynamic> json) {
    return TopReferrer(
      userId: json['user_id'],
      username: json['username'],
      email: json['email'],
      referralCount: json['referral_count'] ?? 0,
    );
  }
}

class Asset {
  final String id;
  final String title;
  final String ownerId;
  final String mediaUrl;
  final String status;
  final DateTime createdAt;
  final String? ownerUsername;
  final String? ownerEmail;
  final String? source;

  Asset({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.mediaUrl,
    required this.status,
    required this.createdAt,
    this.ownerUsername,
    this.ownerEmail,
    this.source,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    final ownerData = json['users'];
    String? username;
    if (ownerData != null && ownerData is Map<String, dynamic>) {
      username = ownerData['username'];
    }

    return Asset(
      id: json['id'],
      title: json['title'],
      ownerId: json['owner_id'],
      mediaUrl: json['media_url'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      ownerUsername: username,
      ownerEmail: json['owner_email'], 
      source: json['source'],
    );
  }
}

class PostAnalytic {
  final String assetId;
  final String assetTitle;
  final String assetType;
  final int views;
  final int likes;
  final int saves;
  final DateTime date;

  PostAnalytic({
    required this.assetId,
    required this.assetTitle,
    required this.assetType,
    required this.views,
    required this.likes,
    required this.saves,
    required this.date,
  });

  factory PostAnalytic.fromJson(Map<String, dynamic> json) {
    return PostAnalytic(
      assetId: json['asset_id'],
      assetTitle: json['asset_title'] ?? 'N/A',
      assetType: json['asset_type'] ?? 'Scraped',
      views: json['views'] ?? 0,
      likes: json['likes'] ?? 0,
      saves: json['saves'] ?? 0,
      date: DateTime.parse(json['date']),
    );
  }
}

class CreditHistory {
  final DateTime entryDate;
  final int creditsAdded;
  final int creditsSpent;

  CreditHistory(
      {required this.entryDate,
      required this.creditsAdded,
      required this.creditsSpent});

  factory CreditHistory.fromJson(Map<String, dynamic> json) {
    return CreditHistory(
      entryDate: DateTime.parse(json['entry_date']),
      creditsAdded: json['credits_added'],
      creditsSpent: json['credits_spent'],
    );
  }
}

class ReferralNode {
  final int level;
  final String userId;
  final String? username;
  final String? referredBy;

  ReferralNode(
      {required this.level,
      required this.userId,
      this.username,
      this.referredBy});

  factory ReferralNode.fromJson(Map<String, dynamic> json) {
    return ReferralNode(
      level: json['level'],
      userId: json['user_id'],
      username: json['username'],
      referredBy: json['referred_by'],
    );
  }
}

class Board {
  final String id;
  final String name;
  final String userId;
  final DateTime createdAt;

  Board({
    required this.id,
    required this.name,
    required this.userId,
    required this.createdAt,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'],
      name: json['name'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class CreatorDashboard {
  final int totalWorksUploaded;
  final List<TopPost> topPosts;
  final int totalUnlocks;
  final int totalSaves;

  CreatorDashboard({
    required this.totalWorksUploaded,
    required this.topPosts,
    required this.totalUnlocks,
    required this.totalSaves,
  });

  factory CreatorDashboard.fromJson(Map<String, dynamic> json) {
    return CreatorDashboard(
      totalWorksUploaded: json['total_works_uploaded'],
      topPosts:
          (json['top_posts'] as List).map((e) => TopPost.fromJson(e)).toList(),
      totalUnlocks: json['total_unlocks'],
      totalSaves: json['total_saves'],
    );
  }
}

class TopPost {
  final String title;
  final int views;
  final int likes;
  final int saves;

  TopPost(
      {required this.title,
      required this.views,
      required this.likes,
      required this.saves});

  factory TopPost.fromJson(Map<String, dynamic> json) {
    return TopPost(
      title: json['title'],
      views: json['views'],
      likes: json['likes'],
      saves: json['saves'],
    );
  }
}