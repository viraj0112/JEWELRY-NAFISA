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
  late final Stream<Map<String, dynamic>> _metricsStream;

  @override
  void initState() {
    super.initState();
    _metricsStream = _adminService.getDashboardMetricsStream();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        const Text('Dashboard Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        StreamBuilder<Map<String, dynamic>>(
          stream: _metricsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
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
              usersChange: metrics['usersChange'],
              totalPosts: metrics['totalPosts'],
              postsChange: metrics['postsChange'],
              creditsUsed: metrics['creditsUsed'],
              creditsChange: metrics['creditsChange'],
              referrals: metrics['totalReferrals'],
              referralsChange: metrics['referralsChange'],
            );
          },
        ),
        const SizedBox(height: 24),
        const ChartGrid(),
      ],
    );
  }
}
