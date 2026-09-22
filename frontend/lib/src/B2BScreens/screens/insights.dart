import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jewelry_nafisa/src/B2BScreens/b2b_theme.dart';
import 'package:jewelry_nafisa/src/B2BScreens/widgets/insight_widgets.dart';
import 'package:jewelry_nafisa/src/models/filter_criteria.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/services/b2b_insights_service.dart';
import 'package:jewelry_nafisa/src/services/geo_analytics_service.dart';
import 'package:jewelry_nafisa/src/widgets/geo_analytics_widget.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Portfolio performance for the signed-in seller, from the `b2b_insights`
/// database function: real totals (including quote requests), change vs the
/// previous period, a views trend, top products, key observations and the
/// latest activity. Follows the header's date filter.
class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key, this.dateRange});

  /// When set, the numbers cover only this range. Null = all time.
  final DateTimeRange? dateRange;

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final _supabase = Supabase.instance.client;
  final _service = B2BInsightsService();

  bool _isLoading = true;
  String? _error;
  bool _isManufacturer = false;
  final bool _isPremiumDesigner = false;

  InsightsReport? _report;
  GeoAnalyticsData _geoData = GeoAnalyticsData.empty;

  // A slow response for an old range must not overwrite a newer one.
  int _fetchSeq = 0;

  bool get _isUnlocked => _isManufacturer || _isPremiumDesigner;

  FilterCriteria get _range => FilterCriteria(dateRange: widget.dateRange);

  String get _periodLabel {
    final range = widget.dateRange;
    if (range == null) return 'All time';
    final f = DateFormat('MMM d');
    return '${f.format(range.start)} - ${f.format(range.end)}';
  }

  @override
  void initState() {
    super.initState();
    final profile =
        Provider.of<UserProfileProvider>(context, listen: false).userProfile;
    _isManufacturer = profile?.manufacturerProfile != null;
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant InsightsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateRange != widget.dateRange) _fetchData();
  }

  Future<void> _fetchData() async {
    final seq = ++_fetchSeq;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final range = _range;
      Future<InsightsReport> fetch(String table) => _service.fetch(
            table: table,
            from: range.rangeStart,
            to: range.rangeEndExclusive,
          );

      var table = _isManufacturer ? 'manufacturerproducts' : 'designerproducts';
      var report = await fetch(table);
      // Older designer accounts may still have their catalogue in `products`.
      if (!_isManufacturer && report.productCount == 0) {
        table = 'products';
        report = await fetch(table);
      }

      var geo = GeoAnalyticsData.empty;
      if (_isUnlocked && report.productCount > 0) {
        geo = await GeoAnalyticsService.fetchGeoData(
            productIds: await _productIds(table));
      }

      if (!mounted || seq != _fetchSeq) return;
      setState(() {
        _report = report;
        _geoData = geo;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching insights: $e');
      if (!mounted || seq != _fetchSeq) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load insights. Please try again.';
      });
    }
  }

  /// All of the seller's product ids, paged past the 1000-row response cap.
  Future<List<String>> _productIds(String table) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];
    final ids = <String>[];
    for (var from = 0;; from += 1000) {
      final rows = await _supabase
          .from(table)
          .select('id')
          .eq('user_id', userId)
          .order('id')
          .range(from, from + 999);
      ids.addAll(rows.map((r) => '${r['id']}'));
      if (rows.length < 1000) break;
    }
    return ids;
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      backgroundColor: B2BColors.canvas,
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 26),
                    if (_error != null) ...[
                      _errorBanner(),
                      const SizedBox(height: 20),
                    ],
                    if (_isLoading && report == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (report != null)
                      AnimatedOpacity(
                        // Dim while a new range loads instead of blanking.
                        opacity: _isLoading ? 0.5 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: _body(report),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PERFORMANCE', style: B2BText.eyebrow()),
              const SizedBox(height: 6),
              Text('Portfolio Insights', style: B2BText.serif(size: 30)),
              const SizedBox(height: 6),
              Text(
                'How your designs are performing · $_periodLabel'
                '${_report == null ? '' : ' · ${_report!.productCount} products'}',
                style: B2BText.sans(size: 13.5, color: B2BColors.muted),
              ),
              const SizedBox(height: 14),
              Container(width: 44, height: 2, color: B2BColors.gold),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _isLoading ? null : _fetchData,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: B2BColors.dangerSoft,
        borderRadius: BorderRadius.circular(B2BRadius.md),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: B2BColors.danger),
        const SizedBox(width: 10),
        Expanded(
            child: Text(_error!,
                style: B2BText.sans(size: 13.5, color: B2BColors.danger))),
        TextButton(onPressed: _fetchData, child: const Text('Retry')),
      ]),
    );
  }

  Widget _body(InsightsReport r) {
    final t = r.totals;
    final tiles = [
      InsightStatTile(
          icon: Icons.visibility_outlined, label: 'Views', value: t.views,
          current: r.current.views, previous: r.previous.views),
      InsightStatTile(
          icon: Icons.favorite_border_rounded, label: 'Likes', value: t.likes,
          current: r.current.likes, previous: r.previous.likes,
          accent: B2BColors.gold),
      InsightStatTile(
          icon: Icons.bookmark_border_rounded, label: 'Saves', value: t.saves,
          current: r.current.saves, previous: r.previous.saves,
          accent: B2BColors.primaryDeep),
      InsightStatTile(
          icon: Icons.ios_share_rounded, label: 'Shares', value: t.shares,
          current: r.current.shares, previous: r.previous.shares,
          accent: const Color(0xFF8A6A36)),
      InsightStatTile(
          icon: Icons.request_quote_outlined, label: 'Quote requests',
          value: t.quoteRequests, current: r.current.quoteRequests,
          previous: r.previous.quoteRequests, accent: B2BColors.success,
          highlight: true),
    ];

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      final perRow = c.maxWidth >= 900 ? 5 : (c.maxWidth >= 600 ? 3 : 2);
      final tileWidth = (c.maxWidth - 14 * (perRow - 1)) / perRow;

      final trend = InsightSection(
        title: 'Views over time',
        subtitle: 'Last ${r.windowDays} days: ${r.current.views} views · '
            '${r.previous.views} in the ${r.windowDays} days before',
        child: ViewsTrendChart(days: r.dailyViews, height: 200),
      );
      final keyInsights = InsightSection(
        title: 'Key insights',
        child: KeyInsightsList(insights: r.keyInsights()),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final tile in tiles) SizedBox(width: tileWidth, child: tile)
            ],
          ),
          const SizedBox(height: 20),
          if (wide)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: trend),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: keyInsights),
                ],
              ),
            )
          else ...[
            trend,
            const SizedBox(height: 20),
            keyInsights,
          ],
          const SizedBox(height: 20),
          _topProducts(r),
          const SizedBox(height: 20),
          if (_isUnlocked)
            GeoAnalyticsWidget(
              data: _geoData,
              title: 'Geographic Insights',
              subtitle:
                  'Views, likes, shares and saves of your products by country, state and pincode.',
              primaryColor: B2BColors.primary,
              accentColor: B2BColors.gold,
            )
          else
            _buildLockedGeoCard(),
          const SizedBox(height: 20),
          InsightSection(
            title: 'Recent activity',
            subtitle: 'The latest views, likes, saves, shares and quote requests',
            child: ActivityList(activity: r.recentActivity),
          ),
        ],
      );
    });
  }

  Widget _topProducts(InsightsReport r) {
    return InsightSection(
      title: 'Top products',
      subtitle: 'Ranked by activity - quote requests weigh the most',
      trailing:
          const Icon(Icons.trending_up_rounded, color: B2BColors.gold, size: 20),
      child: r.topProducts.isEmpty
          ? Text('No product activity in this period yet.',
              style: B2BText.sans(size: 13, color: B2BColors.muted))
          : Column(
              children: [
                for (var i = 0; i < r.topProducts.length; i++)
                  _productRow(i + 1, r.topProducts[i]),
              ],
            ),
    );
  }

  Widget _productRow(int rank, InsightProduct p) {
    Widget stat(IconData icon, int n) => Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: B2BColors.faint),
            const SizedBox(width: 3),
            Text(compactCount(n),
                style: B2BText.sans(size: 12.5, color: B2BColors.inkSoft)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(
          width: 26,
          child: Text('$rank',
              style: B2BText.serif(size: 16, color: B2BColors.gold)),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(B2BRadius.sm),
          child: (p.image ?? '').isEmpty
              ? Container(
                  width: 46,
                  height: 46,
                  color: B2BColors.surfaceAlt,
                  child: const Icon(Icons.diamond_outlined,
                      size: 20, color: B2BColors.faint))
              : CachedNetworkImage(
                  imageUrl: p.image!,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                      width: 46, height: 46, color: B2BColors.surfaceAlt),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(p.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: B2BText.sans(size: 14, weight: FontWeight.w500)),
        ),
        stat(Icons.visibility_outlined, p.views),
        stat(Icons.favorite_border_rounded, p.likes),
        if (p.quoteRequests > 0) stat(Icons.request_quote_outlined, p.quoteRequests),
      ]),
    );
  }

  Widget _buildLockedGeoCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: b2bCardDecoration(),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Geographic Insights', style: B2BText.serif(size: 19)),
              const SizedBox(height: 6),
              Text('Detailed country, state, and pincode breakdown',
                  style: B2BText.sans(size: 13, color: B2BColors.muted)),
              const SizedBox(height: 28),
              for (int i = 0; i < 4; i++) ...[
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: B2BColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(B2BRadius.sm),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(B2BRadius.lg),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.4),
                  alignment: Alignment.center,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.all(24),
                    decoration: b2bCardDecoration(
                            lifted: true, radius: B2BRadius.xl)
                        .copyWith(
                            border: Border.all(color: const Color(0xFFE8D9BD))),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                              color: B2BColors.goldSoft, shape: BoxShape.circle),
                          child: const Icon(Icons.workspace_premium,
                              color: B2BColors.gold, size: 24),
                        ),
                        const SizedBox(height: 12),
                        Text('Unlock full insights',
                            style: B2BText.serif(size: 18)),
                        const SizedBox(height: 6),
                        Text(
                          'Get detailed location analytics, demand trends and actionable insights.',
                          textAlign: TextAlign.center,
                          style: B2BText.sans(size: 12.5, color: B2BColors.muted),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {},
                            style: FilledButton.styleFrom(
                                backgroundColor: B2BColors.gold),
                            child: const Text('Upgrade to Premium'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
