
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
  final String? ownerUsername; // Added for convenience

  Asset({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.mediaUrl,
    required this.status,
    required this.createdAt,
    this.ownerUsername,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    // Handle nested owner data if it exists
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
    );
  }
}

class PostAnalytic {
  final String assetId;
  final String assetTitle;
  final String assetType; // 'Uploaded' or 'Scraped'
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