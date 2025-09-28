import 'package:flutter/material.dart';

class AppUser {
  final String id;
  final String? email;
  final String? username;
  final String? role;
  final String? approvalStatus;
  final bool isMember;
  final DateTime createdAt;
  final String? businessName;

  AppUser({
    required this.id,
    this.email,
    this.username,
    this.role,
    this.approvalStatus,
    this.isMember = false,
    required this.createdAt,
    this.businessName,
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
