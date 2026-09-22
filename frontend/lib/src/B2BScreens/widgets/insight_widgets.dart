import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/b2b_insights_service.dart';
import '../b2b_theme.dart';

/// Compact number: 950, 1.2K, 3.4M.
String compactCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

/// One metric with its change against the previous window.
class InsightStatTile extends StatelessWidget {
  const InsightStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.current,
    this.previous,
    this.accent = B2BColors.primary,
    this.highlight = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final int value;

  /// When both are given, a change chip compares them.
  final int? current;
  final int? previous;
  final Color accent;

  /// Gold-tinted tile for the headline metric (quote requests).
  final bool highlight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: b2bCardDecoration(
        color: highlight ? B2BColors.goldSoft : B2BColors.surface,
        radius: B2BRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              padding: EdgeInsets.all(compact ? 6 : 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(B2BRadius.sm),
              ),
              child: Icon(icon, size: compact ? 15 : 18, color: accent),
            ),
            const Spacer(),
            if (current != null && previous != null)
              _ChangeChip(current: current!, previous: previous!),
          ]),
          SizedBox(height: compact ? 10 : 14),
          Text(compactCount(value), style: B2BText.serif(size: compact ? 22 : 28)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: B2BText.sans(size: compact ? 11.5 : 12.5, color: B2BColors.muted)),
        ],
      ),
    );
  }
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({required this.current, required this.previous});

  final int current;
  final int previous;

  @override
  Widget build(BuildContext context) {
    final pct = InsightsReport.change(current, previous);
    late final String text;
    late final Color color;
    late final IconData icon;
    if (pct == null) {
      if (current == 0) return const SizedBox.shrink();
      text = 'New';
      color = B2BColors.success;
      icon = Icons.arrow_upward_rounded;
    } else if (pct.abs() < 1) {
      text = '0%';
      color = B2BColors.muted;
      icon = Icons.remove_rounded;
    } else {
      text = '${pct.abs().round()}%';
      color = pct > 0 ? B2BColors.success : B2BColors.danger;
      icon = pct > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    }
    return Tooltip(
      message: 'vs the previous period ($previous)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 2),
          Text(text,
              style: B2BText.sans(size: 10.5, weight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

/// Daily views as a soft emerald area line.
class ViewsTrendChart extends StatelessWidget {
  const ViewsTrendChart({super.key, required this.days, this.height = 150});

  final List<InsightDay> days;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return SizedBox(height: height);
    final maxY = days.fold<int>(0, (m, d) => d.views > m ? d.views : m);
    final spots = [
      for (var i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), days[i].views.toDouble()),
    ];
    final fmt = DateFormat('MMM d');
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY == 0 ? 1 : maxY * 1.25,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY <= 4 ? 1 : (maxY / 4).ceilToDouble(),
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: B2BColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: maxY <= 4 ? 1 : (maxY / 4).ceilToDouble(),
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: B2BText.sans(size: 10, color: B2BColors.faint)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (days.length / 4).ceilToDouble().clamp(1, 1000),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(fmt.format(days[i].day),
                        style: B2BText.sans(size: 10, color: B2BColors.faint)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => B2BColors.ink,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${fmt.format(days[s.x.toInt()].day)}\n'
                        '${s.y.toInt()} view${s.y.toInt() == 1 ? '' : 's'}',
                        B2BText.sans(size: 11.5, color: Colors.white),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              color: B2BColors.primary,
              barWidth: 2.2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    B2BColors.primary.withValues(alpha: 0.18),
                    B2BColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 350),
      ),
    );
  }
}

/// Top locations as share-of-activity bars.
class LocationBars extends StatelessWidget {
  const LocationBars({super.key, required this.locations, this.max = 5});

  final List<InsightLocation> locations;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) {
      return Text(
        'No location data yet. Locations appear once signed-in visitors '
        'with a pincode view, like or save your designs.',
        style: B2BText.sans(size: 13, color: B2BColors.muted, height: 1.5),
      );
    }
    final total = locations.fold<int>(0, (s, l) => s + l.count);
    return Column(
      children: [
        for (final l in locations.take(max))
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 15, color: B2BColors.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(l.name,
                        overflow: TextOverflow.ellipsis,
                        style: B2BText.sans(size: 13.5, color: B2BColors.inkSoft)),
                  ),
                  Text('${(l.count / total * 100).round()}%',
                      style: B2BText.sans(size: 13, weight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text('(${l.count})',
                      style: B2BText.sans(size: 11.5, color: B2BColors.faint)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: l.count / total,
                    minHeight: 6,
                    backgroundColor: B2BColors.surfaceAlt,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(B2BColors.primary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Generated observations, each with a small gold marker.
class KeyInsightsList extends StatelessWidget {
  const KeyInsightsList({super.key, required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final text in insights)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: B2BColors.goldSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome,
                      size: 11, color: B2BColors.gold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(text,
                      style: B2BText.sans(
                          size: 13.5, color: B2BColors.inkSoft, height: 1.5)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Newest engagement events: "Viewed · Ruby Pendant · Mumbai · 2h ago".
class ActivityList extends StatelessWidget {
  const ActivityList({super.key, required this.activity, this.max = 8});

  final List<InsightActivity> activity;
  final int max;

  static (IconData, String, Color) _style(String kind) => switch (kind) {
        'view' => (Icons.visibility_outlined, 'Viewed', B2BColors.primary),
        'like' => (Icons.favorite_border_rounded, 'Liked', B2BColors.gold),
        'save' => (Icons.bookmark_border_rounded, 'Saved', B2BColors.primaryDeep),
        'share' => (Icons.ios_share_rounded, 'Shared', const Color(0xFF8A6A36)),
        'quote' => (Icons.request_quote_outlined, 'Quote requested', B2BColors.success),
        _ => (Icons.bolt_rounded, 'Activity', B2BColors.muted),
      };

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat('MMM d').format(t);
  }

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) {
      return Text('No activity in this period yet.',
          style: B2BText.sans(size: 13, color: B2BColors.muted));
    }
    return Column(
      children: [
        for (final a in activity.take(max))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Builder(builder: (_) {
                  final (icon, _, color) = _style(a.kind);
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(B2BRadius.sm),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  );
                }),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_style(a.kind).$2} · ${a.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: B2BText.sans(size: 13.5, weight: FontWeight.w500)),
                      if (a.location != null)
                        Text(a.location!,
                            style: B2BText.sans(size: 12, color: B2BColors.muted)),
                    ],
                  ),
                ),
                Text(_ago(a.at),
                    style: B2BText.sans(size: 12, color: B2BColors.faint)),
              ],
            ),
          ),
      ],
    );
  }
}

/// White card with a serif section title.
class InsightSection extends StatelessWidget {
  const InsightSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: b2bCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: B2BText.serif(size: 19)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!,
                        style: B2BText.sans(size: 12.5, color: B2BColors.muted)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
