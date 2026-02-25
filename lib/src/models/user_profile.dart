import 'package:jewelry_nafisa/src/models/designer_profile.dart';
import 'package:jewelry_nafisa/src/models/manufacturer_profile.dart';

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
  final ManufacturerProfile? manufacturerProfile;
  final String? bio;
  final int age;
  // ------------------------------------------------------------------
  // 🎯 UPDATED ONBOARDING FIELDS
  // ------------------------------------------------------------------
  final int onboardingStage;
  final bool isSetupComplete;
  
  // NEW: Updated location fields
  final String? country;          // UPDATED - Now free text input             // UPDATED - Optional free text input
  final String? zipCode;          // NEW - ZIP/PIN code
  
  final List<String> selectedOccasions;
  final List<String> selectedCategories;
  // ------------------------------------------------------------------

  UserProfile({
    required this.id,
    this.username,
    this.fullName,
    this.email,
    this.birthdate,
    this.avatarUrl,
    this.gender,
    this.age = 0 ,
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
    this.manufacturerProfile,
    this.bio,
    // UPDATED: New location fields with safe defaults
    this.onboardingStage = 0,
    this.isSetupComplete = false,
    this.country,
    this.zipCode,
    this.selectedOccasions = const [],
    this.selectedCategories = const [],
  });

// --------------------------------------------------------------------------
// UPDATED: copyWith Method with new location fields
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
    ManufacturerProfile? manufacturerProfile,
    String? bio,
    // UPDATED: Onboarding fields with new location parameters
    int? onboardingStage,
    bool? isSetupComplete,
    String? continent,
    String? country,
    String? zipCode,
    List<String>? selectedOccasions,
    List<String>? selectedCategories,
    int? age
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
      manufacturerProfile: manufacturerProfile ?? this.manufacturerProfile,
      bio: bio ?? this.bio,
        
      // UPDATED: Onboarding fields with new location parameters
      onboardingStage: onboardingStage ?? this.onboardingStage,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      country: country ?? this.country,
      zipCode: zipCode ?? this.zipCode,
      selectedOccasions: selectedOccasions ?? this.selectedOccasions,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      age: age ?? this.age,
    );
  }

// --------------------------------------------------------------------------
// UPDATED: fromMap factory with new location fields
// --------------------------------------------------------------------------
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(String? dateStr) {
      return dateStr == null ? null : DateTime.tryParse(dateStr);
    }

    List<String> parseStringList(dynamic value) {
      if (value == null) return const [];
      if (value is List) {
          return value.map((e) => e.toString()).toList();
      }
      return const [];
    }

    // Handle both List (array) and Map (single object) formats
    DesignerProfile? _parseDesignerProfile(dynamic data) {
      if (data == null) return null;
      if (data is List && data.isNotEmpty) {
        return DesignerProfile.fromMap(data[0] as Map<String, dynamic>);
      }
      if (data is Map<String, dynamic>) {
        return DesignerProfile.fromMap(data);
      }
      return null;
    }

    ManufacturerProfile? _parseManufacturerProfile(dynamic data) {
      if (data == null) return null;
      if (data is List && data.isNotEmpty) {
        return ManufacturerProfile.fromMap(data[0] as Map<String, dynamic>);
      }
      if (data is Map<String, dynamic>) {
        return ManufacturerProfile.fromMap(data);
      }
      return null;
    }

    final designerProfileData = map['designer_profiles'];
    final manufacturerProfileData = map['manufacturer_profiles'];

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
      designerProfile: _parseDesignerProfile(designerProfileData),
      manufacturerProfile: _parseManufacturerProfile(manufacturerProfileData),
      bio: map['bio'],

      // ------------------------------------------------------------------
      // 🎯 UPDATED: New location fields mapped from Supabase
      // ------------------------------------------------------------------
      onboardingStage: map['setup_stage'] ?? 0,
      isSetupComplete: map['setup_complete'] ?? false,
      country: map['country'],
      zipCode: map['zip_code'],
      selectedOccasions: parseStringList(map['occasions']),
      selectedCategories: parseStringList(map['jewelry_categories']),
      age: map['age'] ?? 0,
      // ------------------------------------------------------------------
    );
  }
}

/// Enum to represent the different user roles in the system.
enum UserRole {
  admin,
  designer,
  member,
  manufacturer,
}

/// Converts a string from the database into a UserRole enum value.
UserRole userRoleFromString(String? role) {
  switch (role) {
    case 'admin':
      return UserRole.admin;
    case 'designer':
      return UserRole.designer;
    case 'manufacturer':
      return UserRole.manufacturer;
    case 'member':
    default:
      return UserRole.member;
  }
}