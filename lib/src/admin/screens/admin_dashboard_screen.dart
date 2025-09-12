import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/admin_service.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminService adminService = AdminService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: false,
      ),
      body: FutureBuilder<Map<String, int>>(
        future: adminService.getDashboardSummary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading data'));
          }
          final summary = snapshot.data ?? {};
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                StatCard(
                  title: 'Today\'s Quotes',
                  value: (summary['todaysQuotes'] ?? 0).toString(),
                  icon: Icons.request_quote,
                  color: Colors.blue,
                ),
                StatCard(
                  title: 'New User Signups',
                  value: (summary['newSignups'] ?? 0).toString(),
                  icon: Icons.person_add,
                  color: Colors.green,
                ),
                StatCard(
                  title: 'Pending Approvals',
                  value: (summary['pendingApprovals'] ?? 0).toString(),
                  icon: Icons.pending_actions,
                  color: Colors.orange,
                ),
                const StatCard(
                  title: 'Most Viewed Item',
                  value: 'Classic Ring #102',
                  icon: Icons.trending_up,
                  color: Colors.purple,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}