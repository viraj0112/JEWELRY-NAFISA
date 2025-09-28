import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';

class DashboardSection extends StatefulWidget {
  const DashboardSection({super.key});

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  final AdminService _adminService = AdminService();
  Future<Map<String, dynamic>>? _metricsFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _adminService.getDashboardMetrics();
  }

  void _refreshData() {
    setState(() {
      _metricsFuture = _adminService.getDashboardMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Dashboard Overview',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            IconButton(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Data',
            ),
          ],
        ),
        const SizedBox(height: 24),
        FutureBuilder<Map<String, dynamic>>(
          future: _metricsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No metrics available.'));
            }
            final metrics = snapshot.data!;
            return MetricsGrid(
              totalUsers: metrics['totalUsers'],
              totalPosts: metrics['totalPosts'],
              creditsUsed: metrics['creditsUsed'],
              referrals: metrics['totalReferrals'],
            );
          },
        ),
        const SizedBox(height: 24),
        const ChartGrid(),
      ],
    );
  }
}