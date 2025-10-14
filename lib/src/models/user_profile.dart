class UserProfile {
  final String id;
  final String email;
  final String? username;
  final String role;
  final bool? isApproved;
  final int credits;
  final String? referralCode;
  final String? avatarUrl;
  final bool isMember;
  final String? phone;
  final String? birthdate;
  final String? gender;

  UserProfile({
    required this.id,
    required this.email,
    this.username,
    required this.role,
    this.isApproved,
    required this.credits,
    this.referralCode,
    this.avatarUrl,
    required this.isMember,
    this.phone,
    this.birthdate,
    this.gender,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      username: map['username'],
      role: map['role'] ?? 'member',
      isApproved: map['is_approved'],
      credits: map['credits_remaining'] ?? 0,
      referralCode: map['referral_code'],
      avatarUrl: map['avatar_url'],
      isMember: map['is_member'] ?? false,
      phone: map['phone'],
      birthdate: map['birthdate'],
      gender: map['gender'],
    );
  }
}