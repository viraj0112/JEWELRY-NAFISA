import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/geo_analytics_service.dart';
import '../../widgets/geo_analytics_widget.dart';

/// Catalog composition analytics: Product Type distribution, category totals,
/// and Plain vs Studded splits — per catalog table, with multi-select
/// category filtering.
///
/// Data comes from the RPCs `catalog_hierarchy_counts` (one row per
/// table × product type × category × subcategory, with the Category array
/// unnested), `product_type_counts` (exact per-type totals — each product
/// counted once even when it sits in several categories) and
/// `plain_studded_counts_by_category`.
class CatalogAnalyticsDashboard extends StatefulWidget {
  const CatalogAnalyticsDashboard({super.key});

  @override
  State<CatalogAnalyticsDashboard> createState() =>
      _CatalogAnalyticsDashboardState();
}

class _HierarchyCount {
  _HierarchyCount(this.sourceTable, this.productType, this.category,
      this.subCategory, this.count);

  final String sourceTable;
  final String productType;
  final String category;
  final String subCategory;
  final int count;
}

class _PlainStudded {
  _PlainStudded(this.category, this.plain, this.studded, this.total);
  final String category;
  final int plain;
  final int studded;
  final int total;
}

final _numberFormat = NumberFormat.decimalPattern('en_IN');
String _fmt(int n) => _numberFormat.format(n);

class _CatalogAnalyticsDashboardState extends State<CatalogAnalyticsDashboard> {
  // Marks use a validated 2-hue pair (lightness + CVD separation checked):
  // green = Plain, gold = Studded; green doubles as the single magnitude hue.
  static const _barGreen = Color(0xFF1B7A59);
  static const _barGold = Color(0xFFA8842B);
  static const _accent = Color(0xFF0A4F3F);
  static const _ink = Color(0xFF0A2F22);
  static const _mutedInk = Color(0xFF61726C);
  static const _surface = Colors.white;
  static const _panel = Color(0xFFF6F9F7);
  static const _track = Color(0xFFEDF2EF);
  static const _border = Color(0xFFE3E9E6);

  static const _barAnimation = Duration(milliseconds: 650);

  final _supabase = Supabase.instance.client;

  String _tableFilter = 'all';
  // Middle tier of the filter hierarchy: Table → Product Type → Categories.
  // 'all' means no product-type narrowing.
  String _productTypeFilter = 'all';
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedSubCategories = {};
  int _hierarchyPage = 0;
  static const int _hierarchyPageSize = 10;
  bool _loading = true;
  String? _error;
  List<_PlainStudded> _psRows = [];
  List<_HierarchyCount> _hierarchyRows = [];

  // Exact product counts per type for the current table + category scope.
  // Null when the `product_type_counts` RPC isn't deployed yet; the card then
  // falls back to summing hierarchy rows (which over-counts multi-category
  // products) and says so.
  Map<String, int>? _typeCounts;
  bool _typeCountsLoading = false;
  int _typeCountsRequest = 0;

  bool _showAllTypes = false;
  bool _showAllPlainStudded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _supabase.rpc('plain_studded_counts_by_category',
            params: {'p_table_filter': _tableFilter}),
        _supabase.rpc('catalog_hierarchy_counts',
            params: {'p_table_filter': _tableFilter}),
      ]);
      final psRows = (results[0] as List)
          .map((r) => _PlainStudded(
                (r['category'] ?? 'Unknown').toString(),
                (r['plain_count'] as num?)?.toInt() ?? 0,
                (r['studded_count'] as num?)?.toInt() ?? 0,
                (r['total_count'] as num?)?.toInt() ?? 0,
              ))
          .toList();
      final hierarchyRows = (results[1] as List)
          .map((r) => _HierarchyCount(
                (r['source_table'] ?? '').toString(),
                (r['product_type'] ?? '(unspecified)').toString(),
                (r['category'] ?? 'Uncategorized').toString(),
                (r['sub_category'] ?? 'Uncategorized').toString(),
                (r['item_count'] as num?)?.toInt() ?? 0,
              ))
          .toList();
      if (!mounted) return;
      setState(() {
        _psRows = psRows;
        _hierarchyRows = hierarchyRows;
        // Drop a product-type selection that no longer exists in the new scope.
        if (_productTypeFilter != 'all' &&
            !hierarchyRows.any((r) => r.productType == _productTypeFilter)) {
          _productTypeFilter = 'all';
        }
        // Drop category selections that no longer exist under the new scope.
        _selectedCategories
            .removeWhere((c) => !_categoriesInScope().contains(c));
        _selectedSubCategories
            .removeWhere((c) => !_subCategoriesInScope().contains(c));
        _hierarchyPage = 0;
        _loading = false;
      });
      _loadTypeCounts();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  // Re-fetched whenever the table scope or the category selection changes.
  Future<void> _loadTypeCounts() async {
    final request = ++_typeCountsRequest;
    setState(() => _typeCountsLoading = true);
    try {
      final rows = await _supabase.rpc('product_type_counts', params: {
        'p_table_filter': _tableFilter,
        'p_categories':
            _selectedCategories.isEmpty ? null : _selectedCategories.toList(),
      });
      if (!mounted || request != _typeCountsRequest) return;
      final counts = <String, int>{
        for (final r in rows as List)
          (r['product_type'] ?? '(unspecified)').toString():
              (r['item_count'] as num?)?.toInt() ?? 0,
      };
      setState(() {
        _typeCounts = counts;
        _typeCountsLoading = false;
      });
    } catch (e) {
      debugPrint('product_type_counts unavailable, falling back: $e');
      if (!mounted || request != _typeCountsRequest) return;
      setState(() {
        _typeCounts = null;
        _typeCountsLoading = false;
      });
    }
  }

  void _onCategoriesChanged() {
    _selectedSubCategories
        .removeWhere((s) => !_subCategoriesInScope().contains(s));
    _hierarchyPage = 0;
    _loadTypeCounts();
  }

  // Product type → product count under the current scope. Exact when the RPC
  // is available; otherwise summed hierarchy rows (over-counts products that
  // sit in more than one category).
  Map<String, int> _productTypeTotals() {
    final exact = _typeCounts;
    if (exact != null) return exact;
    final totals = <String, int>{};
    for (final r in _hierarchyRows) {
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(r.category)) {
        continue;
      }
      totals[r.productType] = (totals[r.productType] ?? 0) + r.count;
    }
    return totals;
  }

  // Product types available under the current table scope, ranked by volume.
  List<String> _productTypesInScope() {
    final totals = _productTypeTotals();
    final types = totals.keys.toList()
      ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
    // Keep a selected type visible even if the category picks exclude it.
    if (_productTypeFilter != 'all' && !types.contains(_productTypeFilter)) {
      types.add(_productTypeFilter);
    }
    return types;
  }

  // Categories visible under the current Table → Product Type scope. When a
  // product type is selected, only categories that co-occur with it remain.
  Set<String> _categoriesInScope() {
    return _hierarchyRows
        .where((r) => _productTypeInScope(r.productType))
        .map((r) => r.category)
        .toSet();
  }

  Set<String> _subCategoriesInScope() {
    final rows = _hierarchyRows.where((r) =>
        _productTypeInScope(r.productType) && _categorySelected(r.category));
    return rows.map((r) => r.subCategory).toSet();
  }

  bool _subCategorySelected(String subCategory) {
    if (!_subCategoriesInScope().contains(subCategory)) return false;
    return _selectedSubCategories.isEmpty ||
        _selectedSubCategories.contains(subCategory);
  }

  // A category counts as selected only if it's in the current product-type
  // scope AND either no explicit chips are picked or it's among the picked ones.
  bool _categorySelected(String category) {
    if (!_categoriesInScope().contains(category)) return false;
    return _selectedCategories.isEmpty ||
        _selectedCategories.contains(category);
  }

  // Whether a data row's product type passes the middle-tier filter.
  bool _productTypeInScope(String productType) =>
      _productTypeFilter == 'all' || _productTypeFilter == productType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _loading
                ? const Padding(
                    key: ValueKey('loading'),
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _accent)),
                  )
                : _error != null
                    ? _buildError()
                    : KeyedSubtree(
                        key: const ValueKey('content'),
                        child: _buildContent(),
                      ),
          ),
          const SizedBox(height: 20),
          const TopProductsByRegionCard(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryStrip(),
        const SizedBox(height: 18),
        _buildFilterPanel(),
        const SizedBox(height: 20),
        _buildHierarchyTable(),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;
          final typeCard = _buildProductTypeCard();
          final psCard = _buildPlainStuddedCard();
          if (narrow) {
            return Column(children: [
              typeCard,
              const SizedBox(height: 16),
              psCard,
            ]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: typeCard),
              const SizedBox(width: 16),
              Expanded(child: psCard),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      key: const ValueKey('error'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF3F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1D3CF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB3261E), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Could not load catalog analytics: $_error',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF7A1F19))),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F2ED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.insights_outlined, color: _accent, size: 22),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Catalog Composition',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
              SizedBox(height: 3),
              Text(
                'Product types, categories and plain vs studded splits across the catalog.',
                style: TextStyle(fontSize: 12.5, color: _mutedInk),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildTableScopeToggle(),
        const SizedBox(width: 4),
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded, size: 20, color: _mutedInk),
          tooltip: 'Reload',
        ),
      ],
    );
  }

  // ── Headline numbers for the current scope ──
  Widget _buildSummaryStrip() {
    final typeTotals = _productTypeTotals();
    final scopedTypeTotal = _productTypeFilter == 'all'
        ? typeTotals.values.fold<int>(0, (s, v) => s + v)
        : (typeTotals[_productTypeFilter] ?? 0);
    final categories = _categoriesInScope()
        .where((c) => _categorySelected(c))
        .length;
    final ps = _psRows.where((r) => _categorySelected(r.category));
    final plain = ps.fold<int>(0, (s, r) => s + r.plain);
    final studded = ps.fold<int>(0, (s, r) => s + r.studded);
    final studdedShare =
        plain + studded == 0 ? 0 : (studded * 100 / (plain + studded)).round();

    final tiles = [
      _StatTile(
        label: 'Products',
        value: _fmt(scopedTypeTotal),
        hint: _typeCounts == null ? 'approximate' : 'unique items',
        icon: Icons.diamond_outlined,
        loading: _typeCountsLoading,
      ),
      _StatTile(
        label: 'Product types',
        value: _fmt(_productTypeFilter == 'all' ? typeTotals.length : 1),
        hint: _productTypeFilter == 'all' ? 'in scope' : _productTypeFilter,
        icon: Icons.category_outlined,
      ),
      _StatTile(
        label: 'Categories',
        value: _fmt(categories),
        hint: _selectedCategories.isEmpty ? 'all included' : 'selected',
        icon: Icons.account_tree_outlined,
      ),
      _StatTile(
        label: 'Studded share',
        value: '$studdedShare%',
        hint: 'of category listings',
        icon: Icons.auto_awesome_outlined,
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth < 560
          ? 2
          : constraints.maxWidth < 900
              ? 2
              : 4;
      const gap = 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final t in tiles) SizedBox(width: width, child: t)],
      );
    });
  }

  // Top filter tier as a segmented control in the header.
  Widget _buildTableScopeToggle() {
    const scopes = [
      ('all', 'All'),
      ('products', 'Products'),
      ('designerproducts', 'Designer'),
      ('manufacturerproducts', 'Manufacturer'),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: scopes.map((s) {
          final active = _tableFilter == s.$1;
          return _HoverTap(
            onTap: () {
              if (_tableFilter == s.$1) return;
              setState(() => _tableFilter = s.$1);
              _load();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: active ? _accent : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : _mutedInk,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Product type → categories → subcategories, grouped in one soft panel.
  Widget _buildFilterPanel() {
    final hasSelection = _productTypeFilter != 'all' ||
        _selectedCategories.isNotEmpty ||
        _selectedSubCategories.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 16, color: _accent),
              const SizedBox(width: 8),
              const Text('Refine',
                  style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: _accent)),
              const Spacer(),
              AnimatedOpacity(
                opacity: hasSelection ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: TextButton.icon(
                  onPressed: hasSelection
                      ? () => setState(() {
                            _productTypeFilter = 'all';
                            _selectedCategories.clear();
                            _onCategoriesChanged();
                          })
                      : null,
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Clear all', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: _mutedInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildProductTypePills(),
          _buildCategoryChips(),
          _buildSubCategoryChips(),
        ],
      ),
    );
  }

  Widget _filterSection({
    required String title,
    required Widget child,
    String? status,
    VoidCallback? onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink)),
              if (status != null) ...[
                const SizedBox(width: 8),
                Text(status,
                    style: const TextStyle(fontSize: 11.5, color: _mutedInk)),
              ],
              if (onClear != null) ...[
                const SizedBox(width: 4),
                _HoverTap(
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text('Clear',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _accent)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool solid = false,
    int? count,
  }) {
    final bg = selected
        ? (solid ? _accent : const Color(0xFFE7F2ED))
        : _surface;
    final fg = selected ? (solid ? Colors.white : _accent) : _mutedInk;
    return _HoverTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _accent : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected && !solid) ...[
              const Icon(Icons.check_rounded, size: 14, color: _accent),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(_fmt(count),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: fg.withValues(alpha: 0.75))),
            ],
          ],
        ),
      ),
    );
  }

  // Middle filter tier: Product Type. Narrows both the category list and the
  // charts below.
  Widget _buildProductTypePills() {
    final types = _productTypesInScope();
    if (types.isEmpty) return const SizedBox.shrink();
    final totals = _productTypeTotals();

    void select(String t) {
      if (_productTypeFilter == t) return;
      setState(() {
        _productTypeFilter = t;
        // Selecting a type can invalidate category picks that don't belong to
        // it — drop the ones now out of scope.
        final before = _selectedCategories.length;
        _selectedCategories
            .removeWhere((c) => !_categoriesInScope().contains(c));
        _selectedSubCategories
            .removeWhere((c) => !_subCategoriesInScope().contains(c));
        _hierarchyPage = 0;
        if (before != _selectedCategories.length) _loadTypeCounts();
      });
    }

    return _filterSection(
      title: 'Product Type',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _pill(
            label: 'All types',
            selected: _productTypeFilter == 'all',
            solid: true,
            onTap: () => select('all'),
          ),
          for (final t in types)
            _pill(
              label: t,
              selected: _productTypeFilter == t,
              solid: true,
              count: totals[t],
              onTap: () => select(t),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final totals = <String, int>{};
    for (final r in _hierarchyRows) {
      if (_productTypeInScope(r.productType)) {
        totals[r.category] = (totals[r.category] ?? 0) + r.count;
      }
    }
    final categories = totals.keys.toList()
      ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
    if (categories.isEmpty) return const SizedBox.shrink();

    return _filterSection(
      title: 'Categories',
      status: _selectedCategories.isEmpty
          ? 'all included'
          : '${_selectedCategories.length} selected',
      onClear: _selectedCategories.isEmpty
          ? null
          : () => setState(() {
                _selectedCategories.clear();
                _onCategoriesChanged();
              }),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((c) {
          final selected = _selectedCategories.contains(c);
          return _pill(
            label: c,
            selected: selected,
            onTap: () => setState(() {
              if (selected) {
                _selectedCategories.remove(c);
              } else {
                _selectedCategories.add(c);
              }
              _onCategoriesChanged();
            }),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubCategoryChips() {
    final subCategories = _subCategoriesInScope().toList()..sort();
    if (subCategories.isEmpty) return const SizedBox.shrink();

    return _filterSection(
      title: 'Sub Categories',
      status: _selectedSubCategories.isEmpty
          ? 'all included'
          : '${_selectedSubCategories.length} selected',
      onClear: _selectedSubCategories.isEmpty
          ? null
          : () => setState(() {
                _selectedSubCategories.clear();
                _hierarchyPage = 0;
              }),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: subCategories.map((subCategory) {
          final selected = _selectedSubCategories.contains(subCategory);
          return _pill(
            label: subCategory,
            selected: selected,
            onTap: () => setState(() {
              if (selected) {
                _selectedSubCategories.remove(subCategory);
              } else {
                _selectedSubCategories.add(subCategory);
              }
              _hierarchyPage = 0;
            }),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHierarchyTable() {
    final rows = _hierarchyRows
        .where((r) =>
            _productTypeInScope(r.productType) &&
            _categorySelected(r.category) &&
            _subCategorySelected(r.subCategory))
        .toList()
      ..sort((a, b) {
        final category = a.category.compareTo(b.category);
        if (category != 0) return category;
        final subCategory = a.subCategory.compareTo(b.subCategory);
        if (subCategory != 0) return subCategory;
        return a.productType.compareTo(b.productType);
      });
    if (rows.isEmpty) return const SizedBox.shrink();

    final pageCount = (rows.length / _hierarchyPageSize).ceil();
    final page = _hierarchyPage.clamp(0, pageCount - 1);
    final pageRows = rows
        .skip(page * _hierarchyPageSize)
        .take(_hierarchyPageSize)
        .toList();

    const catalogLabels = {
      'products': 'Products',
      'designerproducts': 'Designer',
      'manufacturerproducts': 'Manufacturer',
    };
    const headerStyle = TextStyle(
        fontSize: 11.5,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w700,
        color: _mutedInk);
    const cellStyle = TextStyle(fontSize: 12.5, color: _ink);

    final subCategories = _subCategoriesInScope().length;
    return _card(
      title: 'Products Breakdown',
      subtitle:
          'Product type → category → subcategory · ${rows.length} rows · $subCategories subcategories',
      child: Column(
        children: [
          LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 42,
                  dataRowMaxHeight: 46,
                  horizontalMargin: 12,
                  columnSpacing: 28,
                  dividerThickness: 0.6,
                  headingRowColor: const WidgetStatePropertyAll(_panel),
                  headingTextStyle: headerStyle,
                  dataTextStyle: cellStyle,
                  columns: const [
                    DataColumn(label: Text('CATALOG')),
                    DataColumn(label: Text('PRODUCT TYPE')),
                    DataColumn(label: Text('CATEGORY')),
                    DataColumn(label: Text('SUB CATEGORY')),
                    DataColumn(label: Text('PRODUCTS'), numeric: true),
                  ],
                  rows: pageRows
                      .map((r) => DataRow(
                            color: WidgetStateProperty.resolveWith((states) =>
                                states.contains(WidgetState.hovered)
                                    ? const Color(0xFFF1F6F3)
                                    : null),
                            cells: [
                              DataCell(_CatalogBadge(
                                  catalogLabels[r.sourceTable] ??
                                      r.sourceTable)),
                              DataCell(Text(r.productType)),
                              DataCell(Text(r.category)),
                              DataCell(Text(r.subCategory,
                                  style: const TextStyle(color: _mutedInk))),
                              DataCell(Text(_fmt(r.count),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))),
                            ],
                          ))
                      .toList(),
                ),
              ),
            );
          }),
          if (pageCount > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${page * _hierarchyPageSize + 1}–'
                  '${(page * _hierarchyPageSize + pageRows.length)} of ${rows.length}',
                  style: const TextStyle(fontSize: 12, color: _mutedInk),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous page',
                      visualDensity: VisualDensity.compact,
                      onPressed: page == 0
                          ? null
                          : () => setState(() => _hierarchyPage = page - 1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text('${page + 1} / $pageCount',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _ink)),
                    IconButton(
                      tooltip: 'Next page',
                      visualDensity: VisualDensity.compact,
                      onPressed: page >= pageCount - 1
                          ? null
                          : () => setState(() => _hierarchyPage = page + 1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Product Type distribution (single magnitude hue, direct count labels) ──
  Widget _buildProductTypeCard() {
    final totals = _productTypeTotals();
    final entries = totals.entries
        .where((e) => _productTypeInScope(e.key) && e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final grandTotal = entries.fold<int>(0, (s, e) => s + e.value);
    final maxCount = entries.isEmpty ? 1 : entries.first.value;
    const collapsedCount = 10;
    final visible =
        _showAllTypes ? entries : entries.take(collapsedCount).toList();

    return _card(
      title: 'By Product Type',
      subtitle: _typeCounts == null
          ? '${_scopeSubtitle()} · approximate (apply the product_type_counts migration)'
          : '${_scopeSubtitle()} · each product counted once',
      trailing: _typeCountsLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.6, color: _accent))
          : null,
      child: entries.isEmpty
          ? const _EmptyNote()
          : Column(
              children: [
                for (final e in visible)
                  _barRow(
                    label: e.key,
                    value: e.value,
                    share: grandTotal == 0 ? 0 : e.value / grandTotal,
                    fraction: e.value / maxCount,
                    color: _barGreen,
                  ),
                if (entries.length > collapsedCount)
                  _showMoreToggle(
                    expanded: _showAllTypes,
                    hidden: entries.length - collapsedCount,
                    onTap: () =>
                        setState(() => _showAllTypes = !_showAllTypes),
                  ),
              ],
            ),
    );
  }

  // ── Plain vs Studded per category: one stacked bar each, length = total ──
  Widget _buildPlainStuddedCard() {
    final rows = _psRows.where((r) => _categorySelected(r.category)).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    const collapsedCount = 10;
    final visible =
        _showAllPlainStudded ? rows : rows.take(collapsedCount).toList();
    final maxTotal = rows.isEmpty
        ? 1
        : rows
            .map((r) => r.plain + r.studded)
            .reduce((a, b) => a > b ? a : b);

    return _card(
      title: 'Plain vs Studded',
      subtitle: _scopeSubtitle(),
      trailing: const _Legend(),
      child: rows.isEmpty
          ? const _EmptyNote()
          : Column(
              children: [
                for (final r in visible) _stackedRow(r, maxTotal),
                if (rows.length > collapsedCount)
                  _showMoreToggle(
                    expanded: _showAllPlainStudded,
                    hidden: rows.length - collapsedCount,
                    onTap: () => setState(
                        () => _showAllPlainStudded = !_showAllPlainStudded),
                  ),
              ],
            ),
    );
  }

  Widget _stackedRow(_PlainStudded r, int maxTotal) {
    final sum = r.plain + r.studded;
    final plainPct = sum == 0 ? 0 : (r.plain * 100 / sum).round();
    return _HoverHighlight(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.category,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _ink)),
                ),
                Text(_fmt(sum),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
              ],
            ),
            const SizedBox(height: 6),
            Tooltip(
              message: '${r.category}\n'
                  'Plain: ${_fmt(r.plain)} ($plainPct%)\n'
                  'Studded: ${_fmt(r.studded)} (${sum == 0 ? 0 : 100 - plainPct}%)',
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: sum / maxTotal),
                duration: _barAnimation,
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    final full = constraints.maxWidth * t.clamp(0.0, 1.0);
                    final plainW = sum == 0 ? 0.0 : full * r.plain / sum;
                    final studdedW = sum == 0 ? 0.0 : full * r.studded / sum;
                    // 2px surface gap between the two segments.
                    final gap = plainW > 0 && studdedW > 0 ? 2.0 : 0.0;
                    return Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: _track,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          _segment(plainW - gap / 2, _barGreen,
                              left: true, right: studdedW == 0),
                          SizedBox(width: gap),
                          _segment(studdedW - gap / 2, _barGold,
                              left: plainW == 0, right: true),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text('${_fmt(r.plain)} plain',
                    style: const TextStyle(fontSize: 11, color: _mutedInk)),
                const Text('  ·  ',
                    style: TextStyle(fontSize: 11, color: _mutedInk)),
                Text('${_fmt(r.studded)} studded',
                    style: const TextStyle(fontSize: 11, color: _mutedInk)),
                const Spacer(),
                Text('$plainPct% plain',
                    style: const TextStyle(fontSize: 11, color: _mutedInk)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(double width, Color color,
      {required bool left, required bool right}) {
    if (width <= 0) return const SizedBox.shrink();
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(left ? 4 : 0),
          right: Radius.circular(right ? 4 : 0),
        ),
      ),
    );
  }

  Widget _showMoreToggle({
    required bool expanded,
    required int hidden,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(
            expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 18),
        label: Text(expanded ? 'Show less' : 'Show $hidden more',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(foregroundColor: _accent),
      ),
    );
  }

  String _scopeSubtitle() {
    final scope = switch (_tableFilter) {
      'products' => 'Products',
      'designerproducts' => 'Designer products',
      'manufacturerproducts' => 'Manufacturer products',
      _ => 'All catalog tables',
    };
    final withType =
        _productTypeFilter == 'all' ? scope : '$scope · $_productTypeFilter';
    return _selectedCategories.isEmpty
        ? withType
        : '$withType · ${_selectedCategories.length} categories';
  }

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 11.5, color: _mutedInk)),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _barRow({
    required String label,
    required int value,
    required double share,
    required double fraction,
    required Color color,
  }) {
    final pct = share * 100;
    final pctLabel = pct >= 10 || pct == 0
        ? '${pct.round()}%'
        : '${pct.toStringAsFixed(1)}%';
    return _HoverHighlight(
      child: Tooltip(
        message: '$label — ${_fmt(value)} product(s), $pctLabel of total',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          child: Row(
            children: [
              SizedBox(
                width: 130,
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _ink)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 10,
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: _track,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
                    duration: _barAnimation,
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => FractionallySizedBox(
                      widthFactor: t,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 52,
                child: Text(_fmt(value),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _ink)),
              ),
              SizedBox(
                width: 46,
                child: Text(pctLabel,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11, color: _mutedInk)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    this.loading = false,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E9E6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF61726C))),
                const SizedBox(height: 8),
                AnimatedOpacity(
                  opacity: loading ? 0.4 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A2F22))),
                ),
                const SizedBox(height: 4),
                Text(hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF61726C))),
              ],
            ),
          ),
          Icon(icon, size: 18, color: const Color(0xFF0A4F3F)),
        ],
      ),
    );
  }
}

class _CatalogBadge extends StatelessWidget {
  const _CatalogBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F2ED),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0A4F3F))),
    );
  }
}

/// Clickable wrapper with a pointer cursor and no ink splash.
class _HoverTap extends StatelessWidget {
  const _HoverTap({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

/// Soft row highlight on hover for chart rows.
class _HoverHighlight extends StatefulWidget {
  const _HoverHighlight({required this.child});
  final Widget child;

  @override
  State<_HoverHighlight> createState() => _HoverHighlightState();
}

class _HoverHighlightState extends State<_HoverHighlight> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFFF3F7F5) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: widget.child,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF61726C))),
          ],
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        item(const Color(0xFF1B7A59), 'Plain'),
        const SizedBox(width: 12),
        item(const Color(0xFFA8842B), 'Studded'),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text('No data for this scope.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF61726C))),
      ),
    );
  }
}

/// "Which product is winning where" — platform-wide views/likes/shares,
/// broken down per state, so an admin can pick a region and see its top
/// products (not just a global leaderboard, and not just region totals).
class TopProductsByRegionCard extends StatefulWidget {
  const TopProductsByRegionCard({super.key});

  @override
  State<TopProductsByRegionCard> createState() =>
      _TopProductsByRegionCardState();
}

class _TopProductsByRegionCardState extends State<TopProductsByRegionCard> {
  static const _ink = Color(0xFF0A2F22);
  static const _mutedInk = Color(0xFF61726C);
  static const _surface = Colors.white;
  static const _border = Color(0xFFE3E9E6);
  static const _accent = Color(0xFF0A4F3F);

  final _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  GeoAnalyticsData _data = GeoAnalyticsData.empty;
  String? _selectedState; // null = all regions (global ranking)
  String _metric = 'views'; // views | likes | shares

  // Resolved once per (state, metric) selection.
  Map<String, Map<String, String>> _productDetails = {};
  bool _loadingDetails = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await GeoAnalyticsService.fetchGeoData();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      _resolveDetails();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  List<MapEntry<String, Map<String, int>>> get _rankedProducts {
    final Map<String, Map<String, int>> source;
    if (_selectedState == null) {
      source = _data.byProduct;
    } else {
      source = _data.byStateProduct[_selectedState] ?? const {};
    }
    final entries = source.entries.toList()
      ..sort(
          (a, b) => (b.value[_metric] ?? 0).compareTo(a.value[_metric] ?? 0));
    return entries.where((e) => (e.value[_metric] ?? 0) > 0).take(10).toList();
  }

  Future<void> _resolveDetails() async {
    final top = _rankedProducts.map((e) => e.key).toList();
    if (top.isEmpty) {
      setState(() => _productDetails = {});
      return;
    }
    setState(() => _loadingDetails = true);

    final Map<String, List<String>> byTable = {};
    for (final id in top) {
      final table = _data.itemTables[id] ?? 'products';
      byTable.putIfAbsent(table, () => []).add(id);
    }

    final details = <String, Map<String, String>>{};
    for (final entry in byTable.entries) {
      try {
        final rows = await _supabase
            .from(entry.key)
            .select('id, "Product Title", "Images"')
            .inFilter('id', entry.value);
        for (final row in (rows as List)) {
          final id = row['id'].toString();
          String imgUrl = '';
          final img = row['Images'];
          if (img is List && img.isNotEmpty) imgUrl = img[0].toString();
          details[id] = {
            'title': (row['Product Title'] as String?) ?? 'Untitled Product',
            'image': imgUrl,
            'table': entry.key,
          };
        }
      } catch (_) {
        // Skip products that fail to resolve; the row still ranks, just
        // rendered with a fallback title below.
      }
    }
    if (!mounted) return;
    setState(() {
      _productDetails = details;
      _loadingDetails = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final states = _data.byStateProduct.keys.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Top Products by Region',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                    SizedBox(height: 4),
                    Text(
                      'Most viewed, liked or shared products — platform-wide or filtered to one state.',
                      style: TextStyle(fontSize: 12.5, color: _mutedInk),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 20, color: _mutedInk),
                tooltip: 'Reload',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _regionDropdown(states),
              _metricPills(),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Could not load region analytics: $_error',
                  style: const TextStyle(color: Colors.redAccent)),
            )
          else
            _buildRankedList(),
        ],
      ),
    );
  }

  Widget _regionDropdown(List<String> states) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String?>(
        initialValue: _selectedState,
        isDense: true,
        decoration: InputDecoration(
          isDense: true,
          labelText: 'Region',
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border)),
        ),
        items: [
          const DropdownMenuItem<String?>(
              value: null, child: Text('All regions')),
          ...states
              .map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
        ],
        onChanged: (v) {
          setState(() => _selectedState = v);
          _resolveDetails();
        },
      ),
    );
  }

  Widget _metricPills() {
    const options = [
      ('views', 'Most Viewed'),
      ('likes', 'Most Liked'),
      ('shares', 'Most Shared'),
    ];
    return Wrap(
      spacing: 8,
      children: options.map((o) {
        final active = _metric == o.$1;
        return ChoiceChip(
          label: Text(o.$2),
          selected: active,
          onSelected: (_) {
            if (_metric == o.$1) return;
            setState(() => _metric = o.$1);
            _resolveDetails();
          },
          selectedColor: _accent,
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : _mutedInk,
          ),
          showCheckmark: false,
          side: BorderSide(color: active ? _accent : _border),
          backgroundColor: Colors.white,
        );
      }).toList(),
    );
  }

  Widget _buildRankedList() {
    final ranked = _rankedProducts;
    if (ranked.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            _selectedState == null
                ? 'No engagement data yet.'
                : 'No engagement data yet for $_selectedState.',
            style: const TextStyle(fontSize: 12.5, color: _mutedInk),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < ranked.length; i++)
          _buildRankedRow(i + 1, ranked[i].key, ranked[i].value),
      ],
    );
  }

  Widget _buildRankedRow(int rank, String id, Map<String, int> metrics) {
    final details = _productDetails[id];
    final title = details?['title'] ?? (_loadingDetails ? 'Loading…' : id);
    final imgUrl = details?['image'] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('#$rank',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _mutedInk)),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: imgUrl.isNotEmpty
                ? Image.network(imgUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(width: 36, height: 36, color: _border))
                : Container(width: 36, height: 36, color: _border),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: _ink)),
          ),
          const SizedBox(width: 8),
          Text('${metrics[_metric] ?? 0}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _accent)),
        ],
      ),
    );
  }
}
