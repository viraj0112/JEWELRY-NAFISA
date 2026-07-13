import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class _TypeCount {
  _TypeCount(this.category, this.productType, this.count);
  final String category;
  final String productType;
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
  final Set<String> _selectedCategories = {};
  bool _loading = true;
  String? _error;
  List<_TypeCount> _typeRows = [];
  List<_PlainStudded> _psRows = [];

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
        _supabase.rpc('product_type_counts_by_category',
            params: {'p_table_filter': _tableFilter}),
        _supabase.rpc('plain_studded_counts_by_category',
            params: {'p_table_filter': _tableFilter}),
      ]);
      final typeRows = (results[0] as List)
          .map((r) => _TypeCount(
                (r['category'] ?? 'Unknown').toString(),
                (r['product_type'] ?? '(unspecified)').toString(),
                (r['item_count'] as num?)?.toInt() ?? 0,
              ))
          .toList();
      final psRows = (results[1] as List)
          .map((r) => _PlainStudded(
                (r['category'] ?? 'Unknown').toString(),
                (r['plain_count'] as num?)?.toInt() ?? 0,
                (r['studded_count'] as num?)?.toInt() ?? 0,
                (r['total_count'] as num?)?.toInt() ?? 0,
              ))
          .toList();
      if (!mounted) return;
      setState(() {
        _typeRows = typeRows;
        _psRows = psRows;
        // Drop selections that no longer exist under the new table scope.
        _selectedCategories
            .removeWhere((c) => !psRows.any((r) => r.category == c));
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

  bool _categorySelected(String category) =>
      _selectedCategories.isEmpty || _selectedCategories.contains(category);

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
            _buildCategoryChips(),
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

  Widget _buildCategoryChips() {
    final categories = _psRows.map((r) => r.category).toSet().toList()
      ..sort((a, b) {
        int total(String c) =>
            _psRows.where((r) => r.category == c).fold(0, (s, r) => s + r.total);
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
                onPressed: () => setState(_selectedCategories.clear),
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
    final totals = <String, int>{};
    for (final row in _typeRows) {
      if (!_categorySelected(row.category)) continue;
      totals[row.productType] = (totals[row.productType] ?? 0) + row.count;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount =
        entries.isEmpty ? 1 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return _card(
      title: 'By Product Type',
      subtitle: _scopeSubtitle(),
      child: entries.isEmpty
          ? const _EmptyNote()
          : Column(
              children: entries
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
    return _selectedCategories.isEmpty
        ? scope
        : '$scope · ${_selectedCategories.length} categories';
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
                style:
                    const TextStyle(fontSize: 11, color: Color(0xFF61726C))),
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
