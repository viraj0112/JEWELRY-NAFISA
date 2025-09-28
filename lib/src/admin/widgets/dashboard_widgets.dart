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
        'change': usersChange, // DYNAMIC
      },
      {
        'icon': Icons.article_outlined,
        'color': const Color(0xFF00AB55),
        'label': 'Total Posts',
        'value': totalPosts,
        'change': postsChange, // DYNAMIC
      },
      {
        'icon': Icons.credit_card,
        'color': const Color(0xFFFFC107),
        'label': 'Credits Used',
        'value': creditsUsed,
        'change': creditsChange, // DYNAMIC (but placeholder for now)
      },
      {
        'icon': Icons.share_outlined,
        'color': const Color(0xFFFF4842),
        'label': 'Referrals',
        'value': referrals,
        'change': referralsChange, // DYNAMIC (but placeholder for now)
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

// UserGrowthCard remains the same
class UserGrowthCard extends StatefulWidget {
  const UserGrowthCard({super.key});

  @override
  State<UserGrowthCard> createState() => _UserGrowthCardState();
}

class _UserGrowthCardState extends State<UserGrowthCard> {
  final AdminService _adminService = AdminService();

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Column(
        children: [
          const _ChartCardHeader(
              title: 'User Growth Trend', subtitle: 'Members vs Non-Members'),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _adminService.getUserGrowthStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No data'));
                }
                return SfCartesianChart(
                  primaryXAxis: const CategoryAxis(),
                  // 🚀 FIXED: Changed <ChartSeries> to <CartesianSeries>
                  series: <CartesianSeries>[
                    ColumnSeries<Map<String, dynamic>, String>(
                      dataSource: snapshot.data!,
                      xValueMapper: (data, _) => data['x'],
                      yValueMapper: (data, _) => data['y'],
                    )
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// PostCategoriesCard remains the same
class PostCategoriesCard extends StatefulWidget {
  const PostCategoriesCard({super.key});

  @override
  State<PostCategoriesCard> createState() => _PostCategoriesCardState();
}

class _PostCategoriesCardState extends State<PostCategoriesCard> {
  final AdminService _adminService = AdminService();

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Column(
        children: [
          const _ChartCardHeader(
              title: 'Post Categories', subtitle: 'Breakdown by content type'),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _adminService.getPostCategoriesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No data'));
                  }
                  return SfCircularChart(
                    legend: const Legend(isVisible: true),
                    // 🚀 FIXED: This was already correct but ensuring consistency
                    series: <CircularSeries>[
                      DoughnutSeries<Map<String, dynamic>, String>(
                        dataSource: snapshot.data,
                        xValueMapper: (data, _) => data['cat'],
                        yValueMapper: (data, _) => data['val'],
                        dataLabelSettings:
                            const DataLabelSettings(isVisible: true),
                      )
                    ],
                  );
                }),
          ),
        ],
      ),
    );
  }
}

// DailyUsageCard remains the same
class DailyUsageCard extends StatefulWidget {
  const DailyUsageCard({super.key});

  @override
  State<DailyUsageCard> createState() => _DailyUsageCardState();
}

class _DailyUsageCardState extends State<DailyUsageCard> {
  final AdminService _adminService = AdminService();
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _adminService.getDailyAnalyticsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No data'));
                  }
                  return SfCartesianChart(
                    primaryXAxis: const CategoryAxis(),
                    // 🚀 FIXED: Changed <CartesianSeries<dynamic, dynamic>> to <CartesianSeries>
                    series: <CartesianSeries>[
                      ColumnSeries<Map<String, dynamic>, String>(
                          dataSource: snapshot.data!,
                          xValueMapper: (data, _) => data['hour'],
                          yValueMapper: (data, _) => data['val'],
                          dataLabelSettings:
                              const DataLabelSettings(isVisible: true))
                    ],
                  );
                }),
          ),
        ],
      ),
    );
  }
}

// GoalCompletionCard remains the same
class GoalCompletionCard extends StatefulWidget {
  const GoalCompletionCard({super.key});

  @override
  State<GoalCompletionCard> createState() => _GoalCompletionCardState();
}

class _GoalCompletionCardState extends State<GoalCompletionCard> {
  final AdminService _adminService = AdminService();

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Column(
        children: [
          const _ChartCardHeader(
              title: 'Conversion Rate',
              subtitle: 'Visitors to Members this month'),
          Expanded(
            child: StreamBuilder<double>(
              stream: _adminService.getConversionRateStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('No data'));
                }
                final conversionRate = snapshot.data! * 100;
                return SfCircularChart(
                  // 🚀 FIXED: This was already correct but ensuring consistency
                  series: <CircularSeries>[
                    RadialBarSeries<double, String>(
                      dataSource: [conversionRate],
                      xValueMapper: (data, _) => 'Conversion',
                      yValueMapper: (data, _) => data,
                      maximumValue: 100,
                      cornerStyle: CornerStyle.bothCurve,
                    )
                  ],
                  annotations: <CircularChartAnnotation>[
                    CircularChartAnnotation(
                      widget: Text(
                        '${conversionRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}