class AdminQuote {
  final String id;
  final String userName;
  final bool isUserMember;
  final List<String> imageUrls;
  final String message;
  final String status; // Pending, Responded, Escalated
  final DateTime createdAt;

  AdminQuote({
    required this.id,
    required this.userName,
    required this.isUserMember,
    required this.imageUrls,
    required this.message,
    required this.status,
    required this.createdAt,
  });
}