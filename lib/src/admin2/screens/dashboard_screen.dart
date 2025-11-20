import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../models/dashboard_models.dart';
import '../providers/dashboard_provider.dart';
import '../utils/responsive.dart';
import '../widgets/admin_page_header.dart';
import '../widgets/analytics_widgets.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool isRealTimeMode = false;
  String selectedTimeRange = '7d';
  String selectedGeographicLevel = 'country';
  String geographicParentCode = '';

  @override
  void initState() {
    super.initState();
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(dashboardNotifierProvider.notifier)
          .loadData(timeRange: selectedTimeRange);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final isRealTime = ref.watch(dashboardRealTimeProvider);

    return Scaffold(
      body: dashboardAsync.when(
        loading: () => _buildLoadingState(),
        error: (err, stack) => _buildErrorState(err),
        data: (dashboard) => _buildDashboard(dashboard, isRealTime),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildKPISkeleton(),
          const SizedBox(height: 32),
          _buildChartsSkeleton(),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object err) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Failed to load dashboard: $err'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.refresh(dashboardDataProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(DashboardData dashboard, bool isRealTime) {
    final layout = AdminBreakpoints.of(context);
    return SingleChildScrollView(
      padding: AdminBreakpoints.pagePadding(layout),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildKPICards(dashboard.kpiMetrics),
          const SizedBox(height: 24),
          _buildRealtimeSnapshotRow(dashboard),
          const SizedBox(height: 24),
          _buildSectionPair(
            primary: _buildUserGrowthChart(dashboard.userGrowthData),
            secondary: _buildActivityHeatmap(dashboard.hourlyActivity),
          ),
          const SizedBox(height: 24),
          _buildSectionPair(
            primary: _buildGeographicWidget(dashboard.geographicData),
            secondary: _buildCategoryInsights(dashboard.categoryInsights),
            breakpoint: 1280,
          ),
          const SizedBox(height: 24),
          _buildSectionPair(
            primary: _buildTopPostsTable(dashboard.topPosts),
            secondary: _buildConversionFunnel(dashboard.conversionFunnel),
          ),
          const SizedBox(height: 24),
          _buildExportActions(),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildHeader() {
    return AdminPageHeader(
      title: 'Dashboard Overview',
      subtitle:
          'Real-time insights into platform performance and user engagement.',
      actions: [
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String>(
            value: selectedTimeRange,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: '1d', child: Text('Today')),
              DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
              DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
              DropdownMenuItem(value: 'custom', child: Text('Custom')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedTimeRange = value);
                ref.read(dashboardTimeRangeProvider.notifier).state = value;
              }
            },
          ),
        ),
        _buildLiveModeToggle(),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildLiveModeToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isRealTimeMode
            ? Theme.of(context).primaryColor.withOpacity(0.1)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRealTimeMode
              ? Theme.of(context).primaryColor.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 12,
            color: isRealTimeMode
                ? Theme.of(context).primaryColor
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2))
              .then()
              .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1)),
          const SizedBox(width: 8),
          Text(
            'Live Mode',
            style: TextStyle(
              color: isRealTimeMode
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: isRealTimeMode,
            onChanged: (value) {
              setState(() => isRealTimeMode = value);
              ref.read(dashboardRealTimeProvider.notifier).state = value;
            },
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildKPISkeleton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = constraints.maxWidth > 1200
            ? 6
            : constraints.maxWidth > 800
                ? 3
                : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: List.generate(6, (index) => _buildSkeletonCard()),
        );
      },
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 60,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1000.ms);
  }

  Widget _buildChartsSkeleton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 768;
        return isMobile
            ? Column(
                children: [
                  _buildSkeletonChart(),
                  const SizedBox(height: 24),
                  _buildSkeletonChart(),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSkeletonChart()),
                  const SizedBox(width: 24),
                  Expanded(child: _buildSkeletonChart()),
                ],
              );
      },
    );
  }

  Widget _buildSkeletonChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 200,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1000.ms);
  }

  Widget _buildKPICards(KPIMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = constraints.maxWidth > 1200
            ? 6
            : constraints.maxWidth > 800
                ? 3
                : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            MetricCard(
              title: 'Total Members',
              value: metrics.totalMembers.toString(),
              icon: FontAwesomeIcons.crown,
              color: Colors.purple,
              trend: metrics.membersGrowth > 0
                  ? '+${metrics.membersGrowth.toStringAsFixed(1)}%'
                  : '${metrics.membersGrowth.toStringAsFixed(1)}%',
              trendColor:
                  metrics.membersGrowth >= 0 ? Colors.green : Colors.red,
            ),
            MetricCard(
              title: 'Non-Members',
              value: metrics.totalNonMembers.toString(),
              icon: FontAwesomeIcons.users,
              color: Colors.blue,
              trend: metrics.nonMembersGrowth > 0
                  ? '+${metrics.nonMembersGrowth.toStringAsFixed(1)}%'
                  : '${metrics.nonMembersGrowth.toStringAsFixed(1)}%',
              trendColor:
                  metrics.nonMembersGrowth >= 0 ? Colors.green : Colors.red,
            ),
            MetricCard(
              title: 'Daily Active Users',
              value: metrics.dailyActiveUsers.toString(),
              icon: FontAwesomeIcons.userCheck,
              color: Colors.green,
              trend: metrics.dauGrowth > 0
                  ? '+${metrics.dauGrowth.toStringAsFixed(1)}%'
                  : '${metrics.dauGrowth.toStringAsFixed(1)}%',
              trendColor: metrics.dauGrowth >= 0 ? Colors.green : Colors.red,
            ),
            MetricCard(
              title: 'Credits Used Today',
              value: metrics.creditsUsedToday.toString(),
              icon: FontAwesomeIcons.coins,
              color: Colors.amber,
              trend: metrics.creditsGrowth > 0
                  ? '+${metrics.creditsGrowth.toStringAsFixed(1)}%'
                  : '${metrics.creditsGrowth.toStringAsFixed(1)}%',
              trendColor:
                  metrics.creditsGrowth >= 0 ? Colors.green : Colors.red,
            ),
            MetricCard(
              title: 'Total Referrals',
              value: metrics.totalReferrals.toString(),
              icon: FontAwesomeIcons.shareNodes,
              color: Colors.orange,
              trend: metrics.referralsGrowth > 0
                  ? '+${metrics.referralsGrowth.toStringAsFixed(1)}%'
                  : '${metrics.referralsGrowth.toStringAsFixed(1)}%',
              trendColor:
                  metrics.referralsGrowth >= 0 ? Colors.green : Colors.red,
            ),
            MetricCard(
              title: 'Posts Viewed Today',
              value: metrics.postsViewedToday.toString(),
              icon: FontAwesomeIcons.eye,
              color: Colors.teal,
              trend: metrics.viewsGrowth > 0
                  ? '+${metrics.viewsGrowth.toStringAsFixed(1)}%'
                  : '${metrics.viewsGrowth.toStringAsFixed(1)}%',
              trendColor: metrics.viewsGrowth >= 0 ? Colors.green : Colors.red,
            ),
          ],
        );
      },
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildRealtimeSnapshotRow(DashboardData dashboard) {
    final memberSpots = _buildSpots(
      dashboard.userGrowthData.map((e) => e.members.toDouble()).toList(),
    );
    final visitorSpots = _buildSpots(
      dashboard.userGrowthData.map((e) => e.nonMembers.toDouble()).toList(),
    );
    final activitySpots = _buildSpots(
      dashboard.hourlyActivity.map((e) => e.activityCount.toDouble()).toList(),
    );
    final peakHour = dashboard.hourlyActivity.isEmpty
        ? null
        : dashboard.hourlyActivity.reduce(
            (a, b) => a.activityCount >= b.activityCount ? a : b,
          );

    final cards = [
      _RealtimeSparklineCard(
        title: 'Member Momentum',
        subtitle: 'Trailing ${dashboard.userGrowthData.length}-day performance',
        primaryValue: dashboard.kpiMetrics.totalMembers.toString(),
        trendLabel: _formatTrend(dashboard.kpiMetrics.membersGrowth),
        trendColor:
            dashboard.kpiMetrics.membersGrowth >= 0 ? Colors.green : Colors.red,
        spots: memberSpots,
        gradient: const [Color(0xFF8b5cf6), Color(0xFFc026d3)],
        icon: FontAwesomeIcons.crown,
      ),
      _RealtimeSparklineCard(
        title: 'Peak Engagement',
        subtitle: 'Live hourly activity',
        primaryValue: peakHour != null ? '${peakHour.hour}:00' : '--',
        trendLabel: peakHour != null
            ? '${peakHour.activityCount} events'
            : 'Awaiting traffic',
        trendColor: Theme.of(context).colorScheme.primary,
        spots: activitySpots,
        gradient: const [Color(0xFF0ea5e9), Color(0xFF14b8a6)],
        icon: FontAwesomeIcons.clock,
      ),
      _RealtimeSparklineCard(
        title: 'Visitor Conversions',
        subtitle: 'Non-member journey',
        primaryValue: dashboard.kpiMetrics.totalNonMembers.toString(),
        trendLabel: _formatTrend(dashboard.kpiMetrics.nonMembersGrowth),
        trendColor: dashboard.kpiMetrics.nonMembersGrowth >= 0
            ? Colors.green
            : Colors.red,
        spots: visitorSpots,
        gradient: const [Color(0xFF6366f1), Color(0xFF22d3ee)],
        icon: FontAwesomeIcons.users,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        final horizontalSpacing = 16.0;
        final targetWidth = isCompact
            ? constraints.maxWidth
            : (constraints.maxWidth - (horizontalSpacing * 2)) / 3;
        return Wrap(
          spacing: horizontalSpacing,
          runSpacing: 16,
          children: cards
              .map(
                (card) => SizedBox(
                  width: targetWidth.clamp(240.0, double.infinity),
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildUserGrowthChart(List<UserGrowthData> growthData) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'User Growth Trend',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Members'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Non-Members'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= growthData.length)
                          return const Text('');
                        final date = growthData[value.toInt()].date;
                        return Text(
                          '${date.month}/${date.day}',
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                lineBarsData: [
                  // Members line
                  LineChartBarData(
                    spots: growthData.asMap().entries.map((entry) {
                      return FlSpot(
                          entry.key.toDouble(), entry.value.members.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: Colors.purple,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.purple.withOpacity(0.1),
                    ),
                    dotData: FlDotData(show: false),
                  ),
                  // Non-members line
                  LineChartBarData(
                    spots: growthData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(),
                          entry.value.nonMembers.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildActivityHeatmap(List<HourlyActivity> hourlyActivity) {
    final layout = AdminBreakpoints.of(context);
    final useLineChart = layout.isCompact || hourlyActivity.length <= 8;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Usage Pattern',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Platform activity distribution by hour',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: useLineChart ? 220 : 200,
            child: useLineChart
                ? _buildActivitySparkline(hourlyActivity)
                : _buildActivityBarChart(hourlyActivity),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0);
  }

  Color _getActivityColor(int count) {
    if (count > 50) return Colors.green.shade400;
    if (count > 25) return Colors.amber.shade400;
    return Colors.red.shade400;
  }

  Widget _buildActivityBarChart(List<HourlyActivity> hourlyActivity) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: hourlyActivity.isNotEmpty
            ? hourlyActivity
                    .map((h) => h.activityCount)
                    .reduce((a, b) => a > b ? a : b)
                    .toDouble() *
                1.2
            : 100,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.white,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final activity = hourlyActivity[groupIndex];
              return BarTooltipItem(
                '${activity.hour}:00 - ${activity.activityCount} activities',
                const TextStyle(color: Colors.black),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= hourlyActivity.length) {
                  return const Text('');
                }
                return Text(
                  '${hourlyActivity[value.toInt()].hour}',
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
            dashArray: const [5, 5],
          ),
        ),
        barGroups: hourlyActivity.asMap().entries.map((entry) {
          final index = entry.key;
          final activity = entry.value;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: activity.activityCount.toDouble(),
                color: _getActivityColor(activity.activityCount),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivitySparkline(List<HourlyActivity> hourlyActivity) {
    final spots = _buildSpots(
        hourlyActivity.map((e) => e.activityCount.toDouble()).toList());
    if (spots.isEmpty) {
      return const Center(child: Text('No activity data yet'));
    }
    final colors = [const Color(0xFF0ea5e9), const Color(0xFF10b981)];
    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text('${value.toInt()}',
                  style: const TextStyle(fontSize: 11)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= hourlyActivity.length) {
                  return const Text('');
                }
                final hour = hourlyActivity[value.toInt()].hour;
                return Text('$hour', style: const TextStyle(fontSize: 11));
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(colors: colors),
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: colors
                    .map((color) => color.withValues(alpha: 0.12))
                    .toList(),
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeographicWidget(GeographicData geoData) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Geographic Distribution',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Row(
                children: [
                  if (geographicParentCode.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        // Navigate back logic
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: selectedGeographicLevel,
                    items: const [
                      DropdownMenuItem(
                          value: 'country', child: Text('Country')),
                      DropdownMenuItem(value: 'state', child: Text('State')),
                      DropdownMenuItem(value: 'city', child: Text('City')),
                      DropdownMenuItem(
                          value: 'pincode', child: Text('Pincode')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedGeographicLevel = value);
                        ref.read(geographicLevelProvider.notifier).state =
                            value;
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          geoData.items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Text('No geographic data available'),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = AdminBreakpoints.columnsForWidth(
                      constraints.maxWidth,
                      min: 1,
                      max: 4,
                      idealItemWidth: 260,
                    );
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2,
                      ),
                      itemCount: geoData.items.length,
                      itemBuilder: (context, index) {
                        final item = geoData.items[index];
                        return InkWell(
                          onTap: () {
                            // Drill down logic
                            setState(() => geographicParentCode = item.code);
                            ref.read(geographicParentProvider.notifier).state =
                                item.code;
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${item.userCount} users',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          '${item.percentage.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          item.isGrowing
                                              ? Icons.trending_up
                                              : Icons.trending_down,
                                          size: 16,
                                          color: item.isGrowing
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: item.percentage / 100,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    item.isGrowing
                                        ? Colors.green.shade400
                                        : Colors.blue.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ],
      ),
    ).animate().fadeIn(duration: 900.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildCategoryInsights(List<CategoryInsight> categories) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Insights',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 24),
          ExpansionPanelList(
            expansionCallback: (int index, bool isExpanded) {
              setState(() {
                categories[index] = categories[index]; // Trigger rebuild
              });
            },
            children: categories.map((category) {
              return ExpansionPanel(
                headerBuilder: (BuildContext context, bool isExpanded) {
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.category,
                        color: category.color,
                      ),
                    ),
                    title: Text(
                      category.category,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${category.totalPins} pins • ${category.totalImages} images',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${category.growthPercentage > 0 ? '+' : ''}${category.growthPercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: category.growthPercentage >= 0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          category.growthPercentage >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: category.growthPercentage >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ],
                    ),
                  );
                },
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Top posts for this category
                      ...category.topPosts.map((post) {
                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.image),
                          ),
                          title: Text(post.title),
                          subtitle: Text(
                              '${post.views} views • ${post.unlocks} unlocks'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(Icons.share),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 1000.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildTopPostsTable(List<TopPost> posts) {
    final isCompact = MediaQuery.sizeOf(context).width < 860;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Performing Posts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Row(
                children: [
                  DropdownButton<String>(
                    value: 'views',
                    items: const [
                      DropdownMenuItem(
                          value: 'views', child: Text('Sort by Views')),
                      DropdownMenuItem(
                          value: 'unlocks', child: Text('Sort by Unlocks')),
                      DropdownMenuItem(
                          value: 'saves', child: Text('Sort by Saves')),
                      DropdownMenuItem(
                          value: 'shares', child: Text('Sort by Shares')),
                    ],
                    onChanged: (value) {
                      // Sort logic
                    },
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: 'today',
                    items: const [
                      DropdownMenuItem(value: 'today', child: Text('Today')),
                      DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
                      DropdownMenuItem(
                          value: '30d', child: Text('Last 30 days')),
                    ],
                    onChanged: (value) {
                      // Filter logic
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isCompact)
            _buildTopPostsCards(posts)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                columns: const [
                  DataColumn(
                      label: Text('Post',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(
                      label: Text('Category',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(
                      label: Text('Views',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(
                      label: Text('Unlocks',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(
                      label: Text('Saves',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(
                      label: Text('Shares',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(
                      label: Text('Date',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(
                      label: Text('Actions',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                ],
                rows: posts.map((post) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.image),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 200,
                              child: Text(
                                post.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            post.category,
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(post.views.toString())),
                      DataCell(Text(post.unlocks.toString())),
                      DataCell(Text(post.saves.toString())),
                      DataCell(Text(post.shares.toString())),
                      DataCell(Text(
                          '${post.date.month}/${post.date.day}/${post.date.year}')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, size: 16),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.share, size: 16),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.link, size: 16),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 1100.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildTopPostsCards(List<TopPost> posts) {
    if (posts.isEmpty) {
      return const Text('No post data available right now');
    }
    return Column(
      children: posts.map((post) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                post.category,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetricChip(
                    label: 'Views',
                    value: post.views,
                    color: Colors.blue.shade600,
                    icon: Icons.visibility,
                  ),
                  _buildMetricChip(
                    label: 'Unlocks',
                    value: post.unlocks,
                    color: Colors.orange.shade600,
                    icon: Icons.lock_open,
                  ),
                  _buildMetricChip(
                    label: 'Saves',
                    value: post.saves,
                    color: Colors.purple.shade600,
                    icon: Icons.bookmark_added,
                  ),
                  _buildMetricChip(
                    label: 'Shares',
                    value: post.shares,
                    color: Colors.green.shade600,
                    icon: Icons.share,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Updated ${post.date.month}/${post.date.day}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Chip(
      avatar: Icon(
        icon,
        size: 14,
        color: color,
      ),
      label: Text('$value $label'),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildConversionFunnel(ConversionFunnel funnel) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Conversion Funnel',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.list),
                    label: const Text('List View'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Chart View'),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: '7d',
                    items: const [
                      DropdownMenuItem(value: '1d', child: Text('Today')),
                      DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
                      DropdownMenuItem(
                          value: '30d', child: Text('Last 30 days')),
                    ],
                    onChanged: (value) {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...[
            funnel.signups,
            funnel.firstLogin,
            funnel.creditUse,
            funnel.membership,
          ].asMap().entries.map((entry) {
            final index = entry.key;
            final stage = entry.value;
            final isFirst = index == 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stage.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Row(
                        children: [
                          Text(
                            '${stage.users} users',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${stage.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!isFirst) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: stage.changeFromPrevious >= 0
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${stage.changeFromPrevious >= 0 ? '+' : ''}${stage.changeFromPrevious.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: stage.changeFromPrevious >= 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (stage.percentage / 100).clamp(0.0, 1.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 1000),
                        decoration: BoxDecoration(
                          color: _getFunnelColor(index),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '${stage.users} users',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    ).animate().fadeIn(duration: 1200.ms).slideY(begin: 0.2, end: 0);
  }

  Color _getFunnelColor(int index) {
    const colors = [
      Color(0xFF8b5cf6), // Purple
      Color(0xFF06b6d4), // Cyan
      Color(0xFF10b981), // Green
      Color(0xFFf59e0b), // Amber
    ];
    return colors[index % colors.length];
  }

  Widget _buildSectionPair({
    required Widget primary,
    required Widget secondary,
    double breakpoint = 1100,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > breakpoint;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: primary),
              const SizedBox(width: 24),
              Expanded(child: secondary),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            primary,
            const SizedBox(height: 24),
            secondary,
          ],
        );
      },
    );
  }

  Widget _buildExportActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export Dashboard',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Download dashboard data in various formats',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _exportData('csv'),
                icon: const Icon(Icons.file_download),
                label: const Text('CSV'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _exportData('pdf'),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _exportData('png'),
                icon: const Icon(Icons.image),
                label: const Text('PNG'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 1300.ms).slideY(begin: 0.2, end: 0);
  }

  void _exportData(String format) {
    // Export logic - simplified for now
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting as $format...')),
    );
  }

  List<FlSpot> _buildSpots(List<double> values) {
    if (values.isEmpty) return [];
    return List<FlSpot>.generate(
      values.length,
      (index) => FlSpot(index.toDouble(), values[index]),
    );
  }

  String _formatTrend(double value) {
    final formatted = value.toStringAsFixed(1);
    return value >= 0 ? '+$formatted%' : '$formatted%';
  }
}

class _RealtimeSparklineCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String primaryValue;
  final String trendLabel;
  final Color trendColor;
  final List<FlSpot> spots;
  final List<Color> gradient;
  final IconData icon;

  const _RealtimeSparklineCard({
    required this.title,
    required this.subtitle,
    required this.primaryValue,
    required this.trendLabel,
    required this.trendColor,
    required this.spots,
    required this.gradient,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = spots.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: gradient.first),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                primaryValue,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trendLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: trendColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: hasData
                ? LineChart(
                    LineChartData(
                      titlesData: FlTitlesData(show: false),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          gradient: LinearGradient(colors: gradient),
                          barWidth: 3,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: gradient
                                  .map(
                                    (color) => color.withValues(alpha: 0.12),
                                  )
                                  .toList(),
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Text(
                      'Not enough data yet',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
