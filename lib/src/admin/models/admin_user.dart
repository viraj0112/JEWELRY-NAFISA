class AdminUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool isMember;
  final int creditsRemaining;
  final String? avatarUrl;

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isMember,
    required this.creditsRemaining,
    this.avatarUrl,
  });

  factory AdminUser.fromMap(Map<String, dynamic> map) {
    return AdminUser(
      id: map['id'] ?? '',
      name: map['username'] ?? 'N/A',
      email: map['email'] ?? 'No Email',
      role: map['role'] ?? 'member',
      isMember: map['is_member'] ?? false,
      creditsRemaining: map['credits_remaining'] ?? 0,
      avatarUrl: map['avatar_url'],
    );
  }
}