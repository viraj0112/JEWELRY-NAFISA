import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'page_template.dart';
import 'Uploads/editInSheets.dart';
import 'dart:ui';
import 'package:jewelry_nafisa/src/models/filter_criteria.dart';
import 'package:jewelry_nafisa/src/B2BScreens/b2b_theme.dart';
import 'package:jewelry_nafisa/src/B2BScreens/widgets/insight_widgets.dart';
import 'package:jewelry_nafisa/src/services/b2b_insights_service.dart';

class HomePage extends StatefulWidget {
  final FilterCriteria? filters;
  final Set<int> aiFilledIds;

  const HomePage({super.key, this.filters, this.aiFilledIds = const {}});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<JewelryItem>> _future;
  late JewelryService _jewelryService;
  final List<Map<String, dynamic>> _geoAnalytics = [];

  // User type detection
  bool _isManufacturer = false;
  bool _isPremium = false;

  // View + bulk-selection state
  bool _isGridView = true;
  final Set<String> _selectedIds = {};

  String get _tableName =>
      _isManufacturer ? 'manufacturerproducts' : 'designerproducts';

  void _reload() {
    setState(() {
      _selectedIds.clear();
      _future = _isManufacturer
          ? _jewelryService.getMyManufacturerProducts()
          : _jewelryService.getMyDesignerProducts();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count product(s)?'),
        content: const Text(
            'This permanently removes the selected products from your catalog. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final ids = _selectedIds.map((e) => int.tryParse(e) ?? e).toList();
      await Supabase.instance.client
          .from(_tableName)
          .delete()
          .inFilter('id', ids)
          .eq('user_id', user.id); // never delete rows the user doesn't own
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$count product(s) deleted'),
            backgroundColor: Colors.green),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openEditInSheets(List<JewelryItem> products) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => EditInSheetsDialog(
        tableName: _tableName,
        selectedIds: _selectedIds.toList(),
      ),
    );
    if (changed == true) _reload();
  }

  @override
  void initState() {
    super.initState();

    _jewelryService = JewelryService(Supabase.instance.client);

    // Get user profile to determine if manufacturer or designer
    final userProfile =
        Provider.of<UserProfileProvider>(context, listen: false).userProfile;

    // Detect manufacturer
    _isManufacturer = userProfile?.manufacturerProfile != null;

    // For designers: fetch premium status (for now, assuming false - fetch from DB if needed)
    _isPremium = false; // TODO: Fetch from users table if user is designer

    // If user has manufacturerProfile, load manufacturer products; otherwise load designer products
    if (_isManufacturer) {
      _future = _jewelryService.getMyManufacturerProducts();
    } else {
      _future = _jewelryService.getMyDesignerProducts();
    }
  }

  /// Unlock logic: Manufacturers always see geoAnalytics, Designers only if premium
  bool get _isUnlocked => _isManufacturer || _isPremium;

  // Helper method to check if a product matches the filters
  bool _matchesFilter(JewelryItem item) {
    if (widget.filters == null || widget.filters!.isEmpty) return true;
    final f = widget.filters!;

    // 0. Free-text search across SKU, title, product type and category.
    final search = f.searchText?.trim().toLowerCase();
    if (search != null && search.isNotEmpty) {
      final haystack = [
        item.sku ?? '',
        item.productTitle,
        item.productType ?? '',
        item.category ?? '',
        item.subCategory ?? '',
      ].join(' ').toLowerCase();
      if (!haystack.contains(search)) return false;
    }

    // 0a. Date range: products uploaded within it (whole end day included).
    if (!f.includesDate(item.createdAt)) return false;

    // 1. Location (Mock: assumes item.users['address'] contains specific location string)
    if (f.location != null && f.location != 'India') {
      // Just an example check
      // if (item.users?['address'] != f.location) return false;
    }

    // 2. Product Type
    if (f.productType != null) {
      if (item.productType != f.productType && item.category != f.productType) {
        return false;
      }
    }

    // 3. Category
    if (f.category != null) {
      if (item.category != f.category && item.subCategory != f.category) {
        return false;
      }
    }

    // 3a. Category1
    if (f.category1 != null) {
      if (item.category1 != f.category1) return false;
    }

    // 3b. Category2
    if (f.category2 != null) {
      if (item.category2 != f.category2) return false;
    }

    // 3c. Category3
    if (f.category3 != null) {
      if (item.category3 != f.category3) return false;
    }

    // 4. Metal Type
    if (f.metalType != null) {
      if (item.metalType != f.metalType && item.metalPurity != f.metalType) {
        return false;
      }
    }

    // 5. Demand Level (Approximation)
    if (f.demandLevel != null) {
      if (f.demandLevel == 'Rising' && (item.isTrending != true)) return false;
      if (f.demandLevel == 'High' && ((item.likes ?? 0) < 20)) return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PageTemplate(
      eyebrow: 'Your catalogue',
      title: "Home",
      subtitle: 'Manage, refine and track every design in your collection.',
      child: FutureBuilder<List<JewelryItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load your catalogue',
              message: '${snapshot.error}',
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const _EmptyState(
              icon: Icons.diamond_outlined,
              title: 'No products yet',
              message: 'Upload your first design to start building your catalogue.',
            );
          }

          // Apply filters
          final allProducts = snapshot.data!;
          final products = allProducts.where(_matchesFilter).toList();

          if (products.isEmpty) {
            return const _EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No products match your filters',
              message: 'Try clearing a filter or widening the date range.',
            );
          }

          return Column(
            children: [
              _buildToolbar(products),
              Expanded(
                child: _isGridView
                    ? _buildGrid(products)
                    : _buildList(products),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToolbar(List<JewelryItem> products) {
    final allSelected = products.isNotEmpty &&
        products.every((p) => _selectedIds.contains(p.id));
    final anySelected = _selectedIds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Select all / none
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: allSelected
                    ? true
                    : (anySelected ? null : false),
                tristate: true,
                activeColor: B2BColors.primary,
                onChanged: (_) => setState(() {
                  if (allSelected) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(products.map((p) => p.id));
                  }
                }),
              ),
              Text(
                anySelected
                    ? '${_selectedIds.length} selected'
                    : 'Select all',
                style: B2BText.sans(
                    size: 13, weight: FontWeight.w600, color: B2BColors.inkSoft),
              ),
            ],
          ),
          if (anySelected) ...[
            OutlinedButton.icon(
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: B2BColors.danger,
                side: const BorderSide(color: Color(0xFFEBC4C1)),
              ),
            ),
          ],
          OutlinedButton.icon(
            onPressed: () => _openEditInSheets(products),
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: Text(anySelected
                ? 'Edit in Sheets (${_selectedIds.length})'
                : 'Edit in Sheets'),
          ),
          // View toggle
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: B2BColors.surface,
              border: Border.all(color: B2BColors.border),
              borderRadius: BorderRadius.circular(B2BRadius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ViewToggleButton(
                  icon: Icons.grid_view_rounded,
                  tooltip: 'Grid view',
                  selected: _isGridView,
                  onTap: () => setState(() => _isGridView = true),
                ),
                _ViewToggleButton(
                  icon: Icons.view_list_rounded,
                  tooltip: 'List view',
                  selected: !_isGridView,
                  onTap: () => setState(() => _isGridView = false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<JewelryItem> products) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive Grid Logic
        int crossAxisCount = 2; // Mobile default
        if (constraints.maxWidth > 600) crossAxisCount = 3; // Tablet
        if (constraints.maxWidth > 900) crossAxisCount = 4; // Desktop

        return Center(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(2, 16, 2, 80),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.70, // Slightly taller cards
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final item = products[index];
              final itemId = int.tryParse(item.id) ?? -1;
              return _ProductCard(
                item: item,
                selected: _selectedIds.contains(item.id),
                onToggleSelected: () => _toggleSelected(item.id),
                // Persisted stamp from the backend, or filled just now in
                // this session (before the list has been reloaded).
                isAiFilled:
                    item.isAiFilled || widget.aiFilledIds.contains(itemId),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildList(List<JewelryItem> products) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 80),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = products[index];
        final images = item.images ?? [];
        final selected = _selectedIds.contains(item.id);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: b2bCardDecoration(radius: B2BRadius.md).copyWith(
            border: Border.all(
                color: selected ? B2BColors.primary : B2BColors.border),
          ),
          child: ListTile(
            onTap: () => _toggleSelected(item.id),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _selectedIds.contains(item.id),
                  activeColor: B2BColors.primary,
                  onChanged: (_) => _toggleSelected(item.id),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(B2BRadius.sm),
                  child: images.isNotEmpty
                      ? Image.network(images.first,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                              width: 52,
                              height: 52,
                              child: Icon(Icons.image_not_supported,
                                  color: Colors.grey)))
                      : const SizedBox(
                          width: 52,
                          height: 52,
                          child: Icon(Icons.image, color: Colors.grey)),
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(item.productTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: B2BText.serif(size: 15.5, weight: FontWeight.w700)),
                ),
                if (item.isAiFilled ||
                    widget.aiFilledIds.contains(int.tryParse(item.id) ?? -1))
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: _AiFilledBadge(compact: true),
                  ),
              ],
            ),
            subtitle: Text(
              [
                if ((item.sku ?? '').isNotEmpty) 'SKU ${item.sku}',
                if ((item.category ?? '').isNotEmpty) item.category!,
                if ((item.productType ?? '').isNotEmpty) item.productType!,
              ].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: B2BColors.muted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('₹${item.price ?? '0'}',
                    style: B2BText.sans(size: 14, weight: FontWeight.w600)),
                const SizedBox(width: 14),
                const Icon(Icons.favorite_border_rounded,
                    size: 15, color: B2BColors.gold),
                const SizedBox(width: 4),
                Text('${item.likes ?? 0}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatefulWidget {
  final JewelryItem item;
  final bool selected;
  final VoidCallback? onToggleSelected;
  final bool isAiFilled;

  const _ProductCard({
    required this.item,
    this.selected = false,
    this.onToggleSelected,
    this.isAiFilled = false,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _isHovered = false;
  bool _isTapped = false; // New state for mobile tap

  // Helper to determine demand level
  String _getDemandLevel() {
    final likes = widget.item.likes ?? 0;
    final isTrending = widget.item.isTrending ?? false;

    if (isTrending || likes > 1000) return 'High demand';
    if (likes > 500) return 'Rising demand';
    return 'Medium demand';
  }

  // Helper to get demand level colors
  (Color bg, Color fg, Color border) _getDemandColors() {
    final demand = _getDemandLevel();
    if (demand == 'High demand') {
      return (
        B2BColors.primarySoft,
        B2BColors.primaryDeep,
        B2BColors.primaryTint,
      );
    } else if (demand == 'Rising demand') {
      return (
        B2BColors.goldSoft,
        const Color(0xFF8A6A36),
        const Color(0xFFE8D9BD),
      );
    } else {
      return (
        B2BColors.surfaceAlt, // gray-100
        B2BColors.inkSoft, // gray-700
        B2BColors.border, // gray-200
      );
    }
  }

  void _showInsights(BuildContext context) {
    // Get parent state to access unlock status
    final homeState = context.findAncestorStateOfType<_HomePageState>();

    showModalBottomSheet(
      context: context,
      constraints:
          BoxConstraints.expand(width: MediaQuery.of(context).size.width),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InsightsBottomSheet(
        item: widget.item,
        table: (homeState?._isManufacturer ?? false)
            ? 'manufacturerproducts'
            : 'designerproducts',
        isUnlocked:
            (homeState?._isManufacturer ?? false) || (homeState?._isPremium ?? false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item.productTitle;
    final category = widget.item.category ?? '';
    final subCategory = widget.item.subCategory ?? '';

    // Image logic
    final List<String> images = widget.item.images ?? [];
    final String imageUrl = images.isNotEmpty ? images[0] : '';

    // Location logic
    final String location = widget.item.users?['address'] ?? 'India';

    final int likes = widget.item.likes ?? 0;
    final int saves = widget.item.saves ?? 0;
    final int credits = widget.item.credits ?? 0;
    final bool isTrending = widget.item.isTrending ?? false;

    final demandLevel = _getDemandLevel();
    final demandColors = _getDemandColors();

    // Check if should show overlay (hover OR tap)
    final bool showOverlay = _isHovered || _isTapped;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          widget.onToggleSelected?.call();
          setState(() => _isTapped = !_isTapped);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: B2BColors.surface,
            borderRadius: BorderRadius.circular(B2BRadius.lg),
            border: Border.all(
              color: widget.selected ? B2BColors.primary : B2BColors.border,
              width: widget.selected ? 1.6 : 1,
            ),
            boxShadow: _isHovered ? B2BShadows.lifted : B2BShadows.soft,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(B2BRadius.lg - 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Image Section with 3:4 aspect ratio
                Expanded(
                  child: Stack(
                    children: [
                      // Product Image
                      Container(
                        width: double.infinity,
                        color: B2BColors.surfaceAlt,
                        child: imageUrl.isNotEmpty
                            ? AnimatedScale(
                                scale: _isHovered ? 1.04 : 1.0,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                child: Image.network(
                                imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: B2BColors.faint,
                                      size: 48,
                                    ),
                                  );
                                },
                              ))
                            : const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: B2BColors.faint,
                                  size: 48,
                                ),
                              ),
                      ),

                      // Bulk-selection checkbox
                      if (widget.onToggleSelected != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                borderRadius:
                                    BorderRadius.circular(B2BRadius.sm),
                                boxShadow: B2BShadows.soft,
                              ),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: Checkbox(
                                  value: widget.selected,
                                  activeColor: B2BColors.primary,
                                  onChanged: (_) => widget.onToggleSelected?.call(),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Moderation Status Badge — compact pill top-right
                      if (widget.item.status == 'pending' ||
                          widget.item.status == 'rejected' ||
                          widget.item.status == 'approved')
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _StatusBadge(status: widget.item.status!),
                        ),

                      // Trending Badge (Top Left)
                      if (isTrending)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFC9A66B),
                                  B2BColors.gold,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: B2BShadows.soft,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.trending_up,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "Trending",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ✨ AI Filled Badge (Bottom Left of image area)
                      if (widget.isAiFilled)
                        const Positioned(
                          bottom: 10,
                          left: 10,
                          child: _AiFilledBadge(),
                        ),

                      // Overlay with Action Buttons (Hover OR Tap)
                      if (showOverlay &&
                          widget.item.status != 'pending' &&
                          widget.item.status != 'rejected')
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  B2BColors.ink.withValues(alpha: 0.0),
                                  B2BColors.ink.withValues(alpha: 0.45),
                                ],
                              ),
                            ),
                            child: Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // View Insights Button (Compact for Mobile)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() =>
                                            _isTapped = false); // Close overlay
                                        _showInsights(context);
                                      },
                                      icon: const Icon(Icons.visibility,
                                          size: 18),
                                      label: const Text(
                                        'View Insights',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: B2BColors.primaryDeep,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // DELETE BUTTON
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              // Show confirmation
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Product'),
                                  content: const Text(
                                      'Are you sure you want to delete this product? This action cannot be undone and deletes all stats and images.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete',
                                          style: TextStyle(
                                              color: B2BColors.danger)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && context.mounted) {
                                // Call delete
                                final homeState = context
                                    .findAncestorStateOfType<_HomePageState>();
                                if (homeState != null) {
                                  // Show loading indicator
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Deleting product...')));
                                  final success = await homeState
                                      ._jewelryService
                                      .deleteProduct(widget.item);
                                  if (success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Product deleted successfully')));
                                    // Refresh feed
                                    homeState.setState(() {
                                      if (homeState._isManufacturer) {
                                        homeState._future = homeState
                                            ._jewelryService
                                            .getMyManufacturerProducts();
                                      } else {
                                        homeState._future = homeState
                                            ._jewelryService
                                            .getMyDesignerProducts();
                                      }
                                    });
                                  } else if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Failed to delete product'),
                                            backgroundColor: Colors.red));
                                  }
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                shape: BoxShape.circle,
                                boxShadow: B2BShadows.soft,
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: B2BColors.danger,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Details Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: B2BText.serif(size: 16.5, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),

                      // Category • SubCategory
                      Text(
                        "$category · $subCategory",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: B2BColors.muted,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Demand Level Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: demandColors.$1,
                          border: Border.all(
                            color: demandColors.$3,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              demandLevel,
                              style: TextStyle(
                                color: demandColors.$2,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "·",
                              style: TextStyle(
                                color: demandColors.$2,
                                fontSize: 11,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: demandColors.$2,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Footer: Stats & Credits
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Likes
                          const Icon(
                            Icons.favorite_border,
                            size: 16,
                            color: B2BColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$likes",
                            style: const TextStyle(
                              fontSize: 13,
                              color: B2BColors.muted,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Saves
                          const Icon(
                            Icons.bookmark_border,
                            size: 16,
                            color: B2BColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$saves",
                            style: const TextStyle(
                              fontSize: 13,
                              color: B2BColors.muted,
                            ),
                          ),

                          const Spacer(),

                          // Price / Credits
                          Text(
                            "$credits credits",
                            style: B2BText.sans(
                              size: 13,
                              weight: FontWeight.w600,
                              color: B2BColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────
/// Compact pill badge shown on product cards for moderation status.
/// pending → amber, approved → emerald green, rejected → rose red.
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon, String label) = switch (status) {
      'approved' => (
          const Color(0xFFD1FAE5),
          const Color(0xFF065F46),
          Icons.check_circle_rounded,
          'Approved',
        ),
      'rejected' => (
          const Color(0xFFFFE4E6),
          const Color(0xFF9F1239),
          Icons.cancel_rounded,
          'Rejected',
        ),
      _ => (
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
          Icons.schedule_rounded,
          'In Review',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}


/// Per-product performance sheet ("View Insights"). Loads the product's
/// report from the `b2b_insights` database function: real counts including
/// quote requests, a 30-day views trend, where the interest comes from and
/// observations generated from those numbers.
class _InsightsBottomSheet extends StatefulWidget {
  const _InsightsBottomSheet({
    required this.item,
    required this.table,
    this.isUnlocked = false,
  });

  final JewelryItem item;

  /// designerproducts / manufacturerproducts
  final String table;

  /// Manufacturers and premium designers see locations and insights; others
  /// see them blurred behind the upgrade card.
  final bool isUnlocked;

  @override
  State<_InsightsBottomSheet> createState() => _InsightsBottomSheetState();
}

class _InsightsBottomSheetState extends State<_InsightsBottomSheet> {
  late Future<InsightsReport> _future = _load();

  Future<InsightsReport> _load() {
    final productId = int.tryParse(widget.item.id);
    if (productId == null) {
      // Pending/rejected uploads live in `assets` and have no activity yet.
      return Future.error(
          'Insights become available once this product is approved.');
    }
    return B2BInsightsService()
        .fetch(table: widget.table, productId: productId);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final images = item.images ?? const <String>[];
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: B2BColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + header
          Container(
            decoration: const BoxDecoration(
              color: B2BColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: B2BColors.border)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 10, 14, 14),
            child: Column(children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: B2BColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(B2BRadius.md),
                  child: images.isNotEmpty
                      ? Image.network(images.first,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbPlaceholder())
                      : _thumbPlaceholder(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PRODUCT INSIGHTS', style: B2BText.eyebrow()),
                      const SizedBox(height: 3),
                      Text(item.productTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: B2BText.serif(size: 20)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if ((item.category ?? '').isNotEmpty) item.category!,
                          if ((item.metalPurity ?? '').isNotEmpty ||
                              (item.metalType ?? '').isNotEmpty)
                            '${item.metalPurity ?? ''} ${item.metalType ?? ''}'.trim(),
                          if (item.metalWeight != null) '${item.metalWeight}g',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: B2BText.sans(size: 12.5, color: B2BColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ]),
          ),

          Flexible(
            child: FutureBuilder<InsightsReport>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                if (snap.hasError) {
                  return _message(
                    '${snap.error}'.replaceFirst('Exception: ', ''),
                    retry: int.tryParse(item.id) == null
                        ? null
                        : () => setState(() => _future = _load()),
                  );
                }
                return _report(snap.data!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _report(InsightsReport r) {
    final t = r.totals;
    final tiles = [
      InsightStatTile(
          icon: Icons.visibility_outlined, label: 'Views', value: t.views,
          current: r.current.views, previous: r.previous.views, compact: true),
      InsightStatTile(
          icon: Icons.favorite_border_rounded, label: 'Likes', value: t.likes,
          current: r.current.likes, previous: r.previous.likes,
          accent: B2BColors.gold, compact: true),
      InsightStatTile(
          icon: Icons.bookmark_border_rounded, label: 'Saves', value: t.saves,
          current: r.current.saves, previous: r.previous.saves,
          accent: B2BColors.primaryDeep, compact: true),
      InsightStatTile(
          icon: Icons.ios_share_rounded, label: 'Shares', value: t.shares,
          current: r.current.shares, previous: r.previous.shares,
          accent: const Color(0xFF8A6A36), compact: true),
      InsightStatTile(
          icon: Icons.request_quote_outlined, label: 'Quote requests',
          value: t.quoteRequests, current: r.current.quoteRequests,
          previous: r.previous.quoteRequests, accent: B2BColors.success,
          highlight: true, compact: true),
    ];

    final locked = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InsightSection(
          title: 'Where the interest comes from',
          subtitle: 'Views, likes and saves by location',
          child: LocationBars(locations: r.topLocations),
        ),
        const SizedBox(height: 16),
        InsightSection(
          title: 'Key insights',
          child: KeyInsightsList(insights: r.keyInsights(singleProduct: true)),
        ),
      ],
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(builder: (context, c) {
              final perRow = c.maxWidth >= 560 ? 5 : 3;
              final w = (c.maxWidth - 10 * (perRow - 1)) / perRow;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [for (final tile in tiles) SizedBox(width: w, child: tile)],
              );
            }),
            const SizedBox(height: 16),
            InsightSection(
              title: 'Views · last ${r.windowDays} days',
              subtitle: '${r.current.views} in this period · '
                  '${r.previous.views} in the ${r.windowDays} days before',
              child: ViewsTrendChart(days: r.dailyViews, height: 140),
            ),
            const SizedBox(height: 16),
            if (widget.isUnlocked)
              locked
            else
              Stack(children: [
                locked,
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(B2BRadius.lg),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        color: B2BColors.canvas.withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        child: _upgradeCard(),
                      ),
                    ),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _message(String text, {VoidCallback? retry}) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insights_outlined, size: 34, color: B2BColors.gold),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: B2BText.sans(size: 14, color: B2BColors.inkSoft)),
          if (retry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: retry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 60,
        height: 60,
        color: B2BColors.surfaceAlt,
        child: const Icon(Icons.diamond_outlined, color: B2BColors.faint),
      );

  Widget _upgradeCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      decoration: b2bCardDecoration(lifted: true, radius: B2BRadius.xl)
          .copyWith(border: Border.all(color: const Color(0xFFE8D9BD))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                color: B2BColors.goldSoft, shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium,
                color: B2BColors.gold, size: 26),
          ),
          const SizedBox(height: 14),
          Text('Unlock full insights',
              textAlign: TextAlign.center, style: B2BText.serif(size: 20)),
          const SizedBox(height: 8),
          Text(
            'See where your buyers are and what drives demand for each design.',
            textAlign: TextAlign.center,
            style: B2BText.sans(size: 13, color: B2BColors.muted, height: 1.45),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(backgroundColor: B2BColors.gold),
              child: const Text('Upgrade to Premium'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small shared pieces ─────────────────────────────────────────────────────

/// "✦ AI Filled" in antique gold on deep emerald.
class _AiFilledBadge extends StatelessWidget {
  const _AiFilledBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Details completed with AI',
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 9, vertical: compact ? 3 : 4),
        decoration: BoxDecoration(
          color: B2BColors.primaryDeep.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: B2BColors.gold.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: compact ? 10 : 11, color: const Color(0xFFE2C58F)),
            const SizedBox(width: 4),
            Text(
              'AI Filled',
              style: B2BText.sans(
                size: compact ? 9.5 : 10,
                weight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(B2BRadius.sm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: selected ? B2BColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(B2BRadius.sm),
          ),
          child: Icon(icon,
              size: 18, color: selected ? B2BColors.primary : B2BColors.faint),
        ),
      ),
    );
  }
}

/// Centred icon, serif title and a short message for empty/error states.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: B2BColors.goldSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: B2BColors.gold),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center, style: B2BText.serif(size: 20)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: B2BText.sans(size: 13.5, color: B2BColors.muted)),
            ),
          ],
        ),
      ),
    );
  }
}
