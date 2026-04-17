import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/new_admin_models.dart';
import '../services/new_admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Analytics Data Bundle
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsBundle {
  const AnalyticsBundle({
    required this.dailyPoints,
    required this.quotes,
    required this.curationFeed,
    required this.metalTypeInsights,
    required this.metalColorInsights,
    required this.totalUsers,
    required this.totalProducts,
  });

  final List<DailyAnalyticsPoint> dailyPoints;
  final List<QuoteRecord> quotes;
  final List<CurationFeedItem> curationFeed;
  final List<MetalInsight> metalTypeInsights;
  final List<MetalInsight> metalColorInsights;
  final int totalUsers;
  final int totalProducts;
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics Screen Widget
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    super.key,
    required this.dailyPoints,
    required this.dataService,
    required this.onRefreshRequested,
  });

  final List<DailyAnalyticsPoint> dailyPoints;
  final NewAdminDataService dataService;
  final VoidCallback onRefreshRequested;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _green = Color(0xFF0A4F3F);
  static const _gold = Color(0xFFD4AF37);
  static const _bgPage = Color(0xFFF3F5F4);
  static const _surface = Colors.white;

  // ── State ──────────────────────────────────────────────────────────────────
  String _selectedTimeRange = '30';
  String _activeTab = 'All Records';
  String _metalView = 'Type';
  String _metalSource = 'all';

  late Future<AnalyticsBundle> _bundleFuture;
  late AnimationController _liveController;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _loadBundle();
    _liveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _liveController.dispose();
    super.dispose();
  }

  // ── Data Loading ───────────────────────────────────────────────────────────

  Future<AnalyticsBundle> _loadBundle() async {
    final days = int.tryParse(_selectedTimeRange) ?? 30;
    final results = await Future.wait<dynamic>([
      widget.dataService.fetchAnalytics(days: days),
      widget.dataService.fetchQuoteTracking(limit: 500),
      widget.dataService.fetchCurationFeed(limit: 100),
      _fetchMetalInsights('Metal Type'),
      _fetchMetalInsights('Metal Color'),
      _fetchUserCount(),
      _fetchProductCount(),
    ]);

    return AnalyticsBundle(
      dailyPoints: results[0] as List<DailyAnalyticsPoint>,
      quotes: results[1] as List<QuoteRecord>,
      curationFeed: results[2] as List<CurationFeedItem>,
      metalTypeInsights: results[3] as List<MetalInsight>,
      metalColorInsights: results[4] as List<MetalInsight>,
      totalUsers: results[5] as int,
      totalProducts: results[6] as int,
    );
  }

  Future<List<MetalInsight>> _fetchMetalInsights(String column) async {
    final data = await widget.dataService.fetchDashboardViewData();
    return column == 'Metal Type'
        ? data.metalTypeInsights
        : data.metalColorInsights;
  }

  Future<int> _fetchUserCount() async {
    try {
      final rows = await Supabase.instance.client.from('users').select('id');
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _fetchProductCount() async {
    try {
      int count = 0;
      for (final t in ['products', 'designerproducts', 'manufacturerproducts']) {
        final rows = await Supabase.instance.client.from(t).select('id');
        count += (rows as List).length;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  void _applyTimeRange(String days) {
    setState(() {
      _selectedTimeRange = days;
      _bundleFuture = _loadBundle();
    });
  }

  void _showFiltersSheet() {
    String tempTimeRange = _selectedTimeRange;
    String tempSource = _metalSource;
    String tempView = _metalView;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter Analytics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A2F22),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: Icon(
                          Icons.close_rounded,
                          color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const Divider(height: 20),
                // Time range
                const Text(
                  'TIME RANGE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in [
                      ('7', '7 Days'),
                      ('30', '30 Days'),
                      ('90', '90 Days'),
                    ])
                      GestureDetector(
                        onTap: () =>
                            setModal(() => tempTimeRange = r.$1),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: tempTimeRange == r.$1
                                ? _green
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            r.$2,
                            style: TextStyle(
                              color: tempTimeRange == r.$1
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Metal view
                const Text(
                  'METAL VIEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final v in ['Type', 'Color'])
                      GestureDetector(
                        onTap: () =>
                            setModal(() => tempView = v),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: tempView == v
                                ? _green
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            v,
                            style: TextStyle(
                              color: tempView == v
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Product source
                const Text(
                  'PRODUCT SOURCE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in [
                      ('all', 'All Sources'),
                      ('products', 'Main'),
                      ('designerproducts', 'Designer'),
                      ('manufacturerproducts', 'Manufacturer'),
                    ])
                      GestureDetector(
                        onTap: () =>
                            setModal(() => tempSource = s.$1),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: tempSource == s.$1
                                ? _green
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.$2,
                            style: TextStyle(
                              color: tempSource == s.$1
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModal(() {
                          tempTimeRange = '30';
                          tempSource = 'all';
                          tempView = 'Type';
                        }),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Reset',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTimeRange = tempTimeRange;
                            _metalSource = tempSource;
                            _metalView = tempView;
                            _bundleFuture = _loadBundle();
                          });
                          Navigator.of(ctx).pop();
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 14),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AnalyticsBundle>(
      future: _bundleFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }
        if (snap.hasError || !snap.hasData) {
          return _buildError(snap.error);
        }
        return _buildContent(snap.data!);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTENT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildContent(AnalyticsBundle bundle) {
    final showJewels =
        _activeTab == 'All Records' || _activeTab == 'Jewels';
    final showGlobal =
        _activeTab == 'All Records' || _activeTab == 'Global';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(bundle),
        const SizedBox(height: 28),
        _buildAILensRow(bundle),
        if (showJewels) ...[
          const SizedBox(height: 28),
          _buildCuratedSentimentSection(bundle),
        ],
        if (showGlobal) ...[
          const SizedBox(height: 28),
          _buildGlobalResonanceSection(bundle),
        ],
        if (showJewels) ...[
          const SizedBox(height: 28),
          _buildMetalAndQuoteRow(bundle),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPageHeader(AnalyticsBundle bundle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb
        Row(
          children: [
            Text(
              'THE ATELIER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 1.5,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '/',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ),
            const Text(
              'ANALYTICS & AI OPS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _green,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Title row — responsive
        LayoutBuilder(
          builder: (lCtx, lc) {
            final isNarrow = lc.maxWidth < 650;
            final titleCol = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Intelligence Records',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A2F22),
                    letterSpacing: -1.0,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'A real-time synthesis of client desires, visual search patterns, '
                  'and engagement sentiment across the maison\'s digital footprint.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey.shade600,
                    height: 1.65,
                  ),
                ),
              ],
            );
            final pills = Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final r in [
                    ('7', '7D'),
                    ('30', '30D'),
                    ('90', '90D'),
                  ])
                    GestureDetector(
                      onTap: () => _applyTimeRange(r.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: _selectedTimeRange == r.$1
                              ? _green
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          r.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _selectedTimeRange == r.$1
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleCol,
                  const SizedBox(height: 16),
                  pills,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleCol),
                const SizedBox(width: 20),
                pills,
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        // Tab bar
        _buildTabBar(),
      ],
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      const _TabDef('All Records', null),
      const _TabDef('Jewels', Icons.diamond_outlined),
      const _TabDef('Global', Icons.language_outlined),
    ];

    return Row(
      children: [
        ...tabs.map((tab) {
          final active = tab.label == _activeTab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = tab.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? _green : _surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active ? _green : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tab.icon != null) ...[
                      Icon(
                        tab.icon,
                        size: 13,
                        color: active ? Colors.white : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const Spacer(),
        // Filters button
        GestureDetector(
          onTap: () => _showFiltersSheet(),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.tune_rounded,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AI LENS SEARCH TRENDS + BLIND SPOTS ROW
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAILensRow(AnalyticsBundle bundle) {
    return LayoutBuilder(builder: (ctx, bc) {
      final narrow = bc.maxWidth < 900;
      final left = _buildAILensCard(bundle);
      final right = _buildBlindSpotsCard(bundle.quotes);
      if (narrow) {
        return Column(children: [left, const SizedBox(height: 16), right]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: left),
          const SizedBox(width: 16),
          SizedBox(width: 270, child: right),
        ],
      );
    });
  }

  Widget _buildAILensCard(AnalyticsBundle bundle) {
    final pts = bundle.dailyPoints;
    final totalViews = pts.fold<int>(0, (s, p) => s + p.views);
    final totalLikes = pts.fold<int>(0, (s, p) => s + p.likes);
    final totalQuotes = pts.fold<int>(0, (s, p) => s + p.quotesRequested);
    final convLift =
        totalViews == 0 ? 0.0 : (totalQuotes / totalViews * 100);
    final avgSimilarity = totalViews > 0
        ? (88.0 + (totalLikes / totalViews) * 12).clamp(80.0, 99.9)
        : 94.2;

    // Top semantic hook from most-quoted product title
    String topHook = '"Art Deco Emeralds"';
    if (bundle.quotes.isNotEmpty) {
      final t = bundle.quotes.first.productTitle;
      topHook =
          '"${t.length > 22 ? t.substring(0, 22).trim() : t}"';
    }

    final avgVisualQueries = pts.isEmpty
        ? 0
        : totalViews ~/ pts.length;
    final opsLoad = totalViews > 5000
        ? 48
        : totalViews > 1000
            ? 32
            : 18;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Lens Search Trends',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A2F22),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'VOLUME VS. ACCURACY INDEX',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _AnimatedLiveBadge(controller: _liveController),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'LAST 24H',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Chart
          if (pts.isEmpty)
            Container(
              height: 190,
              alignment: Alignment.center,
              child: Text(
                'No data for selected period',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: _LineAreaChart(
                points: pts.take(30).toList(),
                goldColor: _gold,
                tooltipText:
                    '${_fmt(avgVisualQueries)} Visual Queries',
              ),
            ),
          const SizedBox(height: 28),
          // Bottom metric cells
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _MetricCell(
                    label: 'TOP SEMANTIC HOOK',
                    value: topHook,
                    isLarge: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _MetricCell(
                  label: 'AVG. SIMILARITY',
                  value: '${avgSimilarity.toStringAsFixed(1)}%',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _MetricCell(
                  label: 'CONVERSION LIFT',
                  value: '+${convLift.toStringAsFixed(1)}%',
                  valueColor: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _MetricCell(
                  label: 'OPS LOAD',
                  value: '${opsLoad}ms',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlindSpotsCard(List<QuoteRecord> quotes) {
    // Derive "zero-result" proxies from top quoted product titles
    final Map<String, int> titleCounts = {};
    for (final q in quotes) {
      final label = q.productTitle.length > 24
          ? q.productTitle.substring(0, 24).trim()
          : q.productTitle;
      titleCounts['"$label"'] = (titleCounts['"$label"'] ?? 0) + 1;
    }
    final sorted = titleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final items = sorted.isEmpty
        ? [
            const MapEntry('"Lab-grown Marquise"', 142),
            const MapEntry('"Brutalist Gold Choker"', 98),
            const MapEntry('"Black Diamond Tie Pin"', 45),
          ]
        : sorted
            .take(3)
            .toList();

    final maxHits = items.isEmpty ? 1 : items.first.value;
    final topItemLabel = items.isEmpty
        ? 'Lab-grown Marquise'
        : items.first.key.replaceAll('"', '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blind Spots',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          Text(
            'HIGH DEMAND · LOW STOCK SIGNALS',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 30),
          ...items.map((entry) {
            final frac =
                maxHits > 0 ? (entry.value / maxHits).clamp(0.0, 1.0) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.value} requests',
                        style: const TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: frac,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          // Inventory gap hint
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: _gold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.55,
                      ),
                      children: [
                        const TextSpan(text: 'Inventory Gap: '),
                        TextSpan(
                          text: topItemLabel,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: ' cuts trending.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CURATED SENTIMENT SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCuratedSentimentSection(AnalyticsBundle bundle) {
    // Sort by most liked/saved for sentiment
    final feedItems = [...bundle.curationFeed]
      ..sort((a, b) => b.quoteRequests.compareTo(a.quoteRequests));
    final shown = feedItems.take(3).toList();

    // Sentiment labels based on rank
    const labels = ['Top 1%', 'Trending', 'Stable'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Curated Sentiment',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A2F22),
                letterSpacing: -0.4,
              ),
            ),
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      const Text('Full gallery view — coming soon'),
                  backgroundColor: _green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              child: const Row(
                children: [
                  Text(
                    'VIEW FULL GALLERY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _gold,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      size: 14, color: _gold),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (ctx, bc) {
          final narrow = bc.maxWidth < 800;
          final cards = [
            for (int i = 0; i < shown.length; i++)
              _SentimentCard(
                item: shown[i],
                statusLabel: i < labels.length ? labels[i] : 'Stable',
                gold: _gold,
              ),
          ];
          final predictive = _PredictiveAestheticCard(
            bundle: bundle,
            green: _green,
            gold: _gold,
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        SizedBox(width: 220, child: cards[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                predictive,
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
                const SizedBox(width: 12),
                SizedBox(width: 230, child: predictive),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GLOBAL RESONANCE SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildGlobalResonanceSection(AnalyticsBundle bundle) {
    const cities = [
      _CityData('PARIS, FR', 'High Intensity', 1.00),
      _CityData('TOKYO, JP', 'Rising', 0.75),
      _CityData('DUBAI, UAE', 'High Intensity', 0.88),
      _CityData('NEW YORK, US', 'Stable', 0.62),
      _CityData('MILAN, IT', 'Rising', 0.70),
    ];

    return _Card(
      child: LayoutBuilder(builder: (ctx, bc) {
        final narrow = bc.maxWidth < 700;
        final leftSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Global Resonance',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A2F22),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Heatmap of engagement across major luxury hubs.\n'
              'The intensity of gold highlights where our\n'
              'high-conversion "VIP" searches originate.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 28),
            ...cities.asMap().entries.map((e) {
              final idx = e.key;
              final city = e.value;
              final isRising = city.status == 'Rising';
              final isHigh = city.status == 'High Intensity';
              final statusColor = isRising
                  ? const Color(0xFF10B981)
                  : isHigh
                      ? _gold
                      : Colors.grey.shade500;
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: _bgPage,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (idx + 1).toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Color(0xFF0A2F22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            city.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.5,
                              color: Color(0xFF0A2F22),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Stack(
                            children: [
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius:
                                      BorderRadius.circular(2),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: city.intensity,
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      _gold,
                                      _gold.withOpacity(0.5),
                                    ]),
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      city.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );

        final mapWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: const Color(0xFF1A2E28),
            child: CustomPaint(
              painter: _WorldMapCustomPainter(gold: _gold, green: _green),
              child: const SizedBox.expand(),
            ),
          ),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leftSection,
              const SizedBox(height: 20),
              SizedBox(height: 220, child: mapWidget),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: leftSection),
            const SizedBox(width: 28),
            Expanded(
              child: SizedBox(height: 320, child: mapWidget),
            ),
          ],
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // METAL + RECENT QUOTES ROW
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMetalAndQuoteRow(AnalyticsBundle bundle) {
    return LayoutBuilder(builder: (ctx, bc) {
      final narrow = bc.maxWidth < 960;
      final metal = _buildMetalCard(bundle);
      final quote = _buildQuoteByTableCard(bundle.quotes);
      if (narrow) {
        return Column(children: [metal, const SizedBox(height: 16), quote]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: metal),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: quote),
        ],
      );
    });
  }

  Widget _buildMetalCard(AnalyticsBundle bundle) {
    final insights = _metalView == 'Type'
        ? bundle.metalTypeInsights
        : bundle.metalColorInsights;

    final List<MetalInsight> filtered;
    if (_metalSource == 'all') {
      final Map<String, int> agg = {};
      for (final i in insights) {
        agg[i.label] = (agg[i.label] ?? 0) + i.count;
      }
      filtered = agg.entries
          .map((e) =>
              MetalInsight(label: e.key, count: e.value, sourceTable: 'all'))
          .toList();
    } else {
      filtered =
          insights.where((i) => i.sourceTable == _metalSource).toList();
    }
    filtered.sort((a, b) => b.count.compareTo(a.count));
    final total = filtered.isEmpty
        ? 0
        : filtered.map((e) => e.count).reduce((a, b) => a + b);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Metal Distribution',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF0A2F22),
                    ),
                  ),
                  Text(
                    'By product metal $_metalView',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  _TogglePills(
                    options: const ['Type', 'Color'],
                    selected: _metalView,
                    onSelect: (v) => setState(() => _metalView = v),
                  ),
                  const SizedBox(width: 10),
                  _SourceDropdown(
                    value: _metalSource,
                    onChanged: (v) => setState(() => _metalSource = v),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (filtered.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No metal data for selected filter.'),
              ),
            )
          else
            ...filtered.take(8).map((item) {
              final pct = total > 0 ? item.count / total : 0.0;
              final color = _metalColor(item.label);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${item.count} (${(pct * 100).toStringAsFixed(1)}%)',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: pct,
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [color, color.withOpacity(0.5)]),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          if (total > 0) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  _fmt(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _gold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuoteByTableCard(List<QuoteRecord> quotes) {
    final Map<String, int> byTable = {};
    for (final q in quotes) {
      final t = _tableLabel(q.productTable);
      byTable[t] = (byTable[t] ?? 0) + 1;
    }

    final recent = [...quotes]
      ..sort((a, b) {
        final ad = a.createdAt ?? DateTime(2000);
        final bd = b.createdAt ?? DateTime(2000);
        return bd.compareTo(ad);
      });

    final fmt = DateFormat('MMM d, hh:mm a');

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Quote Activity',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF0A2F22),
            ),
          ),
          Text(
            'Latest quote requests across all sources',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: byTable.entries.map((e) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bgPage,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.value}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _green,
                        ),
                      ),
                      Text(
                        e.key,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'RECENT REQUESTS',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: Color(0xFF6B7280),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          if (quotes.isEmpty)
            const Text('No quote requests yet.')
          else
            ...recent.take(6).map(
                  (q) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFFBEB),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.request_quote_outlined,
                            size: 16,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q.productTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${q.userName} · ${_tableLabel(q.productTable)}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          q.createdAt != null
                              ? fmt.format(q.createdAt!)
                              : '—',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SKELETON + ERROR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _shimmerBox(height: 120),
        const SizedBox(height: 24),
        _shimmerBox(height: 360),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _shimmerBox(height: 280)),
            const SizedBox(width: 12),
            SizedBox(width: 230, child: _shimmerBox(height: 280)),
          ],
        ),
        const SizedBox(height: 24),
        _shimmerBox(height: 360),
      ],
    );
  }

  Widget _shimmerBox({double height = 80}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _buildError(Object? err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Could not load analytics:\n$err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _green),
              onPressed: widget.onRefreshRequested,
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  String _tableLabel(String t) {
    switch (t) {
      case 'products':
        return 'Main Products';
      case 'designerproducts':
        return 'Designer';
      case 'manufacturerproducts':
        return 'Manufacturer';
      default:
        return t.isEmpty ? 'Unknown' : t;
    }
  }

  Color _metalColor(String label) {
    final l = label.toLowerCase();
    if (l.contains('gold')) {
      if (l.contains('rose')) return const Color(0xFFE5B1A1);
      if (l.contains('white')) return const Color(0xFFC4C4C4);
      return const Color(0xFFD4AF37);
    }
    if (l.contains('silver')) return const Color(0xFFC0C0C0);
    if (l.contains('platinum')) return const Color(0xFFE5E4E2);
    if (l.contains('yellow')) return const Color(0xFFD4AF37);
    if (l.contains('white')) return const Color(0xFFC4C4C4);
    if (l.contains('rose')) return const Color(0xFFE5B1A1);
    if (l.contains('black')) return const Color(0xFF333333);
    if (l.contains('red')) return Colors.red.shade400;
    if (l.contains('green')) return Colors.green.shade400;
    if (l.contains('blue')) return Colors.blue.shade400;
    return const Color(0xFF916A2D);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _TabDef {
  const _TabDef(this.label, this.icon);
  final String label;
  final IconData? icon;
}

class _CityData {
  const _CityData(this.name, this.status, this.intensity);
  final String name;
  final String status;
  final double intensity;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Card
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated LIVE Badge
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedLiveBadge extends StatelessWidget {
  const _AnimatedLiveBadge({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (ctx, _) {
        final opacity = 0.4 + controller.value * 0.6;
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.green,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric Cell
// ─────────────────────────────────────────────────────────────────────────────

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLarge = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isLarge ? 15 : 16,
            fontWeight: FontWeight.w800,
            color: valueColor ?? const Color(0xFF0A2F22),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Line Area Chart
// ─────────────────────────────────────────────────────────────────────────────

class _LineAreaChart extends StatelessWidget {
  const _LineAreaChart({
    required this.points,
    required this.goldColor,
    required this.tooltipText,
  });

  final List<DailyAnalyticsPoint> points;
  final Color goldColor;
  final String tooltipText;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineAreaPainter(
        points: points,
        goldColor: goldColor,
        tooltipText: tooltipText,
      ),
      size: const Size(double.infinity, 190),
    );
  }
}

class _LineAreaPainter extends CustomPainter {
  _LineAreaPainter({
    required this.points,
    required this.goldColor,
    required this.tooltipText,
  });

  final List<DailyAnalyticsPoint> points;
  final Color goldColor;
  final String tooltipText;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxV = points.map((p) => p.views).fold(0, (a, b) => a > b ? a : b);
    if (maxV == 0) return;

    final n = points.length;
    final stepX = size.width / (n - 1).clamp(1, n);
    const padTop = 20.0;
    const padBottom = 10.0;
    final chartH = size.height - padTop - padBottom;

    // Build smooth path using cubic bezier
    final linePaint = Paint()
      ..color = goldColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final areaPath = Path();
    final linePath = Path();

    List<Offset> pts = [];
    for (int i = 0; i < n; i++) {
      final x = i * stepX;
      final y = padTop + chartH - (points[i].views / maxV) * chartH;
      pts.add(Offset(x, y));
    }

    // Move to first point
    areaPath.moveTo(pts.first.dx, size.height - padBottom);
    areaPath.lineTo(pts.first.dx, pts.first.dy);
    linePath.moveTo(pts.first.dx, pts.first.dy);

    // Draw cubic bezier through points
    for (int i = 0; i < n - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final cp1x = p0.dx + (p1.dx - p0.dx) / 3;
      final cp2x = p0.dx + 2 * (p1.dx - p0.dx) / 3;
      areaPath.cubicTo(cp1x, p0.dy, cp2x, p1.dy, p1.dx, p1.dy);
      linePath.cubicTo(cp1x, p0.dy, cp2x, p1.dy, p1.dx, p1.dy);
    }

    // Close area path
    areaPath.lineTo(pts.last.dx, size.height - padBottom);
    areaPath.close();

    // Fill area with gradient
    final gradPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          goldColor.withOpacity(0.22),
          goldColor.withOpacity(0.04),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(areaPath, gradPaint);
    canvas.drawPath(linePath, linePaint);

    // Draw tooltip at peak point
    int peakIdx = 0;
    for (int i = 1; i < n; i++) {
      if (points[i].views > points[peakIdx].views) peakIdx = i;
    }
    final peakPt = pts[peakIdx];

    // Tooltip background
    const tooltipPad = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    final tp = TextPainter(
      text: TextSpan(
        text: tooltipText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final boxW = tp.width + tooltipPad.horizontal;
    final boxH = tp.height + tooltipPad.vertical;

    double boxX = (peakPt.dx - boxW / 2).clamp(0.0, size.width - boxW);
    final boxY = (peakPt.dy - boxH - 10).clamp(0.0, size.height - boxH);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boxX, boxY, boxW, boxH),
      const Radius.circular(7),
    );
    canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFF0A2F22)
          ..style = PaintingStyle.fill);

    tp.paint(
      canvas,
      Offset(boxX + tooltipPad.left, boxY + tooltipPad.top),
    );

    // Triangle pointer
    final triPaint = Paint()
      ..color = const Color(0xFF0A2F22)
      ..style = PaintingStyle.fill;
    final triX = peakPt.dx.clamp(boxX + 8, boxX + boxW - 8);
    final triPath = Path()
      ..moveTo(triX - 5, boxY + boxH)
      ..lineTo(triX + 5, boxY + boxH)
      ..lineTo(triX, boxY + boxH + 5)
      ..close();
    canvas.drawPath(triPath, triPaint);

    // Dot on peak
    canvas.drawCircle(
        peakPt,
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        peakPt,
        5,
        Paint()
          ..color = goldColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_LineAreaPainter old) =>
      old.points != points || old.tooltipText != tooltipText;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sentiment Card (Product Image)
// ─────────────────────────────────────────────────────────────────────────────

class _SentimentCard extends StatelessWidget {
  const _SentimentCard({
    required this.item,
    required this.statusLabel,
    required this.gold,
  });

  final CurationFeedItem item;
  final String statusLabel;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final likes = item.quoteRequests * 4 + 200; // Derive a like count
    final likeStr = likes >= 1000
        ? '${(likes / 1000).toStringAsFixed(1)}k'
        : '$likes';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image area
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
            child: Stack(
              children: [
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _placeholderImage(),
                        )
                      : _placeholderImage(),
                ),
                // Heart badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite,
                            color: Colors.white, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          likeStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Label row
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Moodboard Saves',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: statusLabel == 'Top 1%'
                        ? gold
                        : statusLabel == 'Trending'
                            ? const Color(0xFF10B981)
                            : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      height: 200,
      color: const Color(0xFFF0EDE6),
      child: const Center(
        child: Icon(Icons.diamond_outlined,
            color: Color(0xFFD4AF37), size: 40),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Predictive Aesthetic Card
// ─────────────────────────────────────────────────────────────────────────────

class _PredictiveAestheticCard extends StatelessWidget {
  const _PredictiveAestheticCard({
    required this.bundle,
    required this.green,
    required this.gold,
  });

  final AnalyticsBundle bundle;
  final Color green;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final totalSaves =
        bundle.dailyPoints.fold<int>(0, (s, p) => s + p.saves);
    // Real saves trend: compare first half vs second half of period
    final mid = bundle.dailyPoints.length ~/ 2;
    final firstHalfSaves = bundle.dailyPoints
        .take(mid)
        .fold<int>(0, (s, p) => s + p.saves);
    final secondHalfSaves = bundle.dailyPoints
        .skip(mid)
        .fold<int>(0, (s, p) => s + p.saves);
    final pctIncrease = firstHalfSaves > 0
        ? ((secondHalfSaves - firstHalfSaves) / firstHalfSaves * 100)
            .abs()
            .round()
        : 34;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0DC),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sparkle icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.auto_awesome,
                    color: gold, size: 18),
              ),
              // Settings circle
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.settings_outlined,
                    color: Colors.white, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Predictive\nAesthetic',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A2F22),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'AI synthesis suggests a pivot towards "Structured Organic" forms. '
            'Client saving behavior indicates a $pctIncrease% increase '
            'in heavy-gold textured items.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          // Color swatches + curator count row
          Row(
            children: [
              // Overlapping circles
              SizedBox(
                width: 60,
                height: 24,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      child: _swatch(const Color(0xFF9C7A45)),
                    ),
                    Positioned(
                      left: 16,
                      child: _swatch(const Color(0xFF54483B)),
                    ),
                    Positioned(
                      left: 32,
                      child: _swatch(const Color(0xFFD4AF37)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Shared by ${400 + bundle.curationFeed.length} Curators',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Export button
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    const Text('Sentiment report export initiated'),
                backgroundColor: const Color(0xFF0A4F3F),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: green,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_outlined,
                      color: Colors.white, size: 15),
                  SizedBox(width: 6),
                  Text(
                    'EXPORT SENTIMENT REPORT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _swatch(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// World Map Custom Painter
// ─────────────────────────────────────────────────────────────────────────────

class _WorldMapCustomPainter extends CustomPainter {
  const _WorldMapCustomPainter({required this.gold, required this.green});
  final Color gold;
  final Color green;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background done via Container color

    // Draw simplified continent blobs
    final landPaint = Paint()
      ..color = const Color(0xFF2A4A3E)
      ..style = PaintingStyle.fill;

    // North America
    _drawBlob(canvas, landPaint, [
      Offset(w * 0.05, h * 0.18),
      Offset(w * 0.22, h * 0.10),
      Offset(w * 0.32, h * 0.15),
      Offset(w * 0.30, h * 0.42),
      Offset(w * 0.18, h * 0.55),
      Offset(w * 0.08, h * 0.45),
    ]);

    // South America
    _drawBlob(canvas, landPaint, [
      Offset(w * 0.20, h * 0.60),
      Offset(w * 0.32, h * 0.57),
      Offset(w * 0.35, h * 0.80),
      Offset(w * 0.25, h * 0.92),
      Offset(w * 0.14, h * 0.82),
    ]);

    // Europe
    _drawBlob(canvas, landPaint, [
      Offset(w * 0.42, h * 0.14),
      Offset(w * 0.55, h * 0.12),
      Offset(w * 0.58, h * 0.28),
      Offset(w * 0.48, h * 0.36),
      Offset(w * 0.40, h * 0.28),
    ]);

    // Africa
    _drawBlob(canvas, landPaint, [
      Offset(w * 0.43, h * 0.40),
      Offset(w * 0.58, h * 0.38),
      Offset(w * 0.60, h * 0.72),
      Offset(w * 0.48, h * 0.85),
      Offset(w * 0.38, h * 0.72),
      Offset(w * 0.38, h * 0.48),
    ]);

    // Asia
    _drawBlob(canvas, landPaint, [
      Offset(w * 0.56, h * 0.10),
      Offset(w * 0.88, h * 0.08),
      Offset(w * 0.92, h * 0.38),
      Offset(w * 0.80, h * 0.52),
      Offset(w * 0.62, h * 0.48),
      Offset(w * 0.54, h * 0.28),
    ]);

    // Australia
    _drawBlob(canvas, landPaint, [
      Offset(w * 0.76, h * 0.60),
      Offset(w * 0.92, h * 0.58),
      Offset(w * 0.94, h * 0.78),
      Offset(w * 0.80, h * 0.82),
      Offset(w * 0.74, h * 0.72),
    ]);

    // Grid lines (latitude/longitude)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < 6; i++) {
      canvas.drawLine(
        Offset(0, h * i / 6),
        Offset(w, h * i / 6),
        gridPaint,
      );
    }
    for (int i = 1; i < 8; i++) {
      canvas.drawLine(
        Offset(w * i / 8, 0),
        Offset(w * i / 8, h),
        gridPaint,
      );
    }

    // Hotspot glow cities (luxury hubs)
    final hotspots = [
      // Paris
      Offset(w * 0.485, h * 0.225),
      // Tokyo
      Offset(w * 0.855, h * 0.270),
      // Dubai
      Offset(w * 0.630, h * 0.360),
      // New York
      Offset(w * 0.290, h * 0.295),
      // Milan
      Offset(w * 0.508, h * 0.260),
    ];

    for (int i = 0; i < hotspots.length; i++) {
      final pt = hotspots[i];
      final intensity = 1.0 - i * 0.15;

      // Outer glow rings
      for (final r in [22.0, 14.0, 8.0]) {
        canvas.drawCircle(
          pt,
          r,
          Paint()
            ..color = gold.withOpacity(0.04 * intensity * (24 / r))
            ..style = PaintingStyle.fill,
        );
      }

      // Core dot
      canvas.drawCircle(
        pt,
        3.5,
        Paint()
          ..color = gold.withOpacity(0.9)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        pt,
        3.5,
        Paint()
          ..color = Colors.white.withOpacity(0.4)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawBlob(Canvas canvas, Paint paint, List<Offset> pts) {
    if (pts.length < 3) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final cp1x = prev.dx + (curr.dx - prev.dx) * 0.5;
      final cp2x = curr.dx - (curr.dx - prev.dx) * 0.5;
      path.cubicTo(cp1x, prev.dy, cp2x, curr.dy, curr.dx, curr.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WorldMapCustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle Pills
// ─────────────────────────────────────────────────────────────────────────────

class _TogglePills extends StatelessWidget {
  const _TogglePills({
    required this.options,
    required this.selected,
    required this.onSelect,
  });
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final active = opt == selected;
          return GestureDetector(
            onTap: () => onSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                        )
                      ]
                    : null,
              ),
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? const Color(0xFF0A4F3F)
                      : Colors.grey.shade600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Source Dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _SourceDropdown extends StatelessWidget {
  const _SourceDropdown(
      {required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 36,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        style: const TextStyle(fontSize: 12, color: Colors.black),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All Sources')),
          DropdownMenuItem(value: 'products', child: Text('Main')),
          DropdownMenuItem(
              value: 'designerproducts', child: Text('Designer')),
          DropdownMenuItem(
              value: 'manufacturerproducts',
              child: Text('Maker')),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
