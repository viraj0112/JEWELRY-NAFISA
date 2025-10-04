// lib/src/admin/sections/activity_logs_section.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
// FIX: Added 'as admin_service' to create a prefix for the import
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart'
    as admin_service;

class ActivityLogsSection extends StatelessWidget {
  const ActivityLogsSection({super.key});

  @override
  Widget build(BuildContext context) {
    // FIX: Used the prefix to specify which AdminService to use
    final admin_service.AdminService adminService =
        admin_service.AdminService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity Logs',
            style:
                GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Expanded(
          // FIX: Used the prefix to specify your custom Notification class
          child: StreamBuilder<List<admin_service.Notification>>(
            stream: adminService.getActivityLogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return const Center(
                  child: Text(
                    'No activity recorded yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return ListTile(
                    leading: const Icon(Icons.history, color: Colors.grey),
                    title: Text(log.message),
                    subtitle: Text(
                      DateFormat.yMMMd().add_jm().format(log.createdAt),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
