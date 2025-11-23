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
  final String? bio;

  // ------------------------------------------------------------------
  // 🎯 NEW ONBOARDING FIELDS
  // ------------------------------------------------------------------
  final int onboardingStage; // Stage 0, 1, 2, or 3
  final bool isSetupComplete; // Final flag: true when stage 3 is complete
  final String? country; // From Screen 1
  final String? region; // From Screen 1
  final List<String> selectedOccasions; // From Screen 2 (Occasions)
  final List<String> selectedCategories; // From Screen 3 (Pinterest-style)
  // ------------------------------------------------------------------

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
    this.bio,
    // NEW FIELDS REQUIRED (with safe defaults)
    this.onboardingStage = 0,
    this.isSetupComplete = false,
    this.country,
    this.region,
    this.selectedOccasions = const [],
    this.selectedCategories = const [],
  });

// --------------------------------------------------------------------------
// ## 📝 copyWith Method (Crucial for UserProfileProvider updates)
// --------------------------------------------------------------------------

  UserProfile copyWith({
    String? id,
    String? username,
    String? fullName,
    String? email,
    DateTime? birthdate,
    String? avatarUrl,
    String? gender,
    UserRole? role,
    String? phone,
    bool? isMember,
    String? membershipPlan,
    int? credits,
    DateTime? lastCreditRefresh,
    String? referralCode,
    String? referredBy,
    DateTime? createdAt,
    bool? isApproved,
    DesignerProfile? designerProfile,
    String? bio,
    // Onboarding fields
    int? onboardingStage,
    bool? isSetupComplete,
    String? country,
    String? region,
    List<String>? selectedOccasions,
    List<String>? selectedCategories,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      birthdate: birthdate ?? this.birthdate,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      isMember: isMember ?? this.isMember,
      membershipPlan: membershipPlan ?? this.membershipPlan,
      credits: credits ?? this.credits,
      lastCreditRefresh: lastCreditRefresh ?? this.lastCreditRefresh,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      createdAt: createdAt ?? this.createdAt,
      isApproved: isApproved ?? this.isApproved,
      designerProfile: designerProfile ?? this.designerProfile,
      bio: bio ?? this.bio,
        
      // Onboarding fields
      onboardingStage: onboardingStage ?? this.onboardingStage,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      country: country ?? this.country,
      region: region ?? this.region,
      selectedOccasions: selectedOccasions ?? this.selectedOccasions,
      selectedCategories: selectedCategories ?? this.selectedCategories,
    );
  }

// --------------------------------------------------------------------------

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    // Safely parse date strings into DateTime objects
    DateTime? parseDate(String? dateStr) {
      return dateStr == null ? null : DateTime.tryParse(dateStr);
    }

    // Safely parse a dynamic value (which could be null or non-List) into a List<String>
    List<String> parseStringList(dynamic value) {
      if (value == null) return const [];
      // Supabase arrays often return as List<dynamic>
      if (value is List) {
          return value.map((e) => e.toString()).toList();
      }
      return const [];
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
      bio: map['bio'],

      // ------------------------------------------------------------------
      // 🎯 NEW ONBOARDING FIELDS MAPPED FROM SUPABASE (with defaults)
      // ------------------------------------------------------------------
      // These keys may not exist in the DB yet, so the '??' operator ensures safety.
      onboardingStage: map['setup_stage'] ?? 0,
      isSetupComplete: map['setup_complete'] ?? false,
      country: map['country'],
      region: map['region'],
      selectedOccasions: parseStringList(map['occasions']),
      selectedCategories: parseStringList(map['jewelry_categories']),
      // ------------------------------------------------------------------
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