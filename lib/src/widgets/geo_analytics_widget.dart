import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Shared Geo Analytics Widget
/// ─────────────────────────────────────────────────────────────────────────────
/// A full-featured, reusable analytics dashboard widget matching the reference
/// Geo Analytics UI. Displays views, likes, shares, and saves broken down by
/// country, state, and pincode.
///
/// Used by Admin, Designer, and B2B/Manufacturer analytics screens.
/// ─────────────────────────────────────────────────────────────────────────────

// ── Data model ──────────────────────────────────────────────────────────────

class GeoAnalyticsData {
  final int totalViews;
  final int totalLikes;
  final int totalShares;
  final int totalSaves;
  final Map<String, Map<String, int>> byCountry;
  final Map<String, Map<String, int>> byState;
  final Map<String, Map<String, int>> byPincode;
  // item_id -> {views, likes, shares, saves}
  final Map<String, Map<String, int>> byProduct;
  // item_id -> table name (e.g. 'designerproducts')
  final Map<String, String> itemTables;

  const GeoAnalyticsData({
    required this.totalViews,
    required this.totalLikes,
    required this.totalShares,
    required this.totalSaves,
    required this.byCountry,
    required this.byState,
    required this.byPincode,
    this.byProduct = const {},
    this.itemTables = const {},
  });

  static const empty = GeoAnalyticsData(
    totalViews: 0,
    totalLikes: 0,
    totalShares: 0,
    totalSaves: 0,
    byCountry: {},
    byState: {},
    byPincode: {},
    byProduct: {},
    itemTables: {},
  );
}

// ── Main widget ─────────────────────────────────────────────────────────────

class GeoAnalyticsWidget extends StatefulWidget {
  const GeoAnalyticsWidget({
    super.key,
    required this.data,
    this.title = 'Geo Analytics',
    this.subtitle =
        'Analyze views, likes, shares and saves of product posts by country, state and pincode.',
    this.primaryColor = const Color(0xFF0A4F3F),
    this.accentColor = const Color(0xFFD4AF37),
  });

  final GeoAnalyticsData data;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final Color accentColor;

  @override
  State<GeoAnalyticsWidget> createState() => _GeoAnalyticsWidgetState();
}

class _GeoAnalyticsWidgetState extends State<GeoAnalyticsWidget>
    with SingleTickerProviderStateMixin {
  int _activeTab = 0; // 0=Overview, 1=Country, 2=State, 3=Pincode
  String _sortBy = 'views';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return NumberFormat('#,##0').format(n);
  }

  Color get _viewsColor => widget.primaryColor;
  Color get _likesColor => const Color(0xFFE84393);
  Color get _sharesColor => widget.accentColor;
  Color get _savesColor => const Color(0xFFF39C12);

  List<MapEntry<String, Map<String, int>>> _sortedEntries(
      Map<String, Map<String, int>> data) {
    final entries = data.entries.toList();
    entries.sort((a, b) {
      final aVal = a.value[_sortBy] ?? 0;
      final bVal = b.value[_sortBy] ?? 0;
      return bVal.compareTo(aVal);
    });
    return entries;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(),
        const SizedBox(height: 20),

        // Tabs
        _buildTabs(),
        const SizedBox(height: 20),

        // KPI Cards
        _buildKPIRow(d),
        const SizedBox(height: 20),

        // Tab Content
        if (_activeTab == 0) _buildOverviewTab(d),
        if (_activeTab == 1) _buildGeoTable(d.byCountry, 'Country'),
        if (_activeTab == 2) _buildGeoTable(d.byState, 'State'),
        if (_activeTab == 3) _buildGeoTable(d.byPincode, 'Pincode'),

        // Footer note
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'All metrics are unique and aggregated based on your product portfolio.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tabs ────────────────────────────────────────────────────────────────────

  Widget _buildTabs() {
    final tabs = ['Overview', 'Country', 'State', 'Pincode'];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: widget.primaryColor,
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        indicatorColor: widget.primaryColor,
        indicatorWeight: 2.5,
        dividerColor: Colors.transparent,
        tabs: tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  // ── KPI Cards ──────────────────────────────────────────────────────────────

  Widget _buildKPIRow(GeoAnalyticsData d) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final isWide = constraints.maxWidth > 700;
      final cards = [
        _buildKPICard(
          icon: Icons.visibility_outlined,
          iconBg: _viewsColor.withValues(alpha: 0.1),
          iconColor: _viewsColor,
          label: 'Views',
          value: d.totalViews,
          metric: 'views',
        ),
        _buildKPICard(
          icon: Icons.favorite_outline,
          iconBg: _likesColor.withValues(alpha: 0.1),
          iconColor: _likesColor,
          label: 'Likes',
          value: d.totalLikes,
          metric: 'likes',
        ),
        _buildKPICard(
          icon: Icons.share_outlined,
          iconBg: _sharesColor.withValues(alpha: 0.1),
          iconColor: _sharesColor,
          label: 'Shares',
          value: d.totalShares,
          metric: 'shares',
        ),
        _buildKPICard(
          icon: Icons.bookmark_outline,
          iconBg: _savesColor.withValues(alpha: 0.1),
          iconColor: _savesColor,
          label: 'Saves',
          value: d.totalSaves,
          metric: 'saves',
        ),
      ];

      if (isWide) {
        return Row(
          children: cards
              .map((c) => Expanded(child: c))
              .toList()
              .expand((w) => [w, const SizedBox(width: 12)])
              .toList()
            ..removeLast(),
        );
      }
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards
            .map((c) => SizedBox(
                width: (constraints.maxWidth - 12) / 2, child: c))
            .toList(),
      );
    });
  }

  void _showProductBreakdown(BuildContext ctx, String metric) {
    final d = widget.data;
    if (d.byProduct.isEmpty) return;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductBreakdownSheet(
        metric: metric,
        byProduct: d.byProduct,
        itemTables: d.itemTables,
        primaryColor: widget.primaryColor,
        accentColor: widget.accentColor,
      ),
    );
  }

  Widget _buildKPICard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required int value,
    required String metric,
  }) {
    final hasData = widget.data.byProduct.isNotEmpty;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: hasData ? () => _showProductBreakdown(context, metric) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (hasData) ...
                          [const SizedBox(width: 4),
                          Icon(Icons.open_in_new, size: 10, color: Colors.grey.shade400)],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmt(value),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Overview Tab ───────────────────────────────────────────────────────────

  Widget _buildOverviewTab(GeoAnalyticsData d) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final isWide = constraints.maxWidth > 800;
      if (isWide) {
        return Column(
          children: [
            // Top Countries + Top States side by side
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _buildTopCard(
                        d.byCountry, 'Top Countries', 'Country')),
                const SizedBox(width: 16),
                Expanded(
                    child:
                        _buildTopCard(d.byState, 'Top States', 'State')),
              ],
            ),
            const SizedBox(height: 16),
            // Top Pincodes
            _buildTopCard(d.byPincode, 'Top Pincodes', 'Pincode'),
          ],
        );
      }
      return Column(
        children: [
          _buildTopCard(d.byCountry, 'Top Countries', 'Country'),
          const SizedBox(height: 16),
          _buildTopCard(d.byState, 'Top States', 'State'),
          const SizedBox(height: 16),
          _buildTopCard(d.byPincode, 'Top Pincodes', 'Pincode'),
        ],
      );
    });
  }

  // ── Top Card (compact table) ───────────────────────────────────────────────

  Widget _buildTopCard(
      Map<String, Map<String, int>> data, String title, String colLabel) {
    final sorted = _sortedEntries(data);
    final top5 = sorted.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                _buildSortDropdown(),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTableHeaderRow(colLabel),
          ),

          const Divider(height: 1),

          // Rows
          if (top5.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No data available yet',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade400),
                ),
              ),
            )
          else
            ...top5.map((entry) => _buildDataRow(entry.key, entry.value)),

          // "View all" link
          if (sorted.length > 5)
            InkWell(
              onTap: () {
                // Switch to the full tab
                final tabIndex =
                    colLabel == 'Country' ? 1 : (colLabel == 'State' ? 2 : 3);
                _tabController.animateTo(tabIndex);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    Text(
                      'View all ${colLabel.toLowerCase()}s',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: widget.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward,
                        size: 14, color: widget.primaryColor),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Full Geo Table (for individual tabs) ───────────────────────────────────

  Widget _buildGeoTable(
      Map<String, Map<String, int>> data, String colLabel) {
    final sorted = _sortedEntries(data);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Performance by $colLabel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                _buildSortDropdown(),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTableHeaderRow(colLabel),
          ),
          const Divider(height: 1),

          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.analytics_outlined,
                        size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'No ${colLabel.toLowerCase()} data available yet',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            )
          else
            ...sorted.map((entry) => _buildDataRow(entry.key, entry.value)),
        ],
      ),
    );
  }

  // ── Table header row ───────────────────────────────────────────────────────

  Widget _buildTableHeaderRow(String firstCol) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              firstCol,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          _metricHeaderIcon(Icons.visibility_outlined, _viewsColor, 'views'),
          _metricHeaderIcon(Icons.favorite_outline, _likesColor, 'likes'),
          _metricHeaderIcon(Icons.share_outlined, _sharesColor, 'shares'),
          _metricHeaderIcon(Icons.bookmark_outline, _savesColor, 'saves'),
        ],
      ),
    );
  }

  Widget _metricHeaderIcon(IconData icon, Color color, String metric) {
    final isActive = _sortBy == metric;
    return Expanded(
      flex: 2,
      child: InkWell(
        onTap: () => setState(() => _sortBy = metric),
        borderRadius: BorderRadius.circular(4),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: isActive ? color : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  // ── Data row ───────────────────────────────────────────────────────────────

  Widget _buildDataRow(String name, Map<String, int> metrics) {
    final views = metrics['views'] ?? 0;
    final likes = metrics['likes'] ?? 0;
    final shares = metrics['shares'] ?? 0;
    final saves = metrics['saves'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                name.isNotEmpty ? name : '(Unknown)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _metricValue(views, _viewsColor),
            _metricValue(likes, _likesColor),
            _metricValue(shares, _sharesColor),
            _metricValue(saves, _savesColor),
          ],
        ),
      ),
    );
  }

  Widget _metricValue(int value, Color color) {
    return Expanded(
      flex: 2,
      child: Center(
        child: Text(
          _fmt(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: value > 0 ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  // ── Sort dropdown ──────────────────────────────────────────────────────────

  Widget _buildSortDropdown() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          isDense: true,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          icon: Icon(Icons.keyboard_arrow_down,
              size: 16, color: Colors.grey.shade500),
          items: const [
            DropdownMenuItem(value: 'views', child: Text('By Views')),
            DropdownMenuItem(value: 'likes', child: Text('By Likes')),
            DropdownMenuItem(value: 'shares', child: Text('By Shares')),
            DropdownMenuItem(value: 'saves', child: Text('By Saves')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _sortBy = v);
          },
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Product Breakdown Bottom Sheet
// ═════════════════════════════════════════════════════════════════════════════

class _ProductBreakdownSheet extends StatefulWidget {
  const _ProductBreakdownSheet({
    required this.metric,
    required this.byProduct,
    required this.itemTables,
    required this.primaryColor,
    required this.accentColor,
  });

  final String metric;
  final Map<String, Map<String, int>> byProduct;
  final Map<String, String> itemTables;
  final Color primaryColor;
  final Color accentColor;

  @override
  State<_ProductBreakdownSheet> createState() => _ProductBreakdownSheetState();
}

class _ProductBreakdownSheetState extends State<_ProductBreakdownSheet> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  // item_id -> {title, image, table}
  Map<String, Map<String, String>> _details = {};

  static const _tableLabels = {
    'products': 'Main',
    'designerproducts': 'Designer',
    'manufacturerproducts': 'Manufacturer',
  };

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
  }

  Future<void> _fetchProductDetails() async {
    try {
      // Sort by metric descending and take top 50
      final sorted = widget.byProduct.entries.toList()
        ..sort((a, b) =>
            (b.value[widget.metric] ?? 0).compareTo(a.value[widget.metric] ?? 0));
      final top = sorted.take(50).map((e) => e.key).toList();

      // Group by table
      final Map<String, List<String>> byTable = {};
      for (final id in top) {
        final table = widget.itemTables[id] ?? 'products';
        byTable.putIfAbsent(table, () => []).add(id);
      }

      final Map<String, Map<String, String>> details = {};
      final Set<String> missingIds = top.toSet();

      for (final entry in byTable.entries) {
        try {
          final rows = await _supabase
              .from(entry.key)
              .select('id, "Product Title", "Image"')
              .inFilter('id', entry.value);
          for (final row in (rows as List)) {
            final id = row['id'].toString();
            missingIds.remove(id);
            String imgUrl = '';
            final img = row['Image'];
            if (img is List && img.isNotEmpty) {
              imgUrl = img[0].toString();
            } else if (img is String) {
              imgUrl = img;
            }
            details[id] = {
              'title': (row['Product Title'] as String?) ?? 'Untitled Product',
              'image': imgUrl,
              'table': entry.key,
            };
          }
        } catch (_) {}
      }

      // Fallback for any IDs that weren't found (e.g. incorrect table hint)
      if (missingIds.isNotEmpty) {
        for (final table in const ['products', 'designerproducts', 'manufacturerproducts']) {
          if (missingIds.isEmpty) break;
          try {
            final rows = await _supabase
                .from(table)
                .select('id, "Product Title", "Image"')
                .inFilter('id', missingIds.toList());
            for (final row in (rows as List)) {
              final id = row['id'].toString();
              missingIds.remove(id);
              String imgUrl = '';
              final img = row['Image'];
              if (img is List && img.isNotEmpty) {
                imgUrl = img[0].toString();
              } else if (img is String) {
                imgUrl = img;
              }
              details[id] = {
                'title': (row['Product Title'] as String?) ?? 'Untitled Product',
                'image': imgUrl,
                'table': table,
              };
            }
          } catch (_) {}
        }
      }

      if (mounted) setState(() { _details = details; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _metricLabel() {
    switch (widget.metric) {
      case 'likes': return 'Likes';
      case 'shares': return 'Shares';
      case 'saves': return 'Saves';
      default: return 'Views';
    }
  }

  IconData _metricIcon() {
    switch (widget.metric) {
      case 'likes': return Icons.favorite;
      case 'shares': return Icons.share;
      case 'saves': return Icons.bookmark;
      default: return Icons.visibility;
    }
  }

  Color _metricColor() {
    switch (widget.metric) {
      case 'likes': return const Color(0xFFE84393);
      case 'shares': return widget.accentColor;
      case 'saves': return const Color(0xFFF39C12);
      default: return widget.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = widget.byProduct.entries.toList()
      ..sort((a, b) =>
          (b.value[widget.metric] ?? 0).compareTo(a.value[widget.metric] ?? 0));
    final top = sorted.take(50).toList();
    final color = _metricColor();
    final fmt = NumberFormat('#,##0');

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_metricIcon(), color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Products by ${_metricLabel()}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Top ${top.length} products ranked by ${_metricLabel().toLowerCase()}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // Table header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Product',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade400,
                            letterSpacing: 0.8)),
                  ),
                  Text(_metricLabel().toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade400,
                          letterSpacing: 0.8)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // List
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: widget.primaryColor, strokeWidth: 2))
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                      itemCount: top.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (_, i) {
                        final id = top[i].key;
                        final count = top[i].value[widget.metric] ?? 0;
                        final info = _details[id];
                        final title = info?['title'] ?? id;
                        final imgUrl = info?['image'] ?? '';
                        final tableKey = info?['table'] ?? widget.itemTables[id] ?? 'products';
                        final tableLabel = _tableLabels[tableKey] ?? tableKey;
                        final isDesigner = tableKey == 'designerproducts';
                        final isManufacturer = tableKey == 'manufacturerproducts';

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final uri = Uri(
                                path: '/product/$id',
                                queryParameters: {
                                  if (isDesigner) 'isDesigner': 'true',
                                  if (isManufacturer) 'isManufacturer': 'true',
                                },
                              );
                              GoRouter.of(context).push(uri.toString());
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                              child: Row(
                                children: [
                                  // Rank
                                  SizedBox(
                                    width: 24,
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: i < 3
                                            ? color
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: imgUrl.isNotEmpty
                                        ? Image.network(
                                            imgUrl,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _placeholder(),
                                          )
                                        : _placeholder(),
                                  ),
                                  const SizedBox(width: 12),
                                  // Title + badge
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            tableLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Count
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        fmt.format(count),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                        ),
                                      ),
                                      Icon(_metricIcon(), size: 12, color: color.withValues(alpha: 0.5)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 44,
        height: 44,
        color: Colors.grey.shade100,
        child: Icon(Icons.image_outlined, size: 20, color: Colors.grey.shade300),
      );
}
