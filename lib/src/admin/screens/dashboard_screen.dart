import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/services/enhanced_admin_service.dart';
import 'package:jewelry_nafisa/src/admin/models/enhanced_admin_models.dart';
import 'package:jewelry_nafisa/src/admin/widgets/top_posts_widget.dart';
import 'package:jewelry_nafisa/src/admin/widgets/engagement_graph_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final EnhancedAdminService _adminService = EnhancedAdminService();
  late Future<DashboardMetrics> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _adminService.fetchDashboardMetrics();
  }

  @override
  void dispose() {
    _adminService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: FutureBuilder<DashboardMetrics>(
          future: _metricsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _metricsFuture = _adminService.fetchDashboardMetrics();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final metrics = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _metricsFuture = _adminService.fetchDashboardMetrics();
                });
              },
              child: ListView(
                children: [
                  const Text(
                    'Dashboard Overview',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _buildMetricsGrid(metrics),
                  const SizedBox(height: 24),
                  TopPerformingPostsWidget(posts: metrics.topPerformingPosts),
                  const SizedBox(height: 24),
                  EngagementGraphWidget(engagementData: metrics.engagementGraph),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(DashboardMetrics metrics) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard('Total Users', metrics.totalUsers.toString(), Icons.people, Colors.blue),
        _buildMetricCard('Members', metrics.totalMembers.toString(), Icons.star, Colors.green),
        _buildMetricCard('Total Posts', metrics.totalPosts.toString(), Icons.image, Colors.orange),
        _buildMetricCard('Credits Used', metrics.dailyCreditsUsed.toString(), Icons.star_border, Colors.purple),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
