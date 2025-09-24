import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/metric_card.dart';
import '../widgets/chart_card.dart';
import '../widgets/geo_map_widget.dart';

class AnalyticsSection extends StatefulWidget {
  const AnalyticsSection({super.key});

  @override
  State<AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<AnalyticsSection> {
  String selectedPeriod = '30d';
  bool realTimeMode = false;

  final List<Map<String, dynamic>> analyticsMetrics = [
    {
      'title': 'Page Views',
      'value': '156,789',
      'change': '+23.1%',
      'isPositive': true,
      'icon': Icons.visibility,
      'color': const Color(0xFF3B82F6),
    },
    {
      'title': 'Unique Visitors',
      'value': '45,123',
      'change': '+18.5%',
      'isPositive': true,
      'icon': Icons.person,
      'color': const Color(0xFF10B981),
    },
    {
      'title': 'Bounce Rate',
      'value': '32.4%',
      'change': '-2.3%',
      'isPositive': true,
      'icon': Icons.exit_to_app,
      'color': const Color(0xFFF59E0B),
    },
    {
      'title': 'Avg. Session',
      'value': '4:23',
      'change': '+12.8%',
      'isPositive': true,
      'icon': Icons.timer,
      'color': const Color(0xFF8B5CF6),
    },
    {
      'title': 'Conversion Rate',
      'value': '3.8%',
      'change': '+0.7%',
      'isPositive': true,
      'icon': Icons.trending_up,
      'color': const Color(0xFFEC4899),
    },
    {
      'title': 'Page Load Time',
      'value': '2.1s',
      'change': '-0.3s',
      'isPositive': true,
      'icon': Icons.speed,
      'color': const Color(0xFF06B6D4),
    },
  ];

  final List<FlSpot> trafficTrendData = [
    const FlSpot(0, 25467),
    const FlSpot(1, 28934),
    const FlSpot(2, 32156),
    const FlSpot(3, 29847),
    const FlSpot(4, 35621),
    const FlSpot(5, 38945),
    const FlSpot(6, 42189),
  ];

  final List<Map<String, dynamic>> topPages = [
    {'page': '/jewelry/rings/engagement', 'views': '25,467', 'unique': '18,234', 'bounce': '28.5%', 'trend': true},
    {'page': '/collections/vintage-necklaces', 'views': '12,890', 'unique': '9,567', 'bounce': '35.2%', 'trend': true},
    {'page': '/jewelry/earrings/gold', 'views': '8,456', 'unique': '6,789', 'bounce': '42.1%', 'trend': false},
    {'page': '/about/our-story', 'views': '5,234', 'unique': '4,123', 'bounce': '38.7%', 'trend': true},
    {'page': '/blog/jewelry-care-tips', 'views': '4,567', 'unique': '3,456', 'bounce': '25.3%', 'trend': true},
    {'page': '/collections/bracelets', 'views': '3,892', 'unique': '2,934', 'bounce': '44.8%', 'trend': false},
  ];

  final List<Map<String, dynamic>> trafficSources = [
    {'source': 'Organic Search', 'visitors': 34567, 'percentage': 42.5, 'color': const Color(0xFF10B981)},
    {'source': 'Direct', 'visitors': 28934, 'percentage': 35.6, 'color': const Color(0xFF3B82F6)},
    {'source': 'Social Media', 'visitors': 12345, 'percentage': 15.2, 'color': const Color(0xFFEC4899)},
    {'source': 'Email', 'visitors': 3456, 'percentage': 4.2, 'color': const Color(0xFFF59E0B)},
    {'source': 'Paid Ads', 'visitors': 2058, 'percentage': 2.5, 'color': const Color(0xFF8B5CF6)},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with real-time toggle
          _buildHeader(),
          const SizedBox(height: 24),
          
          // Analytics metrics grid
          _buildMetricsGrid(),
          const SizedBox(height: 24),
          
          // Traffic trend and sources
          _buildTrafficAnalytics(),
          const SizedBox(height: 24),
          
          // Geographic and device analytics
          _buildGeoAndDeviceAnalytics(),
          const SizedBox(height: 24),
          
          // Top pages and performance metrics
          _buildPerformanceSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Comprehensive insights into your jewelry platform performance.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            _buildRealTimeToggle(),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export Data'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRealTimeToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton('Historical', !realTimeMode),
          _buildToggleButton('Real-time', realTimeMode),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          realTimeMode = text == 'Real-time';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ] : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isActive ? const Color(0xFF111827) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 6 : (constraints.maxWidth > 800 ? 3 : 2);
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: analyticsMetrics.length,
          itemBuilder: (context, index) {
            final metric = analyticsMetrics[index];
            return MetricCard(
              title: metric['title'],
              value: metric['value'],
              change: metric['change'],
              isPositive: metric['isPositive'],
              icon: metric['icon'],
              iconColor: metric['color'],
              isKpiCard: true,
            );
          },
        );
      },
    );
  }

  Widget _buildTrafficAnalytics() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Traffic trend
        Expanded(
          flex: 2,
          child: ChartCard(
            title: 'Traffic Trend',
            subtitle: 'Page views over the selected period',
            actions: [_buildPeriodSelector()],
            chart: SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value / 1000).toStringAsFixed(0)}k',
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          if (value.toInt() < days.length) {
                            return Text(
                              days[value.toInt()],
                              style: const TextStyle(fontSize: 12),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: trafficTrendData,
                      isCurved: true,
                      color: const Color(0xFF3B82F6),
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        
        // Traffic sources
        Expanded(
          child: ChartCard(
            title: 'Traffic Sources',
            subtitle: 'Where your visitors come from',
            chart: SizedBox(
              height: 300,
              child: Column(
                children: [
                  // Pie chart
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: trafficSources.map((source) {
                          return PieChartSectionData(
                            color: source['color'],
                            value: source['percentage'],
                            title: '${source['percentage'].toStringAsFixed(1)}%',
                            titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            radius: 60,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Legend
                  Column(
                    children: trafficSources.take(3).map((source) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: source['color'],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                source['source'],
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              '${source['percentage'].toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeoAndDeviceAnalytics() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: GeoMapWidget(),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ChartCard(
            title: 'Device & Browser Analytics',
            subtitle: 'User device and browser preferences',
            chart: SizedBox(
              height: 300,
              child: Column(
                children: [
                  // Device types bar chart
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const devices = ['Desktop', 'Mobile', 'Tablet'];
                                if (value.toInt() < devices.length) {
                                  return Text(
                                    devices[value.toInt()],
                                    style: const TextStyle(fontSize: 12),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 55, color: const Color(0xFF3B82F6), width: 30)]),
                          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 35, color: const Color(0xFF10B981), width: 30)]),
                          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 10, color: const Color(0xFFF59E0B), width: 30)]),
                        ],
                        maxY: 60,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Device stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      Column(
                        children: [
                          Text('55%', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          Text('Desktop', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('35%', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          Text('Mobile', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('10%', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          Text('Tablet', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSection() {
    return ChartCard(
      title: 'Top Performing Pages',
      subtitle: 'Most visited pages and their performance metrics',
      chart: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Page', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(child: Text('Views', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(child: Text('Unique', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(child: Text('Bounce', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                SizedBox(width: 40, child: Text('Trend', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Rows
          ...topPages.map((page) => _buildPageRow(page)),
        ],
      ),
    );
  }

  Widget _buildPageRow(Map<String, dynamic> page) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              page['page'],
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              page['views'],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              page['unique'],
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              page['bounce'],
              style: TextStyle(
                fontSize: 13,
                color: double.parse(page['bounce'].replaceAll('%', '')) > 40 
                  ? Colors.red.shade600 
                  : Colors.green.shade600,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Icon(
              page['trend'] ? Icons.trending_up : Icons.trending_down,
              size: 16,
              color: page['trend'] ? Colors.green.shade600 : Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return PopupMenuButton<String>(
      initialValue: selectedPeriod,
      onSelected: (value) {
        setState(() {
          selectedPeriod = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedPeriod,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey.shade600),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'today', child: Text('Today')),
        const PopupMenuItem(value: '7d', child: Text('7 days')),
        const PopupMenuItem(value: '30d', child: Text('30 days')),
        const PopupMenuItem(value: '90d', child: Text('90 days')),
      ],
    );
  }
}