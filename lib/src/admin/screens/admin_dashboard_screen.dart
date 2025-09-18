import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/admin_service.dart';
import 'package:fl_chart/fl_chart.dart'; // Ensure fl_chart is in your pubspec.yaml

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  late Future<Map<String, int>> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _adminService.getDashboardMetrics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5EF), // Background color from image
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Search Bar
          Container(
            width: 250,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search something...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_none_outlined), onPressed: () {}),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=3'), // Placeholder
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _metricsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading dashboard data'));
          }
          final metrics = snapshot.data ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricCards(metrics),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(flex: 3, child: DailyCreditsChart()),
                    const SizedBox(width: 24),
                    const Expanded(flex: 2, child: VisitorStatusChart()),
                  ],
                ),
                const SizedBox(height: 24),
                 Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Expanded(flex: 1, child: Column(
                       children: [
                         PendingAccountsCard(),
                         SizedBox(height: 24,),
                         PendingPostsCard()
                       ],
                     )),
                    const SizedBox(width: 24),
                    const Expanded(flex: 2, child: MembershipsChart()),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCards(Map<String, int> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 2.5,
          children: [
            _MetricCard(title: 'Total Users', value: metrics['totalUsers'].toString()),
            _MetricCard(title: 'Daily Active Users', value: metrics['dailyActiveUsers'].toString()),
            _MetricCard(title: 'Total Referrals', value: metrics['totalReferrals'].toString()),
            _MetricCard(title: 'Total Posts', value: metrics['totalPosts'].toString()),
          ],
        );
      },
    );
  }
}

// Reusable Metric Card matching the design
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  const _MetricCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F5EF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFC8A36A)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Placeholder for Daily Credits Chart
class DailyCreditsChart extends StatelessWidget {
  const DailyCreditsChart({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      height: 300,
      child: const Center(child: Text('Daily Credits Used Chart - Placeholder')),
    );
  }
}

// Placeholder for Visitor Status Chart
class VisitorStatusChart extends StatelessWidget {
  const VisitorStatusChart({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      height: 300,
      child: const Center(child: Text('Visitor Status Chart - Placeholder')),
    );
  }
}

// Placeholder for Memberships Chart
class MembershipsChart extends StatelessWidget {
  const MembershipsChart({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      height: 300,
      child: const Center(child: Text('Memberships Purchased Chart - Placeholder')),
    );
  }
}

// Placeholder for Pending B2B Accounts
class PendingAccountsCard extends StatelessWidget {
  const PendingAccountsCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      height: 138,
      child: const Center(child: Text('Pending B2B Accounts - Placeholder')),
    );
  }
}


// Placeholder for Pending Post Approvals
class PendingPostsCard extends StatelessWidget {
  const PendingPostsCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      height: 138,
      child: const Center(child: Text('Pending Post Approvals - Placeholder')),
    );
  }
}