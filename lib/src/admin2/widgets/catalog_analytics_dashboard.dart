import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/geo_analytics_service.dart';
import '../../widgets/geo_analytics_widget.dart';

/// Catalog composition analytics: Product Type distribution, category totals,
/// and Plain vs Studded splits — per catalog table, with multi-select
/// category filtering.
///
/// Data comes from the Phase 2 RPCs `product_type_counts_by_category` and
/// `plain_studded_counts_by_category`, which unnest the unified category
/// array across all three product tables (products / designerproducts /
/// manufacturerproducts), so this dashboard keeps working unchanged through
/// the Phase 3 rename (the RPC bodies are rewritten in the same migration).
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

class _CatalogAnalyticsDashboardState extends State<CatalogAnalyticsDashboard> {
  // Marks use a validated 2-hue pair (lightness + CVD separation checked):
  // green = Plain, gold = Studded; green doubles as the single magnitude hue.
  static const _barGreen = Color(0xFF1B7A59);
  static const _barGold = Color(0xFFA8842B);
  static const _ink = Color(0xFF0A2F22);
  static const _mutedInk = Color(0xFF61726C);
  static const _surface = Colors.white;
  static const _border = Color(0xFFE3E9E6);

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  // Product types available under the current table scope, ranked by volume.
  List<String> _productTypesInScope() {
    final totals = <String, int>{};
    for (final r in _hierarchyRows) {
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(r.category)) {
        continue;
      }
      totals[r.productType] = (totals[r.productType] ?? 0) + r.count;
    }
    final types = totals.keys.toList()
      ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildTableScopePills(),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text('Could not load catalog analytics: $_error',
                  style: const TextStyle(color: Colors.redAccent)),
            )
          else ...[
            _buildProductTypePills(),
            const SizedBox(height: 12),
            _buildCategoryChips(),
            const SizedBox(height: 12),
            _buildSubCategoryChips(),
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
            const SizedBox(height: 16),
            const TopProductsByRegionCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Catalog Composition',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
              SizedBox(height: 4),
              Text(
                'Product types, categories and plain vs studded splits across the catalog.',
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
    );
  }

  Widget _buildTableScopePills() {
    const scopes = [
      ('all', 'All Tables'),
      ('products', 'Products'),
      ('designerproducts', 'Designer'),
      ('manufacturerproducts', 'Manufacturer'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: scopes.map((s) {
        final active = _tableFilter == s.$1;
        return ChoiceChip(
          label: Text(s.$2),
          selected: active,
          onSelected: (_) {
            if (_tableFilter == s.$1) return;
            setState(() => _tableFilter = s.$1);
            _load();
          },
          selectedColor: const Color(0xFF0A4F3F),
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : _mutedInk,
          ),
          showCheckmark: false,
          side: BorderSide(color: active ? const Color(0xFF0A4F3F) : _border),
          backgroundColor: _surface,
        );
      }).toList(),
    );
  }

  // Middle filter tier: Product Type. Sits between the table scope and the
  // category chips, and narrows both the category list and the charts below.
  Widget _buildProductTypePills() {
    final types = _productTypesInScope();
    if (types.isEmpty) return const SizedBox.shrink();

    // 'all' pill + one pill per product type, single-select.
    final options = ['all', ...types];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Product Type',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((t) {
            final active = _productTypeFilter == t;
            final label = t == 'all' ? 'All Types' : t;
            return ChoiceChip(
              label: Text(label),
              selected: active,
              onSelected: (_) {
                if (_productTypeFilter == t) return;
                setState(() {
                  _productTypeFilter = t;
                  // Selecting a type can invalidate category picks that don't
                  // belong to it — drop the ones now out of scope.
                  _selectedCategories
                      .removeWhere((c) => !_categoriesInScope().contains(c));
                  _selectedSubCategories
                      .removeWhere((c) => !_subCategoriesInScope().contains(c));
                  _hierarchyPage = 0;
                });
              },
              selectedColor: const Color(0xFF0A4F3F),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _mutedInk,
              ),
              showCheckmark: false,
              side:
                  BorderSide(color: active ? const Color(0xFF0A4F3F) : _border),
              backgroundColor: _surface,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final categories = _categoriesInScope().toList()
      ..sort((a, b) {
        int total(String c) => _hierarchyRows
            .where((r) => r.category == c)
            .fold(0, (s, r) => s + r.count);
        return total(b).compareTo(total(a));
      });
    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Categories',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(width: 8),
            Text(
              _selectedCategories.isEmpty
                  ? 'all included'
                  : '${_selectedCategories.length} selected',
              style: const TextStyle(fontSize: 12, color: _mutedInk),
            ),
            if (_selectedCategories.isNotEmpty)
              TextButton(
                onPressed: () => setState(() {
                  _selectedCategories.clear();
                  _selectedSubCategories.clear();
                  _hierarchyPage = 0;
                }),
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((c) {
            final selected = _selectedCategories.contains(c);
            return FilterChip(
              label: Text(c),
              selected: selected,
              onSelected: (v) => setState(() {
                if (v) {
                  _selectedCategories.add(c);
                } else {
                  _selectedCategories.remove(c);
                }
                _selectedSubCategories
                    .removeWhere((s) => !_subCategoriesInScope().contains(s));
                _hierarchyPage = 0;
              }),
              selectedColor: const Color(0xFFE7F2ED),
              checkmarkColor: const Color(0xFF0A4F3F),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFF0A4F3F) : _mutedInk,
              ),
              side: BorderSide(
                  color: selected ? const Color(0xFF0A4F3F) : _border),
              backgroundColor: _surface,
            );
          }).toList(),
        ),
      ],
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

    final subCategories = _subCategoriesInScope().toList()..sort();
    return _card(
      title: 'Products Breakdown',
      subtitle:
          'Product type → category → subcategory · ${subCategories.length} subcategories',
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  const WidgetStatePropertyAll(Color(0xFFF1F6F3)),
              columns: const [
                DataColumn(label: Text('Catalog')),
                DataColumn(label: Text('Product Type')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Sub Category')),
                DataColumn(label: Text('Products'), numeric: true),
              ],
              rows: pageRows
                  .map((r) => DataRow(cells: [
                        DataCell(Text(r.sourceTable)),
                        DataCell(Text(r.productType)),
                        DataCell(Text(r.category)),
                        DataCell(Text(r.subCategory)),
                        DataCell(Text(r.count.toString())),
                      ]))
                  .toList(),
            ),
          ),
          if (pageCount > 1) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: page == 0
                      ? null
                      : () => setState(() => _hierarchyPage = page - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${page + 1} of $pageCount',
                    style: const TextStyle(fontSize: 12, color: _mutedInk)),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: page >= pageCount - 1
                      ? null
                      : () => setState(() => _hierarchyPage = page + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubCategoryChips() {
    final subCategories = _subCategoriesInScope().toList()..sort();
    if (subCategories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Sub Categories',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(width: 8),
            Text(
              _selectedSubCategories.isEmpty
                  ? 'all included'
                  : '${_selectedSubCategories.length} selected',
              style: const TextStyle(fontSize: 12, color: _mutedInk),
            ),
            if (_selectedSubCategories.isNotEmpty)
              TextButton(
                onPressed: () => setState(() {
                  _selectedSubCategories.clear();
                  _hierarchyPage = 0;
                }),
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: subCategories.map((subCategory) {
            final selected = _selectedSubCategories.contains(subCategory);
            return FilterChip(
              label: Text(subCategory),
              selected: selected,
              onSelected: (value) => setState(() {
                if (value) {
                  _selectedSubCategories.add(subCategory);
                } else {
                  _selectedSubCategories.remove(subCategory);
                }
                _hierarchyPage = 0;
              }),
              selectedColor: const Color(0xFFE7F2ED),
              checkmarkColor: const Color(0xFF0A4F3F),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFF0A4F3F) : _mutedInk,
              ),
              side: BorderSide(
                  color: selected ? const Color(0xFF0A4F3F) : _border),
              backgroundColor: _surface,
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Product Type distribution (single magnitude hue, direct count labels) ──
  Widget _buildProductTypeCard() {
    // The fixed RPC returns one row per Product Type with category='All'
    // and the exact product count (each product counted once, not once per category).
    // We simply display those counts directly, sorted by volume.
    final deduped = <String, int>{};
    for (final row in _hierarchyRows) {
      if (_productTypeInScope(row.productType) &&
          _categorySelected(row.category)) {
        deduped[row.productType] = (deduped[row.productType] ?? 0) + row.count;
      }
    }
    final dedupedEntries = deduped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxCount = dedupedEntries.isEmpty
        ? 1
        : dedupedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return _card(
      title: 'By Product Type',
      subtitle: _scopeSubtitle(),
      child: dedupedEntries.isEmpty
          ? const _EmptyNote()
          : Column(
              children: dedupedEntries
                  .take(14)
                  .map((e) => _barRow(
                        label: e.key,
                        value: e.value,
                        fraction: e.value / maxCount,
                        color: _barGreen,
                      ))
                  .toList(),
            ),
    );
  }

  // ── Plain vs Studded per category (2 fixed hues + legend) ──
  Widget _buildPlainStuddedCard() {
    final rows = _psRows.where((r) => _categorySelected(r.category)).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final top = rows.take(10).toList();
    final maxVal = top.isEmpty
        ? 1
        : top
            .map((r) => r.plain > r.studded ? r.plain : r.studded)
            .reduce((a, b) => a > b ? a : b);

    return _card(
      title: 'Plain vs Studded',
      subtitle: _scopeSubtitle(),
      trailing: const _Legend(),
      child: top.isEmpty
          ? const _EmptyNote()
          : Column(
              children: top
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
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
                                Text('${r.total} total',
                                    style: const TextStyle(
                                        fontSize: 11, color: _mutedInk)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _pairedBar(r.plain, maxVal, _barGreen),
                            const SizedBox(height: 2),
                            _pairedBar(r.studded, maxVal, _barGold),
                          ],
                        ),
                      ))
                  .toList(),
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
        color: const Color(0xFFFBFCFB),
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
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 11.5, color: _mutedInk)),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _barRow({
    required String label,
    required int value,
    required double fraction,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: '$label — $value item(s)',
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF3F1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text('$value',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
          ),
        ],
      ),
    );
  }

  Widget _pairedBar(int value, int maxVal, Color color) {
    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3F1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: maxVal == 0 ? 0 : (value / maxVal).clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text('$value',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: _mutedInk)),
        ),
      ],
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
        value: _selectedState,
        isDense: true,
        decoration: InputDecoration(
          isDense: true,
          labelText: 'Region',
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _border)),
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
