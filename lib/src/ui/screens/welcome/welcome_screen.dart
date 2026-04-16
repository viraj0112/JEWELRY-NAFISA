import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/widgets/blur_up_placeholder.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/utils/image_url_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/widgets/login_required_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:jewelry_nafisa/src/ui/screens/info_dialog.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _supabase = Supabase.instance.client;
  final List<JewelryItem> _products = [];
  final List<JewelryItem> _allProducts = [];
  late ScrollController _scrollController;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _displayedCount = 100;
  static const int _initialItems = 100;
  static const int _itemsPerPage = 25;
  String _selectedMetalType = 'Gold';
  String _selectedProductType = 'All';
  List<String> _availableProductTypes = ['All'];
  String _selectedCategory = 'All';
  List<String> _availableCategories = ['All'];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadProducts();
    _fetchProductTypes(_selectedMetalType);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const InfoDialog(),
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 500 &&
        !_isLoadingMore &&
        _displayedCount < _allProducts.length) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || _displayedCount >= _allProducts.length) return;

    setState(() => _isLoadingMore = true);
    await Future.delayed(const Duration(milliseconds: 200));

    setState(() {
      _displayedCount = (_displayedCount + _itemsPerPage).clamp(0, _allProducts.length);
      _products
        ..clear()
        ..addAll(_allProducts.take(_displayedCount));
      _isLoadingMore = false;
    });
  }

  Future<List<JewelryItem>> _fetchFilteredProducts() async {
    try {
      const selectColumns = 'id, "Product Title", "Image", "Description", "Product Type", '
          'Category, Category1, Category2, Category3, "Sub Category", '
          '"Metal Type", "Metal Purity", Plain, Studded, "Price"';

      const designerSelectColumns = '$selectColumns, created_at';

      // Handle "Instant" (AKD*) separately
      if (_selectedMetalType == 'Instant') {
        return await _fetchInHouseProducts();
      }

      dynamic productsQuery = _supabase.from('products').select(selectColumns);
      dynamic designerQuery =
          _supabase.from('designerproducts').select(designerSelectColumns);
      dynamic manufacturerQuery =
          _supabase.from('manufacturerproducts').select(designerSelectColumns);

      if (_selectedMetalType != 'All') {
        final metal = _selectedMetalType.trim();
        // Use ilike() for case-insensitive pattern matching
        productsQuery = productsQuery.ilike('"Metal Type"', '%$metal%');
        designerQuery = designerQuery.ilike('"Metal Type"', '%$metal%');
        manufacturerQuery = manufacturerQuery.ilike('"Metal Type"', '%$metal%');
      }

      if (_selectedProductType != 'All') {
        productsQuery =
            productsQuery.eq('"Product Type"', _selectedProductType);
        designerQuery =
            designerQuery.eq('"Product Type"', _selectedProductType);
        manufacturerQuery =
            manufacturerQuery.eq('"Product Type"', _selectedProductType);
      }

      if (_selectedCategory != 'All') {
        final c = _selectedCategory.trim();
        final orFilter =
            'Category.eq.$c,Category1.eq.$c,Category2.eq.$c,Category3.eq.$c';
        productsQuery = productsQuery.or(orFilter);
        designerQuery = designerQuery.or(orFilter);
        manufacturerQuery = manufacturerQuery.or(orFilter);
      }

      productsQuery = productsQuery.order('id', ascending: false).range(0, 199);
      designerQuery =
          designerQuery.order('created_at', ascending: false).range(0, 199);
      manufacturerQuery =
          manufacturerQuery.order('created_at', ascending: false).range(0, 199);

      // Execute queries individually to catch errors per table
      List<dynamic> productsData = [];
      List<dynamic> designerProductsData = [];
      List<dynamic> manufacturerProductsData = [];

      try {
        productsData = await productsQuery;
        debugPrint('✓ Products table: ${productsData.length} items fetched');
      } catch (e) {
        debugPrint('✗ Products table error: $e');
      }

      try {
        designerProductsData = await designerQuery;
        debugPrint('✓ Designer products table: ${designerProductsData.length} items fetched');
      } catch (e) {
        debugPrint('✗ Designer products table error: $e');
      }

      try {
        manufacturerProductsData = await manufacturerQuery;
        debugPrint('✓ Manufacturer products table: ${manufacturerProductsData.length} items fetched');
      } catch (e) {
        debugPrint('✗ Manufacturer products table error: $e');
      }

      final List<JewelryItem> allItems = [];

      if (productsData is List) {
        allItems.addAll(
          productsData.map((item) =>
              JewelryItem.fromJson(item as Map<String, dynamic>)),
        );
      }

      if (designerProductsData is List) {
        allItems.addAll(
          designerProductsData.map((item) {
            final map = item as Map<String, dynamic>;
            map['is_designer_product'] = true;
            return JewelryItem.fromJson(map);
          }),
        );
      }

      if (manufacturerProductsData is List) {
        allItems.addAll(
          manufacturerProductsData.map((item) {
            final map = item as Map<String, dynamic>;
            map['is_manufacturer_product'] = true;
            return JewelryItem.fromJson(map);
          }),
        );
      }

      debugPrint('Total items before dedup: ${allItems.length}');

      // Remove duplicates by image + table source combination
      // This keeps the same image if it comes from different tables
      final uniqueProducts = <JewelryItem>[];
      final Set<String> seenCombinations = {};

      for (var product in allItems) {
        // Use image + table source as unique key instead of just image
        final key = '${product.image}-${product.isDesignerProduct}-${product.isManufacturerProduct}';
        if (!seenCombinations.contains(key)) {
          seenCombinations.add(key);
          uniqueProducts.add(product);
        }
      }
      uniqueProducts.shuffle();

      debugPrint('Total unique items: ${uniqueProducts.length}');
      return uniqueProducts;
    } catch (e) {
      debugPrint('Error loading images from Supabase: $e');
      return [];
    }
  }

  Future<List<JewelryItem>> _fetchInHouseProducts() async {
    try {
      const selectColumns = 'id, "Product Title", "Image", "Description", "Product Type", '
          'Category, Category1, Category2, Category3, "Sub Category", '
          '"Metal Type", "Metal Purity", Plain, Studded, "Price", created_at';

      List<dynamic> designerData = [];
      List<dynamic> manufacturerData = [];

      try {
          PostgrestFilterBuilder<dynamic> designerQuery = _supabase
              .from('designerproducts')
              .select(selectColumns)
              .ilike('"Metal Type"', 'AKD%');

        if (_selectedProductType != 'All') {
          designerQuery = designerQuery.eq('"Product Type"', _selectedProductType);
        }
        if (_selectedCategory != 'All') {
          final c = _selectedCategory.trim();
          designerQuery = designerQuery.or(
            'Category.eq.$c,Category1.eq.$c,Category2.eq.$c,Category3.eq.$c',
          );
        }

        designerData = await designerQuery
            .order('created_at', ascending: false)
            .range(0, 199);
        debugPrint('In-house Designer: ${designerData.length} AKD* items');
      } catch (e) {
        debugPrint('✗ Designer products error: $e');
      }

      try {
          PostgrestFilterBuilder<dynamic> manufacturerQuery = _supabase
              .from('manufacturerproducts')
              .select(selectColumns)
              .ilike('"Metal Type"', 'AKD%');

        if (_selectedProductType != 'All') {
          manufacturerQuery = manufacturerQuery.eq('"Product Type"', _selectedProductType);
        }
        if (_selectedCategory != 'All') {
          final c = _selectedCategory.trim();
          manufacturerQuery = manufacturerQuery.or(
            'Category.eq.$c,Category1.eq.$c,Category2.eq.$c,Category3.eq.$c',
          );
        }

        manufacturerData = await manufacturerQuery
            .order('created_at', ascending: false)
            .range(0, 199);
        debugPrint('In-house Manufacturer: ${manufacturerData.length} AKD* items');
      } catch (e) {
        debugPrint('✗ Manufacturer products error: $e');
      }

      final List<JewelryItem> allItems = [];

      if (designerData is List) {
        allItems.addAll(
          designerData.map((item) {
            final map = item as Map<String, dynamic>;
            map['is_designer_product'] = true;
            return JewelryItem.fromJson(map);
          }),
        );
      }

      if (manufacturerData is List) {
        allItems.addAll(
          manufacturerData.map((item) {
            final map = item as Map<String, dynamic>;
            map['is_manufacturer_product'] = true;
            return JewelryItem.fromJson(map);
          }),
        );
      }

      debugPrint('Total in-house items: ${allItems.length}');
      allItems.shuffle();
      return allItems;
    } catch (e) {
      debugPrint('Error loading Instant: $e');
      return [];
    }
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final products = await _fetchFilteredProducts();
    if (!mounted) return;

    setState(() {
      _allProducts
        ..clear()
        ..addAll(products);
      _displayedCount = _initialItems.clamp(0, products.length);
      _products
        ..clear()
        ..addAll(products.take(_displayedCount));
      _isLoading = false;
    });
  }

  String? _effectiveMetalTypeForFilters(String metalType) {
    if (metalType == 'Instant') return 'AKD';
    if (metalType == 'All') return null;
    return metalType;
  }

  Future<void> _onMetalTypeChanged(String value) async {
    setState(() {
      _selectedMetalType = value;
      _selectedProductType = 'All';
      _availableProductTypes = ['All'];
      _selectedCategory = 'All';
      _availableCategories = ['All'];
    });
    _displayedCount = _initialItems;
    if (value != 'All') {
      await _fetchProductTypes(value);
    }
    await _loadProducts();
  }

  Future<void> _fetchProductTypes(String metalType) async {
    try {
      final effectiveMetal = _effectiveMetalTypeForFilters(metalType)?.trim();
      if (effectiveMetal == null) {
        setState(() => _availableProductTypes = ['All']);
        return;
      }

      debugPrint('Fetching Product Types for $effectiveMetal...');

      final productsQuery = _supabase
          .from('products')
          .select('"Product Type"');
      final productsTypes = await (effectiveMetal == 'AKD'
              ? productsQuery.ilike('"Metal Type"', 'AKD%')
              : productsQuery.eq('"Metal Type"', effectiveMetal))
          .then((data) => (data as List)
              .map((item) => item['Product Type'])
              .whereType<String>()
              .where((t) => t.isNotEmpty)
              .toSet());
      
      final designerQuery = _supabase
          .from('designerproducts')
          .select('"Product Type"');
      final designerTypes = await (effectiveMetal == 'AKD'
              ? designerQuery.ilike('"Metal Type"', 'AKD%')
              : designerQuery.eq('"Metal Type"', effectiveMetal))
          .then((data) => (data as List)
              .map((item) => item['Product Type'])
              .whereType<String>()
              .where((t) => t.isNotEmpty)
              .toSet());

      final manufacturerQuery = _supabase
          .from('manufacturerproducts')
          .select('"Product Type"');
      final manufacturerTypes = await (effectiveMetal == 'AKD'
              ? manufacturerQuery.ilike('"Metal Type"', 'AKD%')
              : manufacturerQuery.eq('"Metal Type"', effectiveMetal))
          .then((data) => (data as List)
              .map((item) => item['Product Type'])
              .whereType<String>()
              .where((t) => t.isNotEmpty)
              .toSet());

      final allTypes = <String>{'All', ...productsTypes, ...designerTypes, ...manufacturerTypes}
          .toList();
      allTypes.sort();

      debugPrint('Available Product Types: $allTypes');

      setState(() => _availableProductTypes = allTypes);
    } catch (e) {
      debugPrint('Error fetching product types: $e');
    }
  }

  Future<void> _fetchCategories({
    required String metalType,
    required String productType,
  }) async {
    try {
      final effectiveMetal = _effectiveMetalTypeForFilters(metalType)?.trim();
      if (effectiveMetal == null || productType == 'All') {
        if (!mounted) return;
        setState(() => _availableCategories = ['All']);
        return;
      }

      const categoryKeys = ['Category', 'Category1', 'Category2', 'Category3'];
      const selectColumns = '"Category", "Category1", "Category2", "Category3"';

      Future<Set<String>> fetchFrom(String table) async {
        final query = _supabase
            .from(table)
            .select(selectColumns);
        final data = await (effectiveMetal == 'AKD'
                ? query.ilike('"Metal Type"', 'AKD%')
                : query.eq('"Metal Type"', effectiveMetal))
            .eq('"Product Type"', productType);

        final out = <String>{};
        for (final row in (data as List)) {
          final m = row as Map<String, dynamic>;
          for (final k in categoryKeys) {
            final v = m[k];
            if (v is String) {
              final s = v.trim();
              if (s.isNotEmpty) out.add(s);
            }
          }
        }
        return out;
      }

      final a = await fetchFrom('products');
      final b = await fetchFrom('designerproducts');
      final c = await fetchFrom('manufacturerproducts');

      final all = <String>{'All', ...a, ...b, ...c}.toList()..sort();
      if (!mounted) return;
      setState(() => _availableCategories = all);
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }


  void _navigateToLogin() {
    context.push('/login');
  }

  void _navigateToRegister() {
    context.push('/signup');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return isWide ? _buildWideLayout() : _buildNarrowLayout();
                },
              ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // _buildNavigationRail(),
            // const VerticalDivider(thickness: 1, width: 16),
            Expanded(
              child: Column(
                children: [
                  _buildAppBar(),
                  _buildFilterBar(),
                  Expanded(
                    child: _products.isEmpty
                        ? const Center(child: Text('Coming Soon'))
                        : _buildImageGrid(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _products.isEmpty
                ? const Center(child: Text('Coming Soon'))
                : _buildImageGrid(),
          )
        ],
      ),
      // bottomNavigationBar: _buildFixedNavBar(),
    );
  }

  Widget _buildNavigationRail() {
    final theme = Theme.of(context);

    return NavigationRail(
      selectedIndex: 0,
      onDestinationSelected: (index) => _navigateToLogin(),
      labelType: NavigationRailLabelType.all,
      useIndicator: true,
      indicatorColor: Colors.transparent,
      selectedLabelTextStyle: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 52.0),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFDAB766),
          child: Text(
            'G',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
      unselectedIconTheme: IconThemeData(
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search),
          label: Text('Search'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.add_box_outlined),
          selectedIcon: Icon(Icons.add_box_rounded),
          label: Text('Boards'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: Text('Updates'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Profile'),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    const Color customGreen = Color(0xFF336B43);
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16.0,
      elevation: 0,
      backgroundColor: customGreen,
      title: Row(
        children: [
          Image.asset(
            'assets/icons/DDlogo.png',
            height: 32,
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildSearchBar(Theme.of(context))),
        ],
      ),
      actions: [
        _buildGuestMenu(context),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => const LoginRequiredDialog(),
        );
      },
      borderRadius: BorderRadius.circular(12.0),
      autofocus: true,
      hoverColor: Colors.grey.withOpacity(0.5),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: theme.splashColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: theme.dividerColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 8.0),
            Text(
              'Search for designs',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 16.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestMenu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      offset: const Offset(0, 50),
      onSelected: (value) {
        if (value == 'login') {
          _navigateToLogin();
        } else if (value == 'register') {
          _navigateToRegister();
        }
      },
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Text(
              'G',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.white),
        ],
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: 'login', child: Text('Login')),
        const PopupMenuItem<String>(value: 'register', child: Text('Register')),
      ],
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedMetalType = 'Gold';
      _selectedProductType = 'All';
      _availableProductTypes = ['All'];
      _selectedCategory = 'All';
      _availableCategories = ['All'];
    });
    _displayedCount = _initialItems;
    _fetchProductTypes(_selectedMetalType);
    _loadProducts();
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12.0,
              runSpacing: 8.0,
              children: [
                Text(
                  'Choose Your Style',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF006435),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                ),
                // Reset button (centered with title)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _resetFilters,
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 6.0,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFE0E0E0),
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, size: 16),
                          SizedBox(width: 4.0),
                          Text('Reset', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMetalTypeButton('Gold', _selectedMetalType == 'Gold'),
                const SizedBox(width: 6.0),
                _buildMetalTypeButton('Silver', _selectedMetalType == 'Silver'),
                const SizedBox(width: 6.0),
                _buildMetalTypeButton('Instant', _selectedMetalType == 'Instant'),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0, -0.08),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child: _selectedMetalType != 'All'
                ? Padding(
                    key: const ValueKey('productTypeDropdown'),
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildProductTypeDropdown(),
                  )
                : const SizedBox.shrink(key: ValueKey('productTypeDropdownEmpty')),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0, -0.08),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child: _selectedMetalType != 'All' && _selectedProductType != 'All'
                ? Padding(
                    key: const ValueKey('categoryDropdown'),
                    padding: const EdgeInsets.only(top: 10.0),
                    child: _buildCategoryDropdown(),
                  )
                : const SizedBox.shrink(key: ValueKey('categoryDropdownEmpty')),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTypeDropdown() {
    return _buildAnimatedOvalDropdown(
      value: _selectedProductType,
      items: _availableProductTypes,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedProductType = value;
            _selectedCategory = 'All';
            _availableCategories = ['All'];
          });
          _fetchCategories(
            metalType: _selectedMetalType,
            productType: value,
          );
          _loadProducts();
        }
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return _buildAnimatedOvalDropdown(
      value: _selectedCategory,
      items: _availableCategories,
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedCategory = value);
          _loadProducts();
        }
      },
    );
  }

  Widget _buildAnimatedOvalDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.96, end: 1.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD8D8D8), width: 1.2),
              borderRadius: BorderRadius.circular(28.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade700,
                  size: 20,
                ),
                borderRadius: BorderRadius.circular(20),
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF2F2F2F),
                  fontWeight: FontWeight.w500,
                ),
                items: items
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetalTypeButton(String metalType, bool isSelected) {
    Color textColor;
    BoxDecoration decoration;

    if (isSelected) {
      textColor = Colors.white;
      switch (metalType) {
        case 'Gold':
          decoration = BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFB84D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.25),
                blurRadius: 3,
                offset: const Offset(0, 1.5),
              ),
            ],
          );
          break;
        case 'Silver':
          decoration = BoxDecoration(
            color: const Color(0xFFB8B8B8),
            borderRadius: BorderRadius.circular(18.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB8B8B8).withOpacity(0.25),
                blurRadius: 3,
                offset: const Offset(0, 1.5),
              ),
            ],
          );
          break;
        case 'Instant':
          // Return special animated widget for Instant
          return _buildInstantButton();
        default:
          decoration = BoxDecoration(
            color: const Color(0xFF9E9E9E),
            borderRadius: BorderRadius.circular(18.0),
          );
      }
    } else {
      textColor = const Color(0xFF424242);
      decoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1.5,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isSelected) {
            _onMetalTypeChanged('All');
          } else {
            _onMetalTypeChanged(metalType);
          }
        },
        borderRadius: BorderRadius.circular(18.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 18.0),
          decoration: decoration,
          child: Text(
            metalType == 'Instant' ? 'Get it' : metalType,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstantButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _onMetalTypeChanged('Instant');
        },
        borderRadius: BorderRadius.circular(18.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 18.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E3F), Color(0xFF2D8659), Color(0xFF1B5E3F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2D8659).withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            children: [
              // Glowing stars animation
              const Positioned.fill(
                child: IgnorePointer(
                  child: _GlowingStarsAnimation(),
                ),
              ),
              // Text on top
              Text(
                'Get it',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  shadows: [
                    Shadow(
                      color: Colors.white.withOpacity(0.5),
                      blurRadius: 4,
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

  Widget _buildImageGrid() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(8.0),
          sliver: SliverMasonryGrid.count(
            crossAxisCount:
                (MediaQuery.of(context).size.width / 200).floor().clamp(2, 8),
            childCount: _products.length,
            itemBuilder: (context, index) {
              final item = _products[index];
              return _buildImageCard(context, item);
            },
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
          ),
        ),
        if (_isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }


  Widget _buildImageCard(BuildContext context, JewelryItem item) {
    final imageUrl = resolveImageUrl(item.image);

    // Skip rendering cards with missing image URLs
    if (imageUrl.isEmpty) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: item.aspectRatio,
          child: Container(
            color: Colors.grey[200],
            child: Center(
              child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        final isDesigner = item.isDesignerProduct;
        final isManufacturer = item.isManufacturerProduct;
        context.push('/product/${item.id}?isDesigner=$isDesigner&isManufacturer=${isManufacturer}');
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: item.aspectRatio,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => createBlurUpPlaceholder(),
            errorWidget: (context, url, error) => Container(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            fadeInDuration: const Duration(milliseconds: 300),
            fadeOutDuration: const Duration(milliseconds: 300),
            memCacheHeight: 400,
            memCacheWidth: 400,
            maxHeightDiskCache: 400,
            maxWidthDiskCache: 400,
            cacheKey: imageUrl,
          ),
        ),
      ),
    );
  }
}

/// Animated glowing stars widget for Instant button
class _GlowingStarsAnimation extends StatefulWidget {
  const _GlowingStarsAnimation();

  @override
  State<_GlowingStarsAnimation> createState() => _GlowingStarsAnimationState();
}

class _GlowingStarsAnimationState extends State<_GlowingStarsAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Star> _stars = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Generate random stars
    final random = Random();
    for (int i = 0; i < 5; i++) {
      _stars.add(
        _Star(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 2 + 1,
          delay: random.nextDouble() * 3,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox.expand(
          child: CustomPaint(
            painter: _StarsPainter(
              animation: _controller.value,
              stars: _stars,
            ),
          ),
        );
      },
    );
  }
}

