import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jewelry_nafisa/src/admin/admin_service.dart';
import 'package:jewelry_nafisa/src/admin/widgets/metric_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<Map<String, int>>(
        stream: _adminService.getDashboardMetrics(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
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
                    Expanded(
                      flex: 2,
                      child: VisitorStatusChart(
                        dailyTotal: metrics['dailyActiveUsers'] ?? 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          QuickAlertCard(
                            title: "Pending B2B Accounts",
                            value: "34",
                            date: "Last Reply Date - 23/2/24",
                          ),
                          SizedBox(height: 24),
                          QuickAlertCard(
                            title: "Pending Post Approvals",
                            value: "346",
                            date: "Last Approval Date - 23/2/24",
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 24),
                    Expanded(flex: 2, child: MembershipsChart()),
                  ],
                ),
              ],
            ).animate().fadeIn(duration: 500.ms),
          );
        },
      ),
    );
  }

  Widget _buildMetricCards(Map<String, int> metrics) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      childAspectRatio: 2.2,
      children: [
        MetricCard(
          title: 'Total Users',
          value: metrics['totalUsers']?.toString() ?? '0',
          icon: Icons.people_alt_outlined,
        ),
        MetricCard(
          title: 'Daily Active Users',
          value: metrics['dailyActiveUsers']?.toString() ?? '0',
          icon: Icons.person_pin_circle_outlined,
        ),
        MetricCard(
          title: 'Total Referrals',
          value: metrics['totalReferrals']?.toString() ?? '0',
          icon: Icons.share_outlined,
        ),
        MetricCard(
          title: 'Total Posts',
          value: metrics['totalPosts']?.toString() ?? '0',
          icon: Icons.article_outlined,
        ),
      ],
    );
  }
}

// --- DASHBOARD WIDGETS ---

class QuickAlertCard extends StatelessWidget {
  final String title;
  final String value;
  final String date;

  const QuickAlertCard({
    super.key,
    required this.title,
    required this.value,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            date,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DailyCreditsChart extends StatelessWidget {
  const DailyCreditsChart({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Daily Credits Used", style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        DateFormat('MMM').format(DateTime(0, value.toInt())),
                      ),
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  12,
                  (index) => BarChartGroupData(
                    x: index + 1,
                    barRods: [
                      BarChartRodData(
                        toY: (index == 4)
                            ? 70
                            : (index % 5 + 1) * 15.0, // May has high value
                        color: (index == 4)
                            ? theme.colorScheme.primary
                            : Colors.grey[300],
                        width: 15,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VisitorStatusChart extends StatelessWidget {
  final int dailyTotal;
  const VisitorStatusChart({super.key, required this.dailyTotal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text("Visitor Status", style: theme.textTheme.titleLarge),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 60,
                sections: [
                  PieChartSectionData(
                    value: 60,
                    color: Colors.teal[300],
                    title: '60%',
                    radius: 25,
                  ),
                  PieChartSectionData(
                    value: 25,
                    color: Colors.orange[300],
                    title: '25%',
                    radius: 25,
                  ),
                  PieChartSectionData(
                    value: 15,
                    color: Colors.blue[300],
                    title: '15%',
                    radius: 25,
                  ),
                ],
              ),
            ),
          ),
          Text("Daily total: $dailyTotal", style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class MembershipsChart extends StatelessWidget {
  const MembershipsChart({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Membership's Purchased", style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3),
                      FlSpot(2, 2),
                      FlSpot(4, 5),
                      FlSpot(6, 3.1),
                      FlSpot(8, 4),
                      FlSpot(9.5, 3),
                      FlSpot(11, 4),
                    ],
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 5,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
