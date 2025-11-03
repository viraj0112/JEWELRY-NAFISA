import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';

// StyledCard remains the same
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
              color: Colors.black.withValues(alpha: _isHovered ? 0.1 : 0.05),
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

class MetricsGrid extends StatelessWidget {
  final int totalUsers;
  final double usersChange;
  final int totalPosts;
  final double postsChange;
  final int creditsUsed;
  final double creditsChange;
  final int referrals;
  final double referralsChange;

  const MetricsGrid({
    super.key,
    required this.totalUsers,
    required this.usersChange,
    required this.totalPosts,
    required this.postsChange,
    required this.creditsUsed,
    required this.creditsChange,
    required this.referrals,
    required this.referralsChange,
  });

  @override
  Widget build(BuildContext context) {
    final metricsData = [
      {
        'icon': Icons.people_alt_outlined,
        'color': const Color(0xFF00B8D9),
        'label': 'Total Users',
        'value': totalUsers,
        'change': usersChange,
      },
      {
        'icon': Icons.article_outlined,
        'color': const Color(0xFF00AB55),
        'label': 'Total Posts',
        'value': totalPosts,
        'change': postsChange,
      },
      {
        'icon': Icons.credit_card,
        'color': const Color(0xFFFFC107),
        'label': 'Credits Used',
        'value': creditsUsed,
        'change': creditsChange,
      },
      {
        'icon': Icons.share_outlined,
        'color': const Color(0xFFFF4842),
        'label': 'Referrals',
        'value': referrals,
        'change': referralsChange,
      },
    ];

    return LayoutBuilder(builder: (context, constraints) {
      bool isMobile = constraints.maxWidth < 600;
      return AnimationLimiter(
        child: isMobile
            ? Column(
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
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(metricsData.length, (index) {
                    final metric = metricsData[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12.0),
                            child: _MetricCard(data: metric),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
      );
    });
  }
}

// _MetricCard remains the same
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
                      color: (data['color'] as Color).withValues(alpha: 0.1),
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

// ChartGrid remains the same
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

// _ChartCardHeader remains the same
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

// FIX: Refactored UserGrowthCard to manage stream lifecycle
class UserGrowthCard extends StatefulWidget {
  const UserGrowthCard({super.key});

  @override
  State<UserGrowthCard> createState() => _UserGrowthCardState();
}

class _UserGrowthCardState extends State<UserGrowthCard> {
  final AdminService _adminService = AdminService();
  StreamSubscription? _subscription;
  List<Map<String, dynamic>>? _data;

  @override
  void initState() {
    super.initState();
    _subscription = _adminService.getUserGrowthStream().listen((data) {
      if (mounted) {
        setState(() {
          _data = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Column(
        children: [
          const _ChartCardHeader(
              title: 'User Growth Trend', subtitle: 'Members vs Non-Members'),
          const SizedBox(height: 20),
          Expanded(
            child: _data == null
                ? const Center(child: CircularProgressIndicator())
                : _data!.isEmpty
                    ? const Center(child: Text('No data'))
                    : SfCartesianChart(
                        primaryXAxis: const CategoryAxis(),
                        series: <CartesianSeries>[
                          ColumnSeries<Map<String, dynamic>, String>(
                            dataSource: _data,
                            xValueMapper: (data, _) => data['x'],
                            yValueMapper: (data, _) => data['y'],
                          )
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// FIX: Refactored PostCategoriesCard to manage stream lifecycle
class PostCategoriesCard extends StatefulWidget {
  const PostCategoriesCard({super.key});

  @override
  State<PostCategoriesCard> createState() => _PostCategoriesCardState();
}

class _PostCategoriesCardState extends State<PostCategoriesCard> {
  final AdminService _adminService = AdminService();
  StreamSubscription? _subscription;
  List<Map<String, dynamic>>? _data;

  @override
  void initState() {
    super.initState();
    _subscription = _adminService.getPostCategoriesStream().listen((data) {
      if (mounted) {
        setState(() {
          _data = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Column(
        children: [
          const _ChartCardHeader(
              title: 'Post Categories', subtitle: 'Breakdown by content type'),
          Expanded(
            child: _data == null
                ? const Center(child: CircularProgressIndicator())
                : _data!.isEmpty
                    ? const Center(child: Text('No data'))
                    : SfCircularChart(
                        legend: const Legend(isVisible: true),
                        series: <CircularSeries>[
                          DoughnutSeries<Map<String, dynamic>, String>(
                            dataSource: _data,
                            xValueMapper: (data, _) => data['cat'],
                            yValueMapper: (data, _) => data['val'],
                            dataLabelSettings:
                                const DataLabelSettings(isVisible: true),
                          )
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// FIX: Refactored DailyUsageCard to manage stream lifecycle
class DailyUsageCard extends StatefulWidget {
  const DailyUsageCard({super.key});

  @override
  State<DailyUsageCard> createState() => _DailyUsageCardState();
}

class _DailyUsageCardState extends State<DailyUsageCard> {
  final AdminService _adminService = AdminService();
  StreamSubscription? _subscription;
  List<Map<String, dynamic>>? _data;

  @override
  void initState() {
    super.initState();
    // MODIFIED: Pointed to the new credits stream
    _subscription = _adminService.getDailyCreditsStream().listen((data) {
      if (mounted) {
        setState(() {
          _data = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Column(
        children: [
          // MODIFIED: Updated title and subtitle
          const _ChartCardHeader(
              title: 'Daily Credits Used',
              subtitle: 'Credits used over the last 30 days'),
          const SizedBox(height: 20),
          Expanded(
            child: _data == null
                ? const Center(child: CircularProgressIndicator())
                : _data!.isEmpty
                    ? const Center(child: Text('No data'))
                    : SfCartesianChart(
                        primaryXAxis: const CategoryAxis(),
                        series: <CartesianSeries>[
                          ColumnSeries<Map<String, dynamic>, String>(
                              dataSource: _data!,
                              xValueMapper: (data, _) => DateFormat.MMMd()
                                  .format(DateTime.parse(data['day'])),
                              yValueMapper: (data, _) => data['val'],
                              dataLabelSettings:
                                  const DataLabelSettings(isVisible: true))
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// FIX: Refactored GoalCompletionCard to manage stream lifecycle
class GoalCompletionCard extends StatefulWidget {
  const GoalCompletionCard({super.key});

  @override
  State<GoalCompletionCard> createState() => _GoalCompletionCardState();
}

class _GoalCompletionCardState extends State<GoalCompletionCard> {
  final AdminService _adminService = AdminService();
  StreamSubscription? _subscription;
  double? _conversionRate;

  @override
  void initState() {
    super.initState();
    _subscription = _adminService.getConversionRateStream().listen((rate) {
      if (mounted) {
        setState(() {
          _conversionRate = rate;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Column(
        children: [
          const _ChartCardHeader(
              title: 'Conversion Rate',
              subtitle: 'Visitors to Members this month'),
          Expanded(
            child: _conversionRate == null
                ? const Center(child: CircularProgressIndicator())
                : SfCircularChart(
                    series: <CircularSeries>[
                      RadialBarSeries<double, String>(
                        dataSource: [_conversionRate!],
                        xValueMapper: (data, _) => 'Conversion',
                        yValueMapper: (data, _) => data,
                        maximumValue: 1,
                        cornerStyle: CornerStyle.bothCurve,
                      )
                    ],
                    annotations: <CircularChartAnnotation>[
                      CircularChartAnnotation(
                        widget: Text(
                          '${(_conversionRate! * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
