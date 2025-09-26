import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

// Main widget to hold the grid of redesigned cards
class ChartCard extends StatelessWidget {
  const ChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        if (constraints.maxWidth < 1300) crossAxisCount = 2;
        if (constraints.maxWidth < 700) crossAxisCount = 1;

        return GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: crossAxisCount == 1 ? 2.2 : 1.1,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            UserGrowthCard(),
            TopPostsCard(),
            DailyUsageCard(),
            ConversionFunnelCard(),
          ],
        );
      },
    );
  }
}

// --- Base Card for consistent styling ---
class BaseChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const BaseChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF212B36) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// --- 1. User Growth Trend Card ---
class UserGrowthCard extends StatelessWidget {
  const UserGrowthCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseChartCard(
      title: 'User Growth Trend',
      subtitle: 'Members vs Non-Members',
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value % 2000 == 0 && value != 0) {
                          return Text('${(value / 1000).toStringAsFixed(0)}K',
                              style:
                                  GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: _bottomTitles,
                    ),
                  ),
                ),
                lineBarsData: [
                  _generateLineData(
                    const Color(0xFF8884d8),
                    _generateSpots(1600, 3700),
                  ),
                  _generateLineData(
                    const Color(0xFF82ca9d),
                    _generateSpots(3700, 5300),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildLegend(),
        ],
      ),
    );
  }

  LineChartBarData _generateLineData(Color color, List<FlSpot> spots) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(const Color(0xFF82ca9d), 'Members'),
        const SizedBox(width: 20),
        _legendItem(const Color(0xFF8884d8), 'Non-Members'),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.inter(fontSize: 12)),
      ],
    );
  }

  static Widget _bottomTitles(double value, TitleMeta meta) {
    String text;
    switch (value.toInt()) {
      case 0: text = 'Jan 1'; break;
      case 2: text = 'Jan 8'; break;
      case 4: text = 'Jan 15'; break;
      case 6: text = 'Jan 22'; break;
      case 8: text = 'Jan 29'; break;
      default: return const SizedBox.shrink();
    }
    return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 4,
        child: Text(text, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)));
  }

  List<FlSpot> _generateSpots(double start, double end) {
    final random = Random();
    return List.generate(10, (index) {
      final y = start + (end - start) * random.nextDouble() + sin(index) * 200;
      return FlSpot(index.toDouble(), y);
    });
  }
}

// --- 2. Top Performing Posts Card ---
class TopPostsCard extends StatelessWidget {
  const TopPostsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = [
      {'title': 'Diamond Engagement Ring Collection', 'views': 15420},
      {'title': 'Vintage Pearl Necklace Designs', 'views': 12680},
      {'title': 'Minimalist Gold Earrings', 'views': 9850},
      {'title': 'Classic Gold Bangle', 'views': 7500},
    ];

    return BaseChartCard(
      title: 'Top Performing Posts',
      subtitle: 'Most engaged jewelry posts',
      child: ListView.separated(
        itemCount: posts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final post = posts[index];
          return Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.primaries[index % Colors.primaries.length].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.article_outlined,
                  color: Colors.primaries[index % Colors.primaries.length],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  post['title'] as String,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(post['views'] as int) ~/ 1000}K',
                style: GoogleFonts.inter(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- 3. Daily Usage Pattern Card ---
class DailyUsageCard extends StatelessWidget {
  const DailyUsageCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseChartCard(
      title: 'Daily Usage Pattern',
      subtitle: 'Platform activity by hour of day',
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  String text;
                  switch (value.toInt()) {
                    case 0: text = '00'; break;
                    case 1: text = '06'; break;
                    case 2: text = '12'; break;
                    case 3: text = '18'; break;
                    case 4: text = '23'; break;
                    default: return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Text(text,
                        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            _makeBar(0, 150),
            _makeBar(1, 250),
            _makeBar(2, 700),
            _makeBar(3, 900),
            _makeBar(4, 350),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeBar(int x, double y) {
    const gradient = LinearGradient(
      colors: [Color(0xfff8b06a), Color(0xfff7863d)],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: gradient,
          width: 20,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        )
      ],
    );
  }
}

// --- 4. Conversion Funnel Card ---
class ConversionFunnelCard extends StatelessWidget {
  const ConversionFunnelCard({super.key});

  @override
  Widget build(BuildContext context) {
    final stages = [
      FunnelStage('Visitors', 10000, const Color(0xFF00B8D9)),
      FunnelStage('Product Views', 7500, const Color(0xFF00AB55)),
      FunnelStage('Add to Cart', 3000, const Color(0xFFFFC107)),
      FunnelStage('Purchases', 1200, const Color(0xFFFF4842)),
    ];

    return BaseChartCard(
      title: 'Conversion Funnel',
      subtitle: 'User journey from visit to purchase',
      child: FunnelChart(stages: stages),
    );
  }
}

// --- Custom Funnel Chart and Painter ---
class FunnelStage {
  final String label;
  final int value;
  final Color color;

  FunnelStage(this.label, this.value, this.color);
}

class FunnelChart extends StatelessWidget {
  final List<FunnelStage> stages;

  const FunnelChart({super.key, required this.stages});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FunnelPainter(stages),
      size: Size.infinite,
    );
  }
}

class FunnelPainter extends CustomPainter {
  final List<FunnelStage> stages;
  FunnelPainter(this.stages);

  @override
  void paint(Canvas canvas, Size size) {
    if (stages.isEmpty) return;

    final double topWidth = size.width * 0.8;
    final double bottomWidth = size.width * 0.2;
    final double stageHeight = size.height / stages.length;
    final double totalValue = stages.first.value.toDouble();

    for (int i = 0; i < stages.length; i++) {
      final stage = stages[i];
      final paint = Paint()..color = stage.color;
      final path = Path();

      final currentTopY = i * stageHeight;
      final currentBottomY = (i + 1) * stageHeight;

      final prevValue = i == 0 ? totalValue : stages[i - 1].value.toDouble();
      final currentValue = stage.value.toDouble();

      final currentTopWidth =
          bottomWidth + (topWidth - bottomWidth) * (prevValue / totalValue);
      final currentBottomWidth =
          bottomWidth + (topWidth - bottomWidth) * (currentValue / totalValue);

      final topLeftX = (size.width - currentTopWidth) / 2;
      final topRightX = topLeftX + currentTopWidth;
      final bottomLeftX = (size.width - currentBottomWidth) / 2;
      final bottomRightX = bottomLeftX + currentBottomWidth;

      path.moveTo(topLeftX, currentTopY);
      path.lineTo(topRightX, currentTopY);
      path.lineTo(bottomRightX, currentBottomY);
      path.lineTo(bottomLeftX, currentBottomY);
      path.close();

      canvas.drawPath(path, paint);

      // --- Draw Text ---
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${stage.label}\n',
          style: GoogleFonts.inter(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          children: [
            TextSpan(
              text: stage.value.toString(),
              style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.8), fontSize: 11),
            )
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(minWidth: 0, maxWidth: size.width);
      final textOffset = Offset(
        (size.width - textPainter.width) / 2,
        currentTopY + (stageHeight - textPainter.height) / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}