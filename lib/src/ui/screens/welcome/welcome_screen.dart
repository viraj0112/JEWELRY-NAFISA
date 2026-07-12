import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/widgets/blur_up_placeholder.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/utils/share_utils.dart';
import 'package:jewelry_nafisa/src/utils/image_url_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/widgets/login_required_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:jewelry_nafisa/src/ui/screens/info_dialog.dart';
import 'package:jewelry_nafisa/src/widgets/floating_filter_panel.dart';
import 'package:jewelry_nafisa/src/widgets/glowing_logo.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:jewelry_nafisa/src/services/filter_service.dart';

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
  String _selectedAkdMetalType = 'All';
  String _selectedProductType = 'All';
  List<String> _availableProductTypes = ['All'];
  String _selectedCategory = 'All';
  List<String> _availableCategories = ['All'];

  List<String> _akdMetalTypeOptions = ['All'];
  bool _isLoadingAkdMetalTypes = false;
  bool _isLoadingProductTypes = false;
  bool _isLoadingCategories = false;

  final Set<String> _itemsBeingLiked = {};
  RealtimeChannel? _likesChannel;

  String _displayMetalType(String value) {
    return value.replaceFirst(RegExp(r'^AKD-', caseSensitive: false), '');
  }

  // --- Advanced Filter Options ---
  List<String> _availableMetalColors = [];
  List<String> _availableMetalPurities = [];
  List<String> _availableStoneShapes = [];
  List<String> _availableStoneTypes = [];
  List<String> _availableStoneQualities = [];
  List<String> _availableStoneSettings = [];
  List<String> _availableFeaturedTags = [];

  List<double> _metalWeightBounds = [0.0, 100.0];
  List<double> _stoneWeightBounds = [0.0, 100.0];

  bool _isLoadingAdvancedOptions = false;

  // --- Advanced Filter State Selections ---
  String? _selectedJewelleryType;
  List<String> _selectedMetalColors = [];
  List<String> _selectedMetalPurities = [];
  bool _isEnamelWorkChecked = false;
  List<String> _selectedStoneShapes = [];
  List<String> _selectedStoneTypes = [];
  List<String> _selectedStoneQualities = [];
  List<String> _selectedStoneSettings = [];
  List<String> _selectedFeaturedTags = [];
  List<double>? _currentMetalWeightRange;
  List<double>? _currentStoneWeightRange;

  // --- Advanced Filter Callbacks ---
  void _onJewelleryTypeChanged(String? val) {
    setState(() => _selectedJewelleryType = val);
  }

  void _onMetalWeightChanged(List<double> val) {
    setState(() => _currentMetalWeightRange = val);
  }

  void _onMetalColorsChanged(List<String> val) {
    setState(() => _selectedMetalColors = val);
  }

  void _onMetalPuritiesChanged(List<String> val) {
    setState(() => _selectedMetalPurities = val);
  }

  void _onEnamelWorkChanged(bool val) {
    setState(() => _isEnamelWorkChecked = val);
  }

  void _onStoneWeightChanged(List<double> val) {
    setState(() => _currentStoneWeightRange = val);
  }

  void _onStoneShapesChanged(List<String> val) {
    setState(() => _selectedStoneShapes = val);
  }

  void _onStoneTypesChanged(List<String> val) {
    setState(() => _selectedStoneTypes = val);
  }

  void _onStoneQualitiesChanged(List<String> val) {
    setState(() => _selectedStoneQualities = val);
  }

  void _onStoneSettingsChanged(List<String> val) {
    setState(() => _selectedStoneSettings = val);
  }

  void _onFeaturedTagsChanged(List<String> val) {
    setState(() => _selectedFeaturedTags = val);
  }

  Future<void> _loadAdvancedFilters() async {
    setState(() => _isLoadingAdvancedOptions = true);
    try {
      final filters = <String, String?>{};
      final effectiveMetal = _effectiveMetalTypeForFilters(_selectedMetalType);
      if (effectiveMetal != null) {
        filters['Metal Type'] = effectiveMetal;
      }
      if (_selectedProductType != 'All') {
        filters['Product Type'] = _selectedProductType;
      }
      if (_selectedCategory != 'All') {
        filters['Category'] = _selectedCategory;
      }
      if (_selectedJewelleryType != null) {
        filters['Jewellery Type'] = _selectedJewelleryType;
      }

      final futures = await Future.wait([
        _filterService.getDependentDistinctValues('Metal Color', filters),
        _filterService.getDependentDistinctValues('Metal Purity', filters),
        _filterService.getDependentDistinctArrayValues('Stone Cut', filters),
        _filterService.getDependentDistinctArrayValues('Stone Type', filters),
        _filterService.getDependentDistinctArrayValues('Stone Purity', filters),
        _filterService.getDependentDistinctArrayValues(
            'Stone Setting', filters),
        _filterService.getDependentDistinctArrayValues(
            'Product Tags', filters),
        // Phase 1 added a real "Metal Weight" column; read it directly instead
        // of the old "Net Weight" approximation. Both weight ranges narrow to
        // the currently selected Product Type/Category/Metal Type etc.
        _filterService.getWeightRange('Metal Weight', filters: filters),
        _filterService.getWeightRange('Stone Weight',
            isArray: true, filters: filters),
      ]);

      if (mounted) {
        setState(() {
          _availableMetalColors = futures[0] as List<String>;
          _availableMetalPurities = futures[1] as List<String>;
          _availableStoneShapes = futures[2] as List<String>;
          _availableStoneTypes = futures[3] as List<String>;
          _availableStoneQualities = futures[4] as List<String>;
          _availableStoneSettings = futures[5] as List<String>;
          _availableFeaturedTags = futures[6] as List<String>;
          _metalWeightBounds = futures[7] as List<double>;
          _stoneWeightBounds = futures[8] as List<double>;
          _isLoadingAdvancedOptions = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading advanced filters: $e');
      if (mounted) setState(() => _isLoadingAdvancedOptions = false);
    }
  }

  final FilterService _filterService = FilterService();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadProducts();
    _fetchProductTypes(_selectedMetalType);
    _loadAdvancedFilters();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const InfoDialog(),
      );
    });
    _setupLikesListener();
  }

  void _setupLikesListener() {
    _likesChannel = _supabase.channel('public:likes_channel_welcome')
      ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'products',
          callback: _handleProductUpdate)
      ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'designerproducts',
          callback: _handleProductUpdate)
      ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'manufacturerproducts',
          callback: _handleProductUpdate)
      ..subscribe();
  }

  void _handleProductUpdate(PostgresChangePayload payload) {
    if (!mounted) return;
    final newRecord = payload.newRecord;
    final id = newRecord['id'].toString();
    final newLikes = newRecord['likes'];

    if (newLikes != null && newLikes is int) {
      final index = _products.indexWhere((p) => p.id == id);
      if (index != -1 && _products[index].likes != newLikes) {
        setState(() {
          _products[index].likes = newLikes;
        });
      }
      final allIndex = _allProducts.indexWhere((p) => p.id == id);
      if (allIndex != -1 && _allProducts[allIndex].likes != newLikes) {
        _allProducts[allIndex].likes = newLikes;
      }
    }
  }

  @override
  void dispose() {
    _likesChannel?.unsubscribe();
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
      _displayedCount =
          (_displayedCount + _itemsPerPage).clamp(0, _allProducts.length);
      _products
        ..clear()
        ..addAll(_allProducts.take(_displayedCount));
      _isLoadingMore = false;
    });
  }

  Future<List<JewelryItem>> _fetchFilteredProducts() async {
    try {
      const selectColumns =
          'id, "Product Title", "Image", "Description", "Product Type", '
          'Category, Category1, Category2, Category3, "Sub Category", '
          '"Metal Type", "Metal Purity", Plain, Studded, "Price", '
          // Phase 2 unified columns (model prefers these, falls back to old ones):
          'images_arr, category_arr, metal_color_arr';

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

      if (_selectedMetalColors.isNotEmpty) {
        // OR/overlap semantics against the unified metal_color_arr (text[]):
        // matches if the product has ANY of the selected colors, so 2-tone
        // products match on either of their colors.
        productsQuery =
            productsQuery.overlaps('metal_color_arr', _selectedMetalColors);
        designerQuery =
            designerQuery.overlaps('metal_color_arr', _selectedMetalColors);
        manufacturerQuery = manufacturerQuery.overlaps(
            'metal_color_arr', _selectedMetalColors);
      }

      if (_selectedFeaturedTags.isNotEmpty) {
        productsQuery =
            productsQuery.overlaps('"Product Tags"', _selectedFeaturedTags);
        designerQuery =
            designerQuery.overlaps('"Product Tags"', _selectedFeaturedTags);
        manufacturerQuery = manufacturerQuery.overlaps(
            '"Product Tags"', _selectedFeaturedTags);
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
        debugPrint(
            '✓ Designer products table: ${designerProductsData.length} items fetched');
      } catch (e) {
        debugPrint('✗ Designer products table error: $e');
      }

      try {
        manufacturerProductsData = await manufacturerQuery;
        debugPrint(
            '✓ Manufacturer products table: ${manufacturerProductsData.length} items fetched');
      } catch (e) {
        debugPrint('✗ Manufacturer products table error: $e');
      }

      final List<JewelryItem> allItems = [];

      if (productsData is List) {
        allItems.addAll(
          productsData.map(
              (item) => JewelryItem.fromJson(item as Map<String, dynamic>)),
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

      // Commented out: Remove duplicates by image + table source combination
      // This keeps the same image if it comes from different tables
      // final uniqueProducts = <JewelryItem>[];
      // final Set<String> seenCombinations = {};
      //
      // for (var product in allItems) {
      //   // Use image + table source as unique key instead of just image
      //   final key = '${product.image}-${product.isDesignerProduct}-${product.isManufacturerProduct}';
      //   if (!seenCombinations.contains(key)) {
      //     seenCombinations.add(key);
      //     uniqueProducts.add(product);
      //   }
      // }
      // uniqueProducts.shuffle();

      // Show only single image per product (no duplicates)
      final uniqueProducts = <JewelryItem>[];
      final Set<String> seenImages = {};

      for (var product in allItems) {
        if (!seenImages.contains(product.image)) {
          seenImages.add(product.image);
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
      const selectColumns =
          'id, "Product Title", "Image", "Description", "Product Type", '
          'Category, Category1, Category2, Category3, "Sub Category", '
          '"Metal Type", "Metal Purity", Plain, Studded, "Price", created_at, '
          'images_arr, category_arr, metal_color_arr';

      List<dynamic> designerData = [];
      List<dynamic> manufacturerData = [];

      try {
        var designerQuery =
            _supabase.from('designerproducts').select(selectColumns);

        if (_selectedAkdMetalType != 'All') {
          designerQuery =
              designerQuery.eq('"Metal Type"', _selectedAkdMetalType);
        } else {
          designerQuery = designerQuery.ilike('"Metal Type"', 'AKD%');
        }

        if (_selectedProductType != 'All') {
          designerQuery =
              designerQuery.eq('"Product Type"', _selectedProductType);
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
      } catch (e) {
        debugPrint('Error loading in-house designer: $e');
      }

      try {
        var manufacturerQuery =
            _supabase.from('manufacturerproducts').select(selectColumns);

        if (_selectedAkdMetalType != 'All') {
          manufacturerQuery =
              manufacturerQuery.eq('"Metal Type"', _selectedAkdMetalType);
        } else {
          manufacturerQuery = manufacturerQuery.ilike('"Metal Type"', 'AKD%');
        }

        if (_selectedProductType != 'All') {
          manufacturerQuery =
              manufacturerQuery.eq('"Product Type"', _selectedProductType);
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
      } catch (e) {
        debugPrint('Error loading in-house manufacturer: $e');
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
    if (metalType == 'Instant') {
      if (_selectedAkdMetalType != 'All') {
        return _selectedAkdMetalType;
      }
      return 'AKD';
    }
    if (metalType == 'All') return null;
    return metalType;
  }

  Future<void> _loadAkdMetalTypes() async {
    setState(() {
      _isLoadingAkdMetalTypes = true;
      _akdMetalTypeOptions = ['All'];
    });
    try {
      final Set<String> akdTypes = {};

      final designerRes = await _supabase
          .from('designerproducts')
          .select('"Metal Type"')
          .ilike('"Metal Type"', 'AKD-%');
      if (designerRes is List) {
        for (var row in designerRes) {
          final val = row['Metal Type'] as String?;
          if (val != null && val.isNotEmpty) {
            akdTypes.add(val);
          }
        }
      }

      final manufacturerRes = await _supabase
          .from('manufacturerproducts')
          .select('"Metal Type"')
          .ilike('"Metal Type"', 'AKD-%');
      if (manufacturerRes is List) {
        for (var row in manufacturerRes) {
          final val = row['Metal Type'] as String?;
          if (val != null && val.isNotEmpty) {
            akdTypes.add(val);
          }
        }
      }

      final List<String> fetched = akdTypes.toList()..sort();

      if (mounted) {
        setState(() {
          _akdMetalTypeOptions = ['All', ...fetched];
          _isLoadingAkdMetalTypes = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading AKD metal types: $e');
      if (mounted) {
        setState(() => _isLoadingAkdMetalTypes = false);
      }
    }
  }

  Future<void> _onAkdMetalTypeChanged(String? value,
      {bool applyImmediately = true}) async {
    if (value == null) return;
    setState(() {
      _selectedAkdMetalType = value;
      _selectedProductType = 'All';
      _selectedCategory = 'All';
      _availableProductTypes = ['All'];
      _availableCategories = ['All'];
    });

    final effectiveMetal = _effectiveMetalTypeForFilters('Instant');
    if (effectiveMetal != null) {
      await _fetchProductTypes(effectiveMetal);
    }
    if (applyImmediately) await _loadProducts();
  }

  Future<void> _onMetalTypeChanged(String value,
      {bool applyImmediately = true}) async {
    setState(() {
      _selectedMetalType = value;
      _selectedAkdMetalType = 'All';
      _selectedProductType = 'All';
      _availableProductTypes = ['All'];
      _selectedCategory = 'All';
      _availableCategories = ['All'];
    });
    _displayedCount = _initialItems;

    if (value == 'Instant') {
      await _loadAkdMetalTypes();
    }

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

      final productsQuery = _supabase.from('products').select('"Product Type"');
      final productsTypes = await (effectiveMetal == 'AKD'
              ? productsQuery.ilike('"Metal Type"', 'AKD%')
              : productsQuery.eq('"Metal Type"', effectiveMetal))
          .then((data) => (data as List)
              .map((item) => item['Product Type'])
              .whereType<String>()
              .where((t) => t.isNotEmpty)
              .toSet());

      final designerQuery =
          _supabase.from('designerproducts').select('"Product Type"');
      final designerTypes = await (effectiveMetal == 'AKD'
              ? designerQuery.ilike('"Metal Type"', 'AKD%')
              : designerQuery.eq('"Metal Type"', effectiveMetal))
          .then((data) => (data as List)
              .map((item) => item['Product Type'])
              .whereType<String>()
              .where((t) => t.isNotEmpty)
              .toSet());

      final manufacturerQuery =
          _supabase.from('manufacturerproducts').select('"Product Type"');
      final manufacturerTypes = await (effectiveMetal == 'AKD'
              ? manufacturerQuery.ilike('"Metal Type"', 'AKD%')
              : manufacturerQuery.eq('"Metal Type"', effectiveMetal))
          .then((data) => (data as List)
              .map((item) => item['Product Type'])
              .whereType<String>()
              .where((t) => t.isNotEmpty)
              .toSet());

      final allTypes = <String>{
        'All',
        ...productsTypes,
        ...designerTypes,
        ...manufacturerTypes
      }.toList();
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
      const selectColumns =
          '"Category", "Category1", "Category2", "Category3", category_arr';

      Future<Set<String>> fetchFrom(String table) async {
        final query = _supabase.from(table).select(selectColumns);
        final data = await (effectiveMetal == 'AKD'
                ? query.ilike('"Metal Type"', 'AKD%')
                : query.eq('"Metal Type"', effectiveMetal))
            .eq('"Product Type"', productType);

        final out = <String>{};
        for (final row in (data as List)) {
          final m = row as Map<String, dynamic>;
          // Prefer the unified category_arr (Phase 1) when present and
          // non-empty; fall back to the legacy scalar columns otherwise.
          final arr = m['category_arr'];
          if (arr is List && arr.isNotEmpty) {
            for (final v in arr) {
              final s = v?.toString().trim();
              if (s != null && s.isNotEmpty) out.add(s);
            }
            continue;
          }
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

  Future<void> _likeItem(JewelryItem item) async {
    if (_itemsBeingLiked.contains(item.id)) return;

    setState(() {
      _itemsBeingLiked.add(item.id);
    });

    try {
      final uid = _supabase.auth.currentUser?.id;
      final prefs = await SharedPreferences.getInstance();
      String? sessionId = prefs.getString('anonymous_session_id');
      if (sessionId == null) {
        sessionId = const Uuid().v4();
        await prefs.setString('anonymous_session_id', sessionId);
      }

      final isNowLiked = !item.isFavorite; // It's a toggle

      // Determine table
      String itemTable = 'products';
      if (item.isDesignerProduct) {
        itemTable = 'designerproducts';
      } else if (item.isManufacturerProduct) {
        itemTable = 'manufacturerproducts';
      }

      // Call the RPC
      final newLikesCount = await _supabase.rpc('toggle_product_like', params: {
        'p_item_id': item.id,
        'p_item_table': itemTable,
        'p_user_id': uid,
        'p_session_id': sessionId,
      });

      if (mounted) {
        final productIndex = _products.indexWhere((i) => i.id == item.id);
        if (productIndex != -1) {
          setState(() {
            _products[productIndex].isFavorite = isNowLiked;
            if (newLikesCount is int) {
              _products[productIndex].likes = newLikesCount;
            }
          });
        }
        final allIndex = _allProducts.indexWhere((i) => i.id == item.id);
        if (allIndex != -1) {
          _allProducts[allIndex].isFavorite = isNowLiked;
          if (newLikesCount is int) {
            _allProducts[allIndex].likes = newLikesCount;
          }
        }
      }
    } catch (e) {
      debugPrint("Error toggling like on welcome screen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not update like status.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _itemsBeingLiked.remove(item.id));
      }
    }
  }

  void _shareItem(JewelryItem item) {
    if (_supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to share items.")),
      );
      return;
    }
    
    // Use ShareUtils to download the image and share the link + image properly
    ShareUtils.shareJewelryItem(context, item, _supabase);
  }

  // ── Proper product-type / category callbacks for the floating panel ────────

  Future<void> _onProductTypeChanged(String? value,
      {bool applyImmediately = true}) async {
    if (value == null) return;
    setState(() {
      _selectedProductType = value;
      _selectedCategory = 'All';
      _availableCategories = ['All'];
      _isLoadingCategories = true;
    });
    _displayedCount = _initialItems;
    await _fetchCategories(
      metalType: _selectedMetalType,
      productType: value,
    );
    if (mounted) setState(() => _isLoadingCategories = false);
    _loadAdvancedFilters();
    if (applyImmediately) await _loadProducts();
  }

  Future<void> _onCategoryChanged(String? value,
      {bool applyImmediately = true}) async {
    if (value == null) return;
    setState(() => _selectedCategory = value);
    _displayedCount = _initialItems;
    _loadAdvancedFilters();
    if (applyImmediately) await _loadProducts();
  }

  void _onSubCategoryChanged(String? value, {bool applyImmediately = true}) {
    // Welcome screen does not have sub-category; no-op.
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: _isLoading
            ? Center(child: GlowingLogo(size: 80))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return isWide ? _buildWideLayout() : _buildNarrowLayout();
                },
              ),
      ),
    );
  }

  /// Maintenance banner that auto-shows only within the announced window and
  /// disappears on its own afterwards. Window is defined in IST (UTC+5:30);
  /// we compare in UTC so it's correct regardless of the device's timezone.
  Widget _buildMaintenanceBanner() {
    // 21:00 IST == 15:30 UTC. Window: 11 Jul 2026 -> 14 Jul 2026.
    final startUtc = DateTime.utc(2026, 7, 11, 15, 30);
    final endUtc = DateTime.utc(2026, 7, 14, 15, 30);
    final nowUtc = DateTime.now().toUtc();

    if (nowUtc.isBefore(startUtc) || nowUtc.isAfter(endUtc)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3CD),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.build_circle_outlined,
              size: 18, color: Color(0xFF8A6D00)),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Site is under maintenance from 21:00 11-07-2026 IST to 21:00 14-07-2026',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF8A6D00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    final filterConfig = _buildFilterConfig();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildAppBar(),
                  _buildMaintenanceBanner(),
                  _buildFilterBar(),
                  Expanded(
                    child: FloatingFilterOverlay(
                      config: filterConfig,
                      child: _products.isEmpty
                          ? const Center(child: Text('Coming Soon'))
                          : _buildImageGrid(),
                    ),
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
    final filterConfig = _buildFilterConfig();
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildMaintenanceBanner(),
          _buildFilterBar(),
          Expanded(
            child: FloatingFilterOverlay(
              config: filterConfig,
              child: _products.isEmpty
                  ? const Center(child: Text('Coming Soon'))
                  : _buildImageGrid(),
            ),
          ),
        ],
      ),
    );
  }

  FloatingFilterConfig _buildFilterConfig() {
    return FloatingFilterConfig(
      selectedMetalType: _selectedMetalType,
      selectedAkdMetalType: _selectedAkdMetalType,
      selectedProductType: _selectedProductType,
      selectedCategory: _selectedCategory,
      selectedSubCategory: 'All',
      akdMetalTypeOptions: _akdMetalTypeOptions,
      productTypeOptions: _availableProductTypes,
      categoryOptions: _availableCategories,
      subCategoryOptions: const ['All'],
      isLoadingAkdMetalTypes: _isLoadingAkdMetalTypes,
      isLoadingProductTypes: _isLoadingProductTypes,
      isLoadingCategories: _isLoadingCategories,
      isLoadingSubCategories: false,
      onMetalTypeChanged: _onMetalTypeChanged,
      onAkdMetalTypeChanged: _onAkdMetalTypeChanged,
      onProductTypeChanged: _onProductTypeChanged,
      onCategoryChanged: _onCategoryChanged,
      onSubCategoryChanged: _onSubCategoryChanged,
      onApplySelection: _loadProducts,
      availableMetalColors: _availableMetalColors,
      availableMetalPurities: _availableMetalPurities,
      availableStoneShapes: _availableStoneShapes,
      availableStoneTypes: _availableStoneTypes,
      availableStoneQualities: _availableStoneQualities,
      availableStoneSettings: _availableStoneSettings,
      availableFeaturedTags: _availableFeaturedTags,
      metalWeightBounds: _metalWeightBounds,
      stoneWeightBounds: _stoneWeightBounds,
      selectedJewelleryType: _selectedJewelleryType,
      selectedMetalColors: _selectedMetalColors,
      selectedMetalPurities: _selectedMetalPurities,
      isEnamelWorkChecked: _isEnamelWorkChecked,
      selectedStoneShapes: _selectedStoneShapes,
      selectedStoneTypes: _selectedStoneTypes,
      selectedStoneQualities: _selectedStoneQualities,
      selectedStoneSettings: _selectedStoneSettings,
      selectedFeaturedTags: _selectedFeaturedTags,
      currentMetalWeightRange: _currentMetalWeightRange,
      currentStoneWeightRange: _currentStoneWeightRange,
      isLoadingAdvancedOptions: _isLoadingAdvancedOptions,
      onJewelleryTypeChanged: _onJewelleryTypeChanged,
      onMetalWeightChanged: _onMetalWeightChanged,
      onMetalColorsChanged: _onMetalColorsChanged,
      onMetalPuritiesChanged: _onMetalPuritiesChanged,
      onEnamelWorkChanged: _onEnamelWorkChanged,
      onStoneWeightChanged: _onStoneWeightChanged,
      onStoneShapesChanged: _onStoneShapesChanged,
      onStoneTypesChanged: _onStoneTypesChanged,
      onStoneQualitiesChanged: _onStoneQualitiesChanged,
      onStoneSettingsChanged: _onStoneSettingsChanged,
      onFeaturedTagsChanged: _onFeaturedTagsChanged,
      onResetFilters: _resetFilters,
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
            child: Text(
              'Choose Your Style',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF006435),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_selectedMetalType != 'Instant') ...[
                  _buildMetalTypeButton('Gold', _selectedMetalType == 'Gold'),
                  const SizedBox(width: 6.0),
                  _buildMetalTypeButton(
                      'Silver', _selectedMetalType == 'Silver'),
                  const SizedBox(width: 6.0),
                ],
                _buildMetalTypeButton(
                    'Instant', _selectedMetalType == 'Instant'),
              ],
            ),
          ),
          if (_selectedMetalType == 'Instant')
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Text(
                        'Select Metal',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    _buildBubbleFilter(
                      options: _akdMetalTypeOptions,
                      selectedValue: _selectedAkdMetalType,
                      onChanged: _onAkdMetalTypeChanged,
                      isLoading: _isLoadingAkdMetalTypes,
                      labelBuilder: _displayMetalType,
                    ),
                  ],
                ),
              ),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0, -0.08),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic));
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child:
                _selectedMetalType != 'All' && _availableProductTypes.length > 1
                    ? Padding(
                        key: const ValueKey('productTypeBubbles'),
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _buildBubbleFilter(
                          options: _availableProductTypes,
                          selectedValue: _selectedProductType,
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
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('productTypeBubblesEmpty')),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0, -0.08),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic));
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child: _selectedMetalType != 'All' &&
                    _selectedProductType != 'All' &&
                    _availableCategories.length > 1
                ? Padding(
                    key: const ValueKey('categoryBubbles'),
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _buildBubbleFilter(
                      options: _availableCategories,
                      selectedValue: _selectedCategory,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                          _loadProducts();
                        }
                      },
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('categoryBubblesEmpty')),
          ),
          if (_selectedMetalType != 'Gold' ||
              _selectedProductType != 'All' ||
              _selectedCategory != 'All')
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: _buildResetButton(),
            ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return OutlinedButton.icon(
      onPressed: _resetFilters,
      icon: const Icon(Icons.clear, size: 12),
      label: const Text(
        'Back To Menu',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF424242),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        minimumSize: const Size(0, 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
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
                selectedItemBuilder: (BuildContext context) {
                  return items.map<Widget>((String item) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _displayMetalType(item),
                        style: const TextStyle(
                          color: Color(0xFF2F2F2F),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList();
                },
                items: items
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          _displayMetalType(item),
                          overflow: TextOverflow.ellipsis,
                        ),
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

  Widget _buildBubbleFilter({
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String?> onChanged,
    bool isLoading = false,
    String Function(String value)? labelBuilder,
  }) {
    if (isLoading) {
      return const SizedBox(
        height: 32,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Filter out 'All' from display
    final displayOptions = options.where((opt) => opt != 'All').toList();

    if (displayOptions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6.0,
      runSpacing: 6.0,
      children: displayOptions
          .map((option) => _buildBubbleChip(
                labelBuilder?.call(option) ?? option,
                selectedValue == option,
                () => onChanged(option),
              ))
          .toList(),
    );
  }

  Widget _buildBubbleChip(String label, bool isSelected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF006435) : Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF006435)
                  : const Color(0xFFE0E0E0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF006435).withOpacity(0.25)
                    : Colors.grey.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF424242),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 12,
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
                child: GlowingLogo(size: 40),
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

    // shareItem moved to _shareItem class method

    String formatCount(int? count) {
      final c = count ?? 0;
      if (c == 0) return '0';
      if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
      if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}K';
      return c.toString();
    }

    return GestureDetector(
      onTap: () {
        final isDesigner = item.isDesignerProduct;
        final isManufacturer = item.isManufacturerProduct;
        context.push(
            '/product/${item.uid ?? item.id}?isDesigner=$isDesigner&isManufacturer=${isManufacturer}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: AspectRatio(
                aspectRatio: item.aspectRatio,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => createBlurUpPlaceholder(),
                  errorWidget: (context, url, error) => Container(
                    color:
                        Theme.of(context).colorScheme.surface.withOpacity(0.1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported,
                            color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12),
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
            // Action bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 9.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ActionButton(
                    icon: Icon(
                      item.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: item.isFavorite
                          ? const Color(0xFFE53935)
                          : const Color(0xFF555555),
                      size: 16,
                    ),
                    label: formatCount(item.likes),
                    active: item.isFavorite,
                    onTap: () => _likeItem(item),
                  ),
                  const Spacer(),
                  _ActionButton(
                    icon: const Icon(Icons.ios_share_rounded,
                        color: Color(0xFF555555), size: 16),
                    onTap: () => _shareItem(item),
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: const Icon(Icons.bookmark_border_rounded,
                        color: Color(0xFF555555), size: 16),
                    onTap: _navigateToLogin,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact, pill-shaped action button for product cards
class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String? label;
  final VoidCallback? onTap;
  final bool active;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFF0F0) : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFFFFCDD2) : const Color(0xFFE8E8E8),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? const Color(0xFFE53935)
                      : const Color(0xFF555555),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
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
