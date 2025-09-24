import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/metric_card.dart';
import '../widgets/chart_card.dart';
import '../widgets/geo_map_widget.dart';
import '../widgets/conversion_funnel_widget.dart';

class DashboardOverview extends StatefulWidget {
  const DashboardOverview({super.key});

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  String userGrowthPeriod = '30d';
  String userGrowthGranularity = 'Day';

  final List<Map<String, dynamic>> kpiCards = [
    {
      'title': 'Total Members',
      'value': '1,847',
      'change': '+12.3%',
      'isPositive': true,
      'icon': Icons.verified_user,
      'color': const Color(0xFF059669),
    },
    {
      'title': 'Non-Members',
      'value': '5,234',
      'change': '+8.7%',
      'isPositive': true,
      'icon': Icons.people,
      'color': const Color(0xFF3B82F6),
    },
    {
      'title': 'Daily Active Users',
      'value': '892',
      'change': '+5.2%',
      'isPositive': true,
      'icon': Icons.people_alt,
      'color': const Color(0xFF8B5CF6),
    },
    {
      'title': 'Credits Used Today',
      'value': '2,341',
      'change': '-3.1%',
      'isPositive': false,
      'icon': Icons.credit_card,
      'color': const Color(0xFFF59E0B),
    },
    {
      'title': 'Referrals',
      'value': '156',
      'change': '+18.9%',
      'isPositive': true,
      'icon': Icons.share,
      'color': const Color(0xFFEC4899),
    },
    {
      'title': 'Posts Viewed',
      'value': '12,847',
      'change': '+22.4%',
      'isPositive': true,
      'icon': Icons.visibility,
      'color': const Color(0xFF6366F1),
    },
  ];

  final List<FlSpot> userGrowthDataMembers = [
    const FlSpot(0, 1200),
    const FlSpot(1, 1350),
    const FlSpot(2, 1480),
    const FlSpot(3, 1620),
    const FlSpot(4, 1780),
  ];

  final List<FlSpot> userGrowthDataNonMembers = [
    const FlSpot(0, 3400),
    const FlSpot(1, 3800),
    const FlSpot(2, 4200),
    const FlSpot(3, 4600),
    const FlSpot(4, 5100),
  ];

