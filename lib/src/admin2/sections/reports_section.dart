// Reports Section
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../models/reports_models.dart';
import '../providers/reports_provider.dart';
import '../services/reports_service.dart';
import '../widgets/admin_page_header.dart';
import '../widgets/analytics_widgets.dart';

class ReportsSection extends ConsumerStatefulWidget {
  const ReportsSection({super.key});

  @override
  ConsumerState<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends ConsumerState<ReportsSection> {
  // State
  bool isExporting = false;
  bool isGeneratingReport = false;
  int selectedTab = 0;
  String selectedDateRange = '30d';

  // Custom Report Dialog State
  final GlobalKey<FormState> _customReportFormKey = GlobalKey<FormState>();
  String selectedReportType = 'platform';
  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();
  List<String> selectedMetrics = [];
  String selectedFormat = 'pdf';

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(reportsDataProvider);

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) {
        _showErrorSnackBar('Failed to load reports data: $err');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading reports: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(reportsDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
      data: (reports) => Scaffold(
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildOverviewCards(reports.overview),
                  const SizedBox(height: 32),
                  _buildReportsTabs(reports),
                ],
              ),
            ),
            if (isGeneratingReport) _buildCustomReportDialog(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AdminPageHeader(
      title: 'Reports Dashboard',
      subtitle: 'Generate and download comprehensive analytics reports.',
      actions: [
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String>(
            value: selectedDateRange,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
              DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
              DropdownMenuItem(value: '90d', child: Text('Last 90 days')),
              DropdownMenuItem(value: 'custom', child: Text('Custom')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedDateRange = value);
              }
            },
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => setState(() => isGeneratingReport = true),
          icon: const Icon(FontAwesomeIcons.plus, size: 16),
          label: const Text('Generate Report'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildOverviewCards(ReportOverview overview) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 768
                ? 2
                : 1;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.5,
          children: [
            MetricCard(
              title: 'Total Reports Generated',
              value: overview.totalReportsGenerated.toString(),
              icon: FontAwesomeIcons.fileAlt,
              color: Colors.blue,
            ),
            MetricCard(
              title: 'Downloads This Month',
              value: overview.downloadsThisMonth.toString(),
              icon: FontAwesomeIcons.download,
              color: Colors.green,
            ),
            MetricCard(
              title: 'Average File Size',
              value: '${overview.averageFileSize} MB',
              icon: FontAwesomeIcons.hdd,
              color: Colors.orange,
            ),
            MetricCard(
              title: 'Reports Available',
              value: '12', // Mock data
              icon: FontAwesomeIcons.database,
              color: Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportsTabs(
      ({
        ReportOverview overview,
        PlatformReportSummary platformSummary,
        List<PlatformGrowthData> platformGrowth,
        List<PlatformPerformanceMetric> platformMetrics,
        List<UserGrowthData> userGrowth,
        List<AvailableUserReport> userReports,
        List<ContentReport> contentReports,
      }) reports) {
    return CustomCard(
      child: Column(
        children: [
          CustomTabBar(
            tabs: const ['Platform Reports', 'User Reports', 'Content Reports'],
            selectedIndex: selectedTab,
            onTabChanged: (index) => setState(() => selectedTab = index),
          ),
          const SizedBox(height: 24),
          _buildTabContent(reports),
        ],
      ),
    );
  }

  Widget _buildTabContent(
      ({
        ReportOverview overview,
        PlatformReportSummary platformSummary,
        List<PlatformGrowthData> platformGrowth,
        List<PlatformPerformanceMetric> platformMetrics,
        List<UserGrowthData> userGrowth,
        List<AvailableUserReport> userReports,
        List<ContentReport> contentReports,
      }) reports) {
    switch (selectedTab) {
      case 0:
        return _buildPlatformReportsTab(reports.platformSummary,
            reports.platformGrowth, reports.platformMetrics);
      case 1:
        return _buildUserReportsTab(reports.userGrowth, reports.userReports);
      case 2:
        return _buildContentReportsTab(reports.contentReports);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPlatformReportsTab(
      PlatformReportSummary summary,
      List<PlatformGrowthData> growthData,
      List<PlatformPerformanceMetric> metrics) {
    return Column(
      children: [
        // Summary Stats Cards
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Total Sales',
                value: '\$${summary.totalSales.formatted}',
                icon: FontAwesomeIcons.dollarSign,
                color: Colors.green,
                subtitle: '↗12%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: MetricCard(
                title: 'Active Users',
                value: summary.activeUsers.formatted,
                icon: FontAwesomeIcons.users,
                color: Colors.blue,
                subtitle: '↗8%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Platform Growth Overview Chart
        _buildPlatformGrowthChart(growthData),
        const SizedBox(height: 32),

        // Platform Performance Metrics Table
        _buildPlatformPerformanceTable(metrics),
      ],
    );
  }

  Widget _buildPlatformGrowthChart(List<PlatformGrowthData> growthData) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Platform Growth Overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(FontAwesomeIcons.calendar, size: 16),
                    label: const Text('Today'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: isExporting
                        ? null
                        : () => _exportPlatformGrowthData('csv'),
                    icon: isExporting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(FontAwesomeIcons.download, size: 16),
                    label: const Text('CSV'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: isExporting
                        ? null
                        : () => _exportPlatformGrowthData('pdf'),
                    icon: isExporting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(FontAwesomeIcons.download, size: 16),
                    label: const Text('PDF'),
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
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= growthData.length)
                          return const Text('');
                        final data = growthData[value.toInt()];
                        return Text(
                          '${data.date.month}/${data.date.day}',
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: growthData.asMap().entries.map((entry) {
                      return FlSpot(
                          entry.key.toDouble(), entry.value.users.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 2,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.3),
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withOpacity(0.3),
                          Colors.blue.withOpacity(0.1)
                        ],
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: growthData.asMap().entries.map((entry) {
                      return FlSpot(
                          entry.key.toDouble(), entry.value.posts.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 2,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withOpacity(0.3),
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.3),
                          Colors.green.withOpacity(0.1)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Users', Colors.blue),
              const SizedBox(width: 24),
              _buildLegendItem('Posts', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildPlatformPerformanceTable(
      List<PlatformPerformanceMetric> metrics) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Platform Performance Metrics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: isExporting
                        ? null
                        : () => _exportPlatformMetrics('csv'),
                    icon: isExporting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(FontAwesomeIcons.download, size: 16),
                    label: const Text('CSV'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: isExporting
                        ? null
                        : () => _exportPlatformMetrics('excel'),
                    icon: isExporting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(FontAwesomeIcons.download, size: 16),
                    label: const Text('Excel'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
              columns: const [
                DataColumn(
                    label: Text('Month',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Total Users',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Posts Created',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Engagement Score',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Growth Rate',
                        style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              rows: metrics.map((metric) {
                return DataRow(
                  cells: [
                    DataCell(Text(metric.month)),
                    DataCell(Text(metric.totalUsers.toString())),
                    DataCell(Text(metric.postsCreated.toString())),
                    DataCell(
                      Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: LinearProgressIndicator(
                              value: metric.engagementScore / 100,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                metric.engagementScore > 70
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${metric.engagementScore.toStringAsFixed(1)}%'),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        '${metric.growthRate >= 0 ? '+' : ''}${metric.growthRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: metric.growthRate >= 0
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserReportsTab(
      List<UserGrowthData> growthData, List<AvailableUserReport> reports) {
    return Column(
      children: [
        // Summary Stats (same as platform)
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Total Sales',
                value: '\$425K',
                icon: FontAwesomeIcons.dollarSign,
                color: Colors.green,
                subtitle: '↗12%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: MetricCard(
                title: 'Active Users',
                value: '18.2K',
                icon: FontAwesomeIcons.users,
                color: Colors.blue,
                subtitle: '↗8%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // User Growth Analysis Chart
        _buildUserGrowthChart(growthData),
        const SizedBox(height: 32),

        // Available User Reports Table
        _buildUserReportsTable(reports),
      ],
    );
  }

  Widget _buildUserGrowthChart(List<UserGrowthData> growthData) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Growth Analysis',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: growthData.isNotEmpty
                    ? growthData
                            .map((d) => d.activeUsers.toDouble())
                            .reduce((a, b) => a > b ? a : b) *
                        1.2
                    : 1000,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final data = growthData[groupIndex];
                      return BarTooltipItem(
                        '${data.date.month}/${data.date.day}\n${rod.toY.toInt()} users',
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
                        if (value.toInt() >= growthData.length)
                          return const Text('');
                        final data = growthData[value.toInt()];
                        return Text(
                          '${data.date.month}/${data.date.day}',
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                barGroups: growthData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: data.newUsers.toDouble(),
                        color: Colors.blue,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: data.activeUsers.toDouble(),
                        color: Colors.green,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('New Users', Colors.blue),
              const SizedBox(width: 24),
              _buildLegendItem('Active Users', Colors.green),
              const SizedBox(width: 24),
              _buildLegendItem('Churn Rate', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserReportsTable(List<AvailableUserReport> reports) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available User Reports',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
              columns: const [
                DataColumn(
                    label: Text('Report Name',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Type',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Generated Date',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Downloads',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('File Size',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Format',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Actions',
                        style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              rows: reports.map((report) {
                return DataRow(
                  cells: [
                    DataCell(Text(report.name)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          report.type,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(
                      '${report.generatedDate.month}/${report.generatedDate.day}/${report.generatedDate.year}',
                    )),
                    DataCell(Text(report.downloadCount.toString())),
                    DataCell(Text('${report.fileSize} MB')),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          report.format.toUpperCase(),
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(FontAwesomeIcons.download, size: 16),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentReportsTab(List<ContentReport> reports) {
    return Column(
      children: [
        // Summary Stats (similar structure)
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Total Content',
                value: '2.4K',
                icon: FontAwesomeIcons.images,
                color: Colors.purple,
                subtitle: '↗15%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: MetricCard(
                title: 'Engagement Rate',
                value: '8.7%',
                icon: FontAwesomeIcons.chartLine,
                color: Colors.orange,
                subtitle: '↗5%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Content Reports Table (similar to user reports)
        CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Content Reports',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      MaterialStateProperty.all(Colors.grey.shade50),
                  columns: const [
                    DataColumn(
                        label: Text('Report Name',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(
                        label: Text('Type',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(
                        label: Text('Generated Date',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(
                        label: Text('Downloads',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(
                        label: Text('File Size',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(
                        label: Text('Format',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(
                        label: Text('Actions',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                  ],
                  rows: reports.map((report) {
                    return DataRow(
                      cells: [
                        DataCell(Text(report.name)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              report.type,
                              style: TextStyle(
                                color: Colors.purple.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(
                          '${report.generatedDate.month}/${report.generatedDate.day}/${report.generatedDate.year}',
                        )),
                        DataCell(Text(report.downloadCount.toString())),
                        DataCell(Text('${report.fileSize} MB')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              report.format.toUpperCase(),
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon:
                                const Icon(FontAwesomeIcons.download, size: 16),
                            label: const Text('Download'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomReportDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generate Custom Report',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure your custom analytics report',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ),
      content: Form(
        key: _customReportFormKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Report Type Selector
              DropdownButtonFormField<String>(
                value: selectedReportType,
                decoration: const InputDecoration(
                  labelText: 'Report Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'platform', child: Text('Platform Report')),
                  DropdownMenuItem(value: 'users', child: Text('User Report')),
                  DropdownMenuItem(
                      value: 'content', child: Text('Content Report')),
                  DropdownMenuItem(
                      value: 'custom', child: Text('Custom Report')),
                ],
                onChanged: (value) =>
                    setState(() => selectedReportType = value!),
                validator: (value) =>
                    value == null ? 'Please select a report type' : null,
              ),
              const SizedBox(height: 16),

              // Date Range Selector
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text:
                            '${startDate.month}/${startDate.day}/${startDate.year}',
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => startDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: '${endDate.month}/${endDate.day}/${endDate.year}',
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => endDate = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Metrics Checkboxes
              const Text('Metrics to Include:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetricCheckbox('User Growth'),
                  _buildMetricCheckbox('Engagement'),
                  _buildMetricCheckbox('Content Stats'),
                  _buildMetricCheckbox('B2B Metrics'),
                  _buildMetricCheckbox('Referrals'),
                  _buildMetricCheckbox('Revenue'),
                ],
              ),
              const SizedBox(height: 16),

              // Format Selector
              DropdownButtonFormField<String>(
                value: selectedFormat,
                decoration: const InputDecoration(
                  labelText: 'Export Format',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                  DropdownMenuItem(value: 'excel', child: Text('Excel')),
                  DropdownMenuItem(value: 'csv', child: Text('CSV')),
                ],
                onChanged: (value) => setState(() => selectedFormat = value!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => isGeneratingReport = false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _generateCustomReport,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Generate Report'),
        ),
      ],
    );
  }

  Widget _buildMetricCheckbox(String metric) {
    return FilterChip(
      label: Text(metric),
      selected: selectedMetrics.contains(metric),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            selectedMetrics.add(metric);
          } else {
            selectedMetrics.remove(metric);
          }
        });
      },
    );
  }

  void _generateCustomReport() {
    if (_customReportFormKey.currentState!.validate()) {
      if (selectedMetrics.isEmpty) {
        _showErrorSnackBar('Please select at least one metric');
        return;
      }

      final config = CustomReportConfig(
        reportType: selectedReportType,
        startDate: startDate,
        endDate: endDate,
        metrics: selectedMetrics,
        format: selectedFormat,
      );

      // Generate report
      ref.read(generateCustomReportProvider(config).future).then((success) {
        if (success) {
          _showSuccessSnackBar('Custom report generated successfully!');
          setState(() => isGeneratingReport = false);
          // Reset form
          _customReportFormKey.currentState!.reset();
          selectedMetrics.clear();
        } else {
          _showErrorSnackBar('Failed to generate custom report');
        }
      });
    }
  }

  Future<void> _exportPlatformGrowthData(String format) async {
    try {
      setState(() => isExporting = true);
      final reports = await ref.read(reportsDataProvider.future);
      final url = await ReportsService.exportPlatformGrowthData(
          reports.platformGrowth, format);
      _showSuccessSnackBar('Platform growth data exported successfully!');
      // In a real app, you might open the URL or download the file
      debugPrint('Export URL: $url');
    } catch (e) {
      _showErrorSnackBar('Failed to export platform growth data: $e');
    } finally {
      setState(() => isExporting = false);
    }
  }

  Future<void> _exportUserGrowthData(String format) async {
    try {
      setState(() => isExporting = true);
      final reports = await ref.read(reportsDataProvider.future);
      final url =
          await ReportsService.exportUserGrowthData(reports.userGrowth, format);
      _showSuccessSnackBar('User growth data exported successfully!');
      debugPrint('Export URL: $url');
    } catch (e) {
      _showErrorSnackBar('Failed to export user growth data: $e');
    } finally {
      setState(() => isExporting = false);
    }
  }

  Future<void> _exportPlatformMetrics(String format) async {
    try {
      setState(() => isExporting = true);
      final reports = await ref.read(reportsDataProvider.future);
      final url = await ReportsService.exportPlatformPerformanceMetrics(
          reports.platformMetrics, format);
      _showSuccessSnackBar('Platform metrics exported successfully!');
      debugPrint('Export URL: $url');
    } catch (e) {
      _showErrorSnackBar('Failed to export platform metrics: $e');
    } finally {
      setState(() => isExporting = false);
    }
  }

  Future<void> _exportUserReports(String format) async {
    try {
      setState(() => isExporting = true);
      final reports = await ref.read(reportsDataProvider.future);
      final url = await ReportsService.exportAvailableUserReports(
          reports.userReports, format);
      _showSuccessSnackBar('User reports exported successfully!');
      debugPrint('Export URL: $url');
    } catch (e) {
      _showErrorSnackBar('Failed to export user reports: $e');
    } finally {
      setState(() => isExporting = false);
    }
  }

  Future<void> _exportContentReports(String format) async {
    try {
      setState(() => isExporting = true);
      final reports = await ref.read(reportsDataProvider.future);
      final url = await ReportsService.exportContentReports(
          reports.contentReports, format);
      _showSuccessSnackBar('Content reports exported successfully!');
      debugPrint('Export URL: $url');
    } catch (e) {
      _showErrorSnackBar('Failed to export content reports: $e');
    } finally {
      setState(() => isExporting = false);
    }
  }
}