class _Star {
  final double x;
  final double y;
  final double size;
  final double delay;

  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.delay,
  });
}

class _StarsPainter extends CustomPainter {
  final double animation;
  final List<_Star> stars;

  _StarsPainter({
    required this.animation,
    required this.stars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      // Calculate animation progress for this star
      double progress = (animation + star.delay / 3) % 1.0;

      // Opacity animation (fade in and out)
      double opacity = (sin(progress * pi * 2) + 1) / 2;

      // Position with slight movement
      double offsetX = sin(progress * pi * 2) * 5;
      double offsetY = cos(progress * pi * 2) * 5;

      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity * 0.8)
        ..style = PaintingStyle.fill;

      // Draw star
      _drawStar(
        canvas,
        Offset(
          star.x * size.width + offsetX,
          star.y * size.height + offsetY,
        ),
        star.size,
        paint,
      );

      // Draw glow
      final glowPaint = Paint()
        ..color = const Color(0xFF4CAF50).withOpacity(opacity * 0.4)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(
          star.x * size.width + offsetX,
          star.y * size.height + offsetY,
        ),
        star.size * 2,
        glowPaint,
      );
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    const numPoints = 5;
    const innerRadius = 0.4;

    for (int i = 0; i < numPoints * 2; i++) {
      final angle = (i * pi) / numPoints - pi / 2;
      final radius = i.isEven ? size : size * innerRadius;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) => true;
}

