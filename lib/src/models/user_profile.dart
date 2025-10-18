import 'package:jewelry_nafisa/src/models/designer_profile.dart';

class UserProfile {
  final String id;
  final String? username;
  final String? fullName;
  final String? email;
  final DateTime? birthdate;
  final String? avatarUrl;
  final String? gender;
  final UserRole role;
  final String? phone;
  final bool isMember;
  final String? membershipPlan;
  final int credits;
  final DateTime? lastCreditRefresh;
  final String? referralCode;
  final String? referredBy;
  final DateTime? createdAt;
  final bool isApproved;
  final DesignerProfile? designerProfile;

  UserProfile({
    required this.id,
    this.username,
    this.fullName,
    this.email,
    this.birthdate,
    this.avatarUrl,
    this.gender,
    required this.role,
    this.phone,
    required this.isMember,
    this.membershipPlan,
    required this.credits,
    this.lastCreditRefresh,
    this.referralCode,
    this.referredBy,
    this.createdAt,
    this.isApproved = false,
    this.designerProfile,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    // Safely parse date strings into DateTime objects
    DateTime? parseDate(String? dateStr) {
      return dateStr == null ? null : DateTime.tryParse(dateStr);
    }

    // Check for nested designer profile data
    final designerProfileData = map['designer_profiles'];

    return UserProfile(
      id: map['id'] ?? '',
      username: map['username'],
      fullName: map['full_name'],
      email: map['email'],
      birthdate: parseDate(map['birthdate']),
      avatarUrl: map['avatar_url'],
      gender: map['gender'],
      role: userRoleFromString(map['role']),
      phone: map['phone'],
      isMember: map['is_member'] ?? false,
      membershipPlan: map['membership_plan'],
      credits: map['credits_remaining'] ?? 0,
      lastCreditRefresh: parseDate(map['last_credit_refresh']),
      referralCode: map['referral_code'],
      referredBy: map['referred_by'],
      createdAt: parseDate(map['created_at']),
      isApproved: map['is_approved'] ?? false,
      designerProfile:
          designerProfileData != null && designerProfileData.isNotEmpty
              ? DesignerProfile.fromMap(designerProfileData[0])
              : null,
    );
  }
}

/// Enum to represent the different user roles in the system.
enum UserRole {
  admin,
  designer,
  member,
}

/// Converts a string from the database into a UserRole enum value.
UserRole userRoleFromString(String? role) {
  switch (role) {
    case 'admin':
      return UserRole.admin;
    case 'designer':
      return UserRole.designer;
    case 'member':
    default:
      return UserRole.member;
  }
}