  final List<BarChartGroupData> heatmapData = [
    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 120, color: const Color(0xFFF59E0B), width: 20)]),
    BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: 240, color: const Color(0xFFF59E0B), width: 20)]),
    BarChartGroupData(x: 12, barRods: [BarChartRodData(toY: 680, color: const Color(0xFFF59E0B), width: 20)]),
    BarChartGroupData(x: 18, barRods: [BarChartRodData(toY: 890, color: const Color(0xFFF59E0B), width: 20)]),
    BarChartGroupData(x: 23, barRods: [BarChartRodData(toY: 340, color: const Color(0xFFF59E0B), width: 20)]),
  ];

  final List<Map<String, dynamic>> topPosts = [
    {
      'title': 'Diamond Engagement Ring Collection',
      'category': 'Rings',
      'views': 15420,
      'unlocks': 2840,
      'saves': 1230,
      'shares': 890,
      'isPositive': true,
    },
    {
      'title': 'Vintage Pearl Necklace Designs',
      'category': 'Necklaces',
      'views': 12680,
      'unlocks': 2100,
      'saves': 980,
      'shares': 640,
      'isPositive': true,
    },
    {
      'title': 'Minimalist Gold Earrings',
      'category': 'Earrings',
      'views': 9850,
      'unlocks': 1750,
      'saves': 820,
      'shares': 520,
      'isPositive': false,
    },
    {
      'title': 'Art Deco Bracelet Collection',
      'category': 'Bracelets',
      'views': 8630,
      'unlocks': 1420,
      'saves': 670,
      'shares': 380,
      'isPositive': true,
    },
    {
      'title': 'Contemporary Watch Designs',
      'category': 'Watches',
      'views': 7240,
      'unlocks': 1180,
      'saves': 540,
      'shares': 290,
      'isPositive': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isWide),
              const SizedBox(height: 24),
              _buildKpiGrid(constraints),
              const SizedBox(height: 24),
              _buildChartsSection(isWide),
              const SizedBox(height: 24),
              _buildGeoAndHeatmapSection(isWide),
              const SizedBox(height: 24),
              _buildBottomSection(isWide),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isWide) {
    final headerContent = [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome back! Here\'s what\'s happening.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
      if (isWide) const Spacer(),
      Row(
        mainAxisSize: isWide ? MainAxisSize.min : MainAxisSize.max,
        children: [
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('View Analytics'),
          ),
        ],
      ),
    ];

    return isWide
      ? Row(children: headerContent)
      : Wrap(runSpacing: 16, children: headerContent);
  }

  Widget _buildKpiGrid(BoxConstraints constraints) {
    final crossAxisCount = (constraints.maxWidth / 200).floor().clamp(2, 6);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: kpiCards.length,
      itemBuilder: (context, index) {
        final kpi = kpiCards[index];
        return MetricCard(
          title: kpi['title'],
          value: kpi['value'],
          change: kpi['change'],
          isPositive: kpi['isPositive'],
          icon: kpi['icon'],
          iconColor: kpi['color'],
          isKpiCard: true,
        );
      },
    );
  }

  Widget _buildChartsSection(bool isWide) {
    final children = [
      _buildUserGrowthChart(),
      _buildDailyUsageChart(),
    ];
    return isWide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: children[0]),
            const SizedBox(width: 16),
            Expanded(flex: 1, child: children[1]),
          ],
        )
      : Column(
          children: [
            children[0],
            const SizedBox(height: 16),
            children[1],
          ],
        );
  }

  Widget _buildGeoAndHeatmapSection(bool isWide) {
      final children = [
          const GeoMapWidget(),
          ChartCard(
            title: 'Platform Activity Heatmap',
            subtitle: 'User engagement patterns by time and day',
            showViewDetails: true,
            chart: SizedBox(height: 300, child: _buildBarChart()),
          ),
      ];
      return isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 16),
                  Expanded(child: children[1]),
              ],
          )
          : Column(
              children: [
                  children[0],
                  const SizedBox(height: 16),
                  children[1],
              ],
          );
  }

   Widget _buildBottomSection(bool isWide) {
      final children = [
          _buildTopPostsCard(),
          const ConversionFunnelWidget(),
      ];
      return isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Expanded(flex: 2, child: children[0]),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: children[1]),
              ],
          )
          : Column(
              children: [
                  children[0],
                  const SizedBox(height: 16),
                  children[1],
              ],
          );
  }

  Widget _buildUserGrowthChart() {
    return ChartCard(
      title: 'User Growth Trend',
      subtitle: 'Members vs Non-Members over the selected period',
      actions: [
        _buildGranularitySelector(),
        const SizedBox(width: 8),
        _buildPeriodSelector(),
      ],
      chart: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => Text('${(value / 1000).toStringAsFixed(1)}k', style: const TextStyle(fontSize: 12)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    const dates = ['Jan 1', 'Jan 8', 'Jan 15', 'Jan 22', 'Jan 29'];
                    return value.toInt() < dates.length ? Text(dates[value.toInt()], style: const TextStyle(fontSize: 12)) : const Text('');
                  },
                ),
              ),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              _buildLineChartBarData(userGrowthDataMembers, const Color(0xFF8B5CF6)),
              _buildLineChartBarData(userGrowthDataNonMembers, const Color(0xFF06B6D4)),
            ],
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildLineChartBarData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
    );
  }

  Widget _buildDailyUsageChart() {
    return ChartCard(
      title: 'Daily Usage Pattern',
      subtitle: 'Platform activity by hour of day',
      chart: SizedBox(
        height: 300,
        child: _buildBarChart(),
      ),
    );
  }

  BarChart _buildBarChart() {
    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text('${value.toInt()}h', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: heatmapData,
        maxY: 1000,
      ),
    );
  }
  
  Widget _buildTopPostsCard() {
    return ChartCard(
      title: 'Top Performing Posts',
      subtitle: 'Most engaged jewelry posts in the selected period',
      chart: SingleChildScrollView( // Added for small screens
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 500), // Min width for the table
          child: Column(
            children: [
              _buildTopPostsHeader(),
              const SizedBox(height: 12),
              ...topPosts.map((post) => _buildTopPostRow(post)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopPostsHeader() {
    return Row(
      children: const [
        Expanded(flex: 3, child: Text('Post Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        Expanded(child: Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        Expanded(child: Text('Views', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        Expanded(child: Text('Unlocks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        SizedBox(width: 30, child: Text('Trend', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
      ],
    );
  }

  Widget _buildTopPostRow(Map<String, dynamic> post) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(post['title'], style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: Text(post['category'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            ),
          ),
          Expanded(child: Text(post['views'].toString(), style: const TextStyle(fontSize: 12))),
          Expanded(child: Text(post['unlocks'].toString(), style: const TextStyle(fontSize: 12))),
          SizedBox(
            width: 30,
            child: Icon(
              post['isPositive'] ? Icons.trending_up : Icons.trending_down,
              size: 16,
              color: post['isPositive'] ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGranularitySelector() {
    return PopupMenuButton<String>(
      initialValue: userGrowthGranularity,
      onSelected: (value) => setState(() => userGrowthGranularity = value),
      child: _buildSelectorChild(userGrowthGranularity),
      itemBuilder: (context) => ['Day', 'Week', 'Month']
          .map((e) => PopupMenuItem(value: e, child: Text(e)))
          .toList(),
    );
  }

  Widget _buildPeriodSelector() {
    return PopupMenuButton<String>(
      initialValue: userGrowthPeriod,
      onSelected: (value) => setState(() => userGrowthPeriod = value),
      child: _buildSelectorChild(userGrowthPeriod),
      itemBuilder: (context) => ['today', '7d', '30d', '90d']
          .map((e) => PopupMenuItem(value: e, child: Text(e)))
          .toList(),
    );
  }

  Widget _buildSelectorChild(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey.shade600),
        ],
      ),
    );
  }
}