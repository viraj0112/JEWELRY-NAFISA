import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _supabase = Supabase.instance.client;
  int _touchedIndex = -1;

  Future<Map<String, dynamic>> _fetchAnalytics() async {
    final designerId = _supabase.auth.currentUser!.id;

    final categoryPerformance = await _supabase.rpc(
      'get_category_performance',
      params: {'designer_id_param': designerId},
    );

    final viewsByCountry = await _supabase.rpc(
      'get_views_by_country',
      params: {'designer_id_param': designerId},
    );

    return {
      'category_performance': categoryPerformance,
      'views_by_country': viewsByCountry,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Analytics'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchAnalytics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final categoryPerformance = (data['category_performance'] as List)
              .map((item) => item as Map<String, dynamic>)
              .toList();
          final viewsByCountry = (data['views_by_country'] as List)
              .map((item) => item as Map<String, dynamic>)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildCategoryPerformanceChart(categoryPerformance),
              const SizedBox(height: 24),
              _buildGeoAnalyticsChart(viewsByCountry),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryPerformanceChart(List<Map<String, dynamic>> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category Performance',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  // getTooltipColor: Colors.blue
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final item = data[groupIndex];
                    return BarTooltipItem(
                      '${item['category']}\n',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: 'Views: ${item['total_views']}\n'
                              'Likes: ${item['total_likes']}\n'
                              'Downloads: ${item['total_downloads']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final categoryName =
                          data[value.toInt()]['category'] as String;
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 4, // Add a little space
                        child: Text(
                          categoryName,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value % 5 != 0 && value != 0) {
                        return Container();
                      }
                      return Text(
                        meta.formattedValue,
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.left,
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: (item['total_views'] as int).toDouble(),
                      color: Colors.lightBlue,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeoAnalyticsChart(List<Map<String, dynamic>> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Views by Country',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 0,
              centerSpaceRadius: 40,
              sections: data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isTouched = index == _touchedIndex;
                final fontSize = isTouched ? 25.0 : 16.0;
                final radius = isTouched ? 60.0 : 50.0;

                return PieChartSectionData(
                  color: Colors.primaries[index % Colors.primaries.length],
                  value: (item['view_count'] as int).toDouble(),
                  title: '${item['country']}\n${item['view_count']}',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xffffffff),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
