import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

// ... (StyledCard class remains the same)
class StyledCard extends StatefulWidget {
  final Widget child;
  const StyledCard({super.key, required this.child});

  @override
  State<StyledCard> createState() => _StyledCardState();
}

class _StyledCardState extends State<StyledCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(
            vertical: 8.0), // Added margin for spacing in lists
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF212B36) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isHovered ? 0.1 : 0.05),
              blurRadius: 15,
              spreadRadius: _isHovered ? 3 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

// MODIFIED: MetricsGrid now accepts data from the FutureBuilder
class MetricsGrid extends StatelessWidget {
  final int totalUsers;
  final int totalPosts;
  final int creditsUsed;
  final int referrals;

  const MetricsGrid({
    super.key,
    required this.totalUsers,
    required this.totalPosts,
    required this.creditsUsed,
    required this.referrals,
  });

  @override
  Widget build(BuildContext context) {
    final metricsData = [
      {
        'icon': Icons.people_alt_outlined,
        'color': const Color(0xFF00B8D9),
        'label': 'Total Users',
        'value': totalUsers,
        'change': 12.3
      },
      {
        'icon': Icons.article_outlined,
        'color': const Color(0xFF00AB55),
        'label': 'Total Posts',
        'value': totalPosts,
        'change': 8.7
      },
      {
        'icon': Icons.credit_card,
        'color': const Color(0xFFFFC107),
        'label': 'Credits Used',
        'value': creditsUsed,
        'change': -3.1
      },
      {
        'icon': Icons.share_outlined,
        'color': const Color(0xFFFF4842),
        'label': 'Referrals',
        'value': referrals,
        'change': 18.9
      },
    ];

    return LayoutBuilder(builder: (context, constraints) {
      return AnimationLimiter(
        child: Wrap(
          spacing: 24.0,
          runSpacing: 24.0,
          alignment: WrapAlignment.center,
          children: List.generate(metricsData.length, (index) {
            final metric = metricsData[index];
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _MetricCard(data: metric),
                ),
              ),
            );
          }),
        ),
      );
    });
  }
}

