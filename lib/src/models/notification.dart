class Notification {
  final String id;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  Notification({
    required this.id,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'],
      message: map['message'],
      isRead: map['is_read'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}