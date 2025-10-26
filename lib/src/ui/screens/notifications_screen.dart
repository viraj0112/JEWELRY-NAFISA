import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jewelry_nafisa/src/models/notification.dart' as app;
import 'package:jewelry_nafisa/src/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Updates & Activity'),
        centerTitle: false,
      ),
      body: StreamBuilder<List<app.Notification>>(
        stream: _notificationService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'No new updates yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                leading: Icon(
                  notification.isRead
                      ? Icons.notifications_none_outlined
                      : Icons.notifications_active,
                  color: notification.isRead
                      ? Colors.grey
                      : Theme.of(context).primaryColor,
                ),
                title: Text(
                  notification.message,
                  style: TextStyle(
                    fontWeight: notification.isRead
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  DateFormat.yMMMd().add_jm().format(notification.createdAt),
                ),
                trailing: !notification.isRead
                    ? TextButton(
                        onPressed: () =>
                            _notificationService.markAsRead(notification.id),
                        child: const Text('Mark as Read'),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