// ... (The rest of the file remains the same)
class _MetricCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final change = data['change'] as double;
    final isPositive = change >= 0;

    return StyledCard(
      child: Container(
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important for Wrap layout
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data['label'],
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                      color: (data['color'] as Color).withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(data['icon'], color: data['color'], size: 22),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(formatter.format(data['value']),
                style: GoogleFonts.inter(
                    fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPositive ? Colors.green : Colors.red, size: 16),
                const SizedBox(width: 4),
                Text('${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600)),
                Text(' vs last month',
                    style: GoogleFonts.inter(
                        color: Colors.grey.shade500, fontSize: 12))
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChartGrid extends StatelessWidget {
  const ChartGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final chartWidgets = [
      const UserGrowthCard(),
      const PostCategoriesCard(),
      const DailyUsageCard(),
      const GoalCompletionCard(),
    ];

    return AnimationLimiter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 700;
          return Wrap(
            spacing: 24,
            runSpacing: 24,
            children: List.generate(chartWidgets.length, (index) {
              final cardWidth = isMobile
                  ? constraints.maxWidth
                  : (constraints.maxWidth / 2) - 12;
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 500),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: SizedBox(
                      width: cardWidth,
                      height: cardWidth * (isMobile ? 1 : 0.8),
                      child: chartWidgets[index],
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _ChartCardHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _ChartCardHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(subtitle,
            style:
                GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }
}

class UserGrowthCard extends StatelessWidget {
  const UserGrowthCard({super.key});
  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Column(
        children: [
          const _ChartCardHeader(
              title: 'User Growth Trend', subtitle: 'Members vs Non-Members'),
          const SizedBox(height: 20),
          Expanded(
            child: SfCartesianChart(
              primaryXAxis: const CategoryAxis(),
              legend:
                  const Legend(isVisible: true, position: LegendPosition.top),
              trackballBehavior: TrackballBehavior(
                  enable: true,
                  activationMode: ActivationMode.singleTap,
                  tooltipSettings: const InteractiveTooltip(
                      enable: true, color: Colors.black)),
              series: <SplineSeries<Map<String, dynamic>, String>>[
                SplineSeries<Map<String, dynamic>, String>(
                    name: 'Members',
                    dataSource: const [
                      {'x': 'Jan', 'y': 1200},
                      {'x': 'Feb', 'y': 1800},
                      {'x': 'Mar', 'y': 2500},
                      {'x': 'Apr', 'y': 2300}
                    ],
                    xValueMapper: (data, _) => data['x'],
                    yValueMapper: (data, _) => data['y']),
                SplineSeries<Map<String, dynamic>, String>(
                    name: 'Non-Members',
                    dataSource: const [
                      {'x': 'Jan', 'y': 2200},
                      {'x': 'Feb', 'y': 2800},
                      {'x': 'Mar', 'y': 3800},
                      {'x': 'Apr', 'y': 3500}
                    ],
                    xValueMapper: (data, _) => data['x'],
                    yValueMapper: (data, _) => data['y']),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PostCategoriesCard extends StatelessWidget {
  const PostCategoriesCard({super.key});
  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Column(
        children: [
          const _ChartCardHeader(
              title: 'Post Categories', subtitle: 'Breakdown by content type'),
          Expanded(
            child: SfCircularChart(
              legend: const Legend(isVisible: true),
              series: <DoughnutSeries<Map<String, dynamic>, String>>[
                DoughnutSeries<Map<String, dynamic>, String>(
                  dataSource: const [
                    {'cat': 'Rings', 'val': 45},
                    {'cat': 'Earrings', 'val': 25},
                    {'cat': 'Necklaces', 'val': 20},
                    {'cat': 'Other', 'val': 10}
                  ],
                  xValueMapper: (data, _) => data['cat'],
                  yValueMapper: (data, _) => data['val'],
                  dataLabelSettings: const DataLabelSettings(isVisible: true),
                  innerRadius: '60%',
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DailyUsageCard extends StatelessWidget {
  const DailyUsageCard({super.key});
  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Column(
        children: [
          const _ChartCardHeader(
              title: 'Daily Usage Pattern',
              subtitle: 'Platform activity by hour'),
          const SizedBox(height: 20),
          Expanded(
            child: SfCartesianChart(
              primaryXAxis: const CategoryAxis(),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <CartesianSeries<Map<String, dynamic>, String>>[
                ColumnSeries<Map<String, dynamic>, String>(
                    dataSource: const [
                      {'hour': '0-6h', 'val': 150},
                      {'hour': '6-12h', 'val': 550},
                      {'hour': '12-18h', 'val': 900},
                      {'hour': '18-24h', 'val': 700}
                    ],
                    xValueMapper: (data, _) => data['hour'],
                    yValueMapper: (data, _) => data['val'],
                    borderRadius: BorderRadius.circular(8),
                    dataLabelSettings: const DataLabelSettings(isVisible: true))
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GoalCompletionCard extends StatelessWidget {
  const GoalCompletionCard({super.key});
  @override
  Widget build(BuildContext context) {
    const double goal = 100;
    const double current = 78;
    return StyledCard(
      child: Column(
        children: [
          const _ChartCardHeader(
              title: 'Conversion Rate',
              subtitle: 'Visitors to Members this month'),
          Expanded(
            child: SfCircularChart(
              series: <RadialBarSeries<double, String>>[
                RadialBarSeries<double, String>(
                  dataSource: const [current],
                  xValueMapper: (data, _) => 'Progress',
                  yValueMapper: (data, _) => data,
                  maximumValue: goal,
                  cornerStyle: CornerStyle.bothCurve,
                  trackOpacity: 0.2,
                  useSeriesColor: true,
                  dataLabelSettings: const DataLabelSettings(isVisible: false),
                )
              ],
              annotations: <CircularChartAnnotation>[
                CircularChartAnnotation(
                    widget: Text('${current.toInt()}%',
                        style: GoogleFonts.inter(
                            fontSize: 24, fontWeight: FontWeight.bold)))
              ],
            ),
          ),
        ],
      ),
    );
  }
}
