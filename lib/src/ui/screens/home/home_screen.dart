import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/providers/boards_provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/services/filter_service.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/utils/share_utils.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:jewelry_nafisa/src/ui/widgets/save_to_board_dialog.dart';
import 'package:jewelry_nafisa/src/utils/image_url_resolver.dart';
import 'package:jewelry_nafisa/src/utils/product_type_icons.dart';
import 'package:jewelry_nafisa/src/widgets/blur_up_placeholder.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/scheduler.dart';
import 'package:jewelry_nafisa/src/widgets/floating_filter_panel.dart';
import 'package:jewelry_nafisa/src/widgets/glowing_logo.dart';
import 'package:jewelry_nafisa/src/ui/widgets/welcome_offer_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;
  late final JewelryService _jewelryService;

  // Filter state
  final FilterService _filterService = FilterService();
  List<JewelryItem> _products = [];
  bool _isLoadingFilters = true;
  bool _isLoadingProducts = true;
  bool _isLoadingProductTypes = false;
  bool _isLoadingCategories = false;
  bool _isLoadingSubCategories = false;

  // Pagination state
  static const int _pageSize = 50; // Load 50 products at a time
  int _currentOffset = 0;
  bool _hasMoreProducts = true;
  bool _isLoadingMore = false;

  // Filter options
  List<String> _metalTypeOptions = ['All', 'Gold', 'Silver', 'Platinum'];
  List<String> _productTypeOptions = ['All'];
  List<String> _categoryOptions = ['All'];
  List<String> _subCategoryOptions = ['All'];
  List<String> _metalPurity = ['All'];
  List<String> _plainOptions = [];
  List<String> _studdedOptions = [];

  // Selected filter values
  String _selectedMetalType = 'Gold';
  String _selectedAkdMetalType = 'All';
  String _selectedProductType = 'All';
  String _selectedCategory = 'All';
  String _selectedSubCategory = 'All';
  String _selectedMetalPurity = 'All';
  String? _selectedPlain;
  String? _selectedStudded;

  List<String> _akdMetalTypeOptions = ['All'];
  bool _isLoadingAkdMetalTypes = false;

  String? _hoveredItemId;
  String? _tappedItemId;
  final Set<String> _itemsBeingLiked = {};

  // Logo animation state
  double _scrollOffset = 0.0;
  static const double _logoAnimationThreshold = 100.0;

  // Onboarding delay timer
  Timer? _onboardingTimer;

  // Realtime channel for likes
  RealtimeChannel? _likesChannel;

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
  @override
  void initState() {
    super.initState();
    _jewelryService = JewelryService(_supabase);
    _loadInitialData();
    _loadAdvancedFilters();
    // Add scroll listener for infinite scroll and logo animation
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_onScrollForLogo);
    // Start 45-second onboarding delay for new users
    _startOnboardingDelayIfNeeded();
    _setupLikesListener();
  }

  void _setupLikesListener() {
    _likesChannel = _supabase.channel('public:likes_channel')
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
    }
  }

  @override
  void dispose() {
    _likesChannel?.unsubscribe();
    _onboardingTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.removeListener(_onScrollForLogo);
    _scrollController.dispose();
    super.dispose();
  }

  /// After 45 seconds, if the user hasn't completed onboarding, navigate them
  /// to the appropriate onboarding screen.
  void _startOnboardingDelayIfNeeded() {
    _onboardingTimer = Timer(const Duration(seconds: 45), () {
      if (!mounted) return;
      final provider = Provider.of<UserProfileProvider>(context, listen: false);
      final profile = provider.userProfile;
      // Only redirect if onboarding is genuinely incomplete
      if (profile == null || profile.isSetupComplete == true) return;

      final stage = profile.onboardingStage;
      final String route;
      if (stage == 0) {
        route = '/onboarding/location';
      } else if (stage == 1) {
        route = '/onboarding/gender';
      } else {
        route = '/onboarding/categories';
      }
      debugPrint(
          '⏰ 45s elapsed — showing welcome offer dialog for route: $route (stage $stage)');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WelcomeOfferDialog(
          onClaim: () {
            Navigator.of(context).pop();
            context.go(route);
          },
        ),
      );
    });
  }

  void _onScroll() {
    // Load more when user scrolls near the bottom (80% of the way)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMoreProducts && !_isLoadingProducts) {
        _loadMoreProducts();
      }
    }
  }

  void _onScrollForLogo() {
    final newOffset = _scrollController.position.pixels;
    if (_scrollOffset != newOffset) {
      setState(() {
        _scrollOffset = newOffset;
      });
    }
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
      if (_selectedSubCategory != 'All') {
        filters['Sub Category'] = _selectedSubCategory;
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
        _filterService.getDependentDistinctArrayValues('Stone Setting', filters),
        _filterService.getDependentDistinctArrayValues('Product Tags', filters),
        // Phase 1 added a real "Metal Weight" column (backfilled from "Gold Weight"),
        // so the Metal Weight slider now reads it directly instead of the old
        // "Net Weight" approximation. Both weight ranges narrow to whatever
        // Product Type/Category/Metal Type etc. are currently selected.
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

  void _onJewelleryTypeChanged(String? val) {
    setState(() => _selectedJewelleryType = val);
    _loadAdvancedFilters();
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

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingFilters = true;
      _isLoadingProducts = true;
      _isLoadingProductTypes = true;
    });
    try {
      // 1. Load Initial Filter Options
      // Metal Type is hardcoded, so we don't need to fetch it
      // Load all Product Types initially (when Metal Type is 'All')
      final allProductTypes =
          await _filterService.getDistinctValues('Product Type');

      // 2. Load Initial Products (with default filters) - First page only
      final productList =
          await _fetchFilteredProducts(offset: 0, limit: _pageSize);

      if (mounted) {
        setState(() {
          _productTypeOptions = ['All', ...allProductTypes];
          _products = productList;
          _currentOffset = productList.length;
          _hasMoreProducts = productList.length >= _pageSize;
          _isLoadingFilters = false;
          _isLoadingProducts = false;
          _isLoadingProductTypes = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoadingFilters = false;
          _isLoadingProducts = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<List<JewelryItem>> _fetchSilverProductsWithPattern(
      {int offset = 0, int limit = _pageSize}) async {
    if (mounted && offset == 0) {
      setState(() => _isLoadingProducts = true);
    }

    try {
      const selectColumns =
          'id, "Product Title", "Images", "Description", "Product Type", '
          '"Category", "Sub Category", '
          '"Metal Type", "Metal Purity", Plain, Studded, "Price", '
          '"Metal Color"';

      const designerSelectColumns = '$selectColumns, created_at';

      // Build queries for all three tables with LIKE pattern matching
      // Using .ilike() for case-insensitive pattern matching

      // Query 1: products table - Metal Type contains "Silver"
      dynamic productsQuery = _supabase
          .from('products')
          .select(selectColumns)
          .ilike('"Metal Type"', '%Silver%'); // Pattern matching for Silver

      // Query 2: designerproducts table - Metal Type contains "Silver"
      dynamic designerQuery = _supabase
          .from('designerproducts')
          .select(designerSelectColumns)
          .ilike('"Metal Type"', '%Silver%'); // Pattern matching for Silver

      // Query 3: manufacturerproducts table - Metal Type contains "Silver"
      dynamic manufacturerQuery = _supabase
          .from('manufacturerproducts')
          .select(designerSelectColumns)
          .ilike('"Metal Type"', '%Silver%'); // Pattern matching for Silver

      // Apply additional filters if needed
      if (_selectedProductType != 'All') {
        productsQuery =
            productsQuery.eq('"Product Type"', _selectedProductType);
        designerQuery =
            designerQuery.eq('"Product Type"', _selectedProductType);
        manufacturerQuery =
            manufacturerQuery.eq('"Product Type"', _selectedProductType);
      }

      if (_selectedCategory != 'All') {
        // "Category" is text[]: match by array overlap with the selection.
        productsQuery = productsQuery.overlaps('Category', [_selectedCategory]);
        designerQuery = designerQuery.overlaps('Category', [_selectedCategory]);
        manufacturerQuery =
            manufacturerQuery.overlaps('Category', [_selectedCategory]);
      }

      if (_selectedSubCategory != 'All') {
        productsQuery =
            productsQuery.eq('"Sub Category"', _selectedSubCategory);
        designerQuery =
            designerQuery.eq('"Sub Category"', _selectedSubCategory);
        manufacturerQuery =
            manufacturerQuery.eq('"Sub Category"', _selectedSubCategory);
      }

      if (_selectedMetalPurity != 'All') {
        productsQuery =
            productsQuery.eq('"Metal Purity"', _selectedMetalPurity);
        designerQuery =
            designerQuery.eq('"Metal Purity"', _selectedMetalPurity);
        manufacturerQuery =
            manufacturerQuery.eq('"Metal Purity"', _selectedMetalPurity);
      }

      if (_selectedPlain != null) {
        productsQuery = productsQuery.eq('Plain', _selectedPlain!);
        designerQuery = designerQuery.eq('Plain', _selectedPlain!);
        manufacturerQuery = manufacturerQuery.eq('Plain', _selectedPlain!);
      }

      if (_selectedStudded != null) {
        productsQuery =
            productsQuery.contains('Studded', ['$_selectedStudded']);
        designerQuery =
            designerQuery.contains('Studded', ['$_selectedStudded']);
        manufacturerQuery =
            manufacturerQuery.contains('Studded', ['$_selectedStudded']);
      }

      // Apply pagination
      productsQuery = productsQuery
          .order('id', ascending: false)
          .range(offset, offset + limit - 1);

      designerQuery = designerQuery
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      manufacturerQuery = manufacturerQuery
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      // Fetch from all three tables in parallel
      final responses = await Future.wait<dynamic>([
        productsQuery as Future<dynamic>,
        designerQuery as Future<dynamic>,
        manufacturerQuery as Future<dynamic>,
      ]);

      final List<JewelryItem> allItems = [];

      // Parse products table results
      if (responses[0] is List) {
        allItems.addAll(
          (responses[0] as List).map(
              (item) => JewelryItem.fromJson(item as Map<String, dynamic>)),
        );
      }

      // Parse designer products with flag
      if (responses[1] is List) {
        allItems.addAll(
          (responses[1] as List).map((item) {
            final map = item as Map<String, dynamic>;
            map['is_designer_product'] = true;
            return JewelryItem.fromJson(map);
          }),
        );
      }

      // Parse manufacturer products with flag
      if (responses[2] is List) {
        allItems.addAll(
          (responses[2] as List).map((item) {
            final map = item as Map<String, dynamic>;
            map['is_manufacturer_product'] = true;
            return JewelryItem.fromJson(map);
          }),
        );
      }

      // Shuffle only on first load
      if (offset == 0) {
        allItems.shuffle();
      }

      return allItems;
    } catch (e) {
      debugPrint('Error fetching silver products with pattern: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading silver products: $e')),
        );
      }
      return [];
    } finally {
      if (mounted && offset == 0) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  Future<List<JewelryItem>> _fetchFilteredProducts(
      {int offset = 0, int limit = _pageSize}) async {
    if (mounted && offset == 0) {
      setState(() => _isLoadingProducts = true);
    }
    try {
      const selectColumns =
          'id, "Product Title", "Images", "Description", "Product Type", '
          '"Category", "Sub Category", '
          '"Metal Type", "Metal Purity", Plain, Studded, "Price"';

      // For designerproducts, we can include created_at
      const designerSelectColumns = '$selectColumns, created_at';

      // Handle "Instant" separately
      if (_selectedMetalType == 'Instant') {
        return await _fetchInHouseProducts(offset: offset, limit: limit);
      }

      // Build query for 'products' table
      dynamic productsQuery = _supabase.from('products').select(selectColumns);

      // Build query for 'designerproducts' table (includes created_at)
      dynamic designerQuery =
          _supabase.from('designerproducts').select(designerSelectColumns);
      dynamic manufacturerQuery =
          _supabase.from('manufacturerproducts').select(designerSelectColumns);
      // Apply filters to both queries
      // Metal Type filter (first in hierarchy)
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
        // "Category" is text[]: match by array overlap with the selection.
        productsQuery = productsQuery.overlaps('Category', [_selectedCategory]);
        designerQuery = designerQuery.overlaps('Category', [_selectedCategory]);
        manufacturerQuery =
            manufacturerQuery.overlaps('Category', [_selectedCategory]);
      }
      if (_selectedSubCategory != 'All') {
        productsQuery =
            productsQuery.eq('"Sub Category"', _selectedSubCategory);
        designerQuery =
            designerQuery.eq('"Sub Category"', _selectedSubCategory);
        manufacturerQuery =
            manufacturerQuery.eq('"Sub Category"', _selectedSubCategory);
      }
      if (_selectedMetalPurity != 'All') {
        productsQuery =
            productsQuery.eq('"Metal Purity"', _selectedMetalPurity);
        designerQuery =
            designerQuery.eq('"Metal Purity"', _selectedMetalPurity);
        manufacturerQuery =
            manufacturerQuery.eq('"Metal Purity"', _selectedMetalPurity);
      }
      if (_selectedPlain != null) {
        productsQuery = productsQuery.eq('Plain', _selectedPlain!);
        designerQuery = designerQuery.eq('Plain', _selectedPlain!);
        manufacturerQuery = manufacturerQuery.eq('Plain', _selectedPlain!);
      }
      if (_selectedStudded != null) {
        productsQuery =
            productsQuery.overlaps('Studded', ['$_selectedStudded']);
        designerQuery =
            designerQuery.overlaps('Studded', ['$_selectedStudded']);
        manufacturerQuery =
            manufacturerQuery.overlaps('Studded', ['$_selectedStudded']);
      }

      // Advanced Filters
      if (_selectedJewelleryType == 'Plain') {
        productsQuery = productsQuery.not('Plain', 'is', 'null');
        designerQuery = designerQuery.not('Plain', 'is', 'null');
        manufacturerQuery = manufacturerQuery.not('Plain', 'is', 'null');
      } else if (_selectedJewelleryType == 'Studded') {
        productsQuery = productsQuery.not('Studded', 'is', 'null');
        designerQuery = designerQuery.not('Studded', 'is', 'null');
        manufacturerQuery = manufacturerQuery.not('Studded', 'is', 'null');
      }

      if (_selectedMetalColors.isNotEmpty) {
        // Match against the unified metal_color_arr (text[]) with OR/overlap
        // semantics, so 2-tone products (e.g. {Yellow Gold, Rose Gold}) match
        // if ANY selected color is present - same operator used for Product Tags.
        productsQuery =
            productsQuery.overlaps('Metal Color', _selectedMetalColors);
        designerQuery =
            designerQuery.overlaps('Metal Color', _selectedMetalColors);
        manufacturerQuery = manufacturerQuery.overlaps(
            'Metal Color', _selectedMetalColors);
      }
      if (_selectedMetalPurities.isNotEmpty) {
        productsQuery = productsQuery.inFilter('"Metal Purity"', _selectedMetalPurities);
        designerQuery = designerQuery.inFilter('"Metal Purity"', _selectedMetalPurities);
        manufacturerQuery = manufacturerQuery.inFilter('"Metal Purity"', _selectedMetalPurities);
      }
      if (_isEnamelWorkChecked) {
        productsQuery = productsQuery.not('"Enamel Work"', 'is', 'null');
        designerQuery = designerQuery.not('"Enamel Work"', 'is', 'null');
        manufacturerQuery = manufacturerQuery.not('"Enamel Work"', 'is', 'null');
      }
      if (_selectedStoneShapes.isNotEmpty) {
        productsQuery = productsQuery.overlaps('"Stone Cut"', _selectedStoneShapes);
        designerQuery = designerQuery.overlaps('"Stone Cut"', _selectedStoneShapes);
        manufacturerQuery = manufacturerQuery.overlaps('"Stone Cut"', _selectedStoneShapes);
      }
      if (_selectedStoneTypes.isNotEmpty) {
        productsQuery = productsQuery.overlaps('"Stone Type"', _selectedStoneTypes);
        designerQuery = designerQuery.overlaps('"Stone Type"', _selectedStoneTypes);
        manufacturerQuery = manufacturerQuery.overlaps('"Stone Type"', _selectedStoneTypes);
      }
      if (_selectedStoneQualities.isNotEmpty) {
        productsQuery = productsQuery.overlaps('"Stone Purity"', _selectedStoneQualities);
        designerQuery = designerQuery.overlaps('"Stone Purity"', _selectedStoneQualities);
        manufacturerQuery = manufacturerQuery.overlaps('"Stone Purity"', _selectedStoneQualities);
      }
      if (_selectedStoneSettings.isNotEmpty) {
        productsQuery = productsQuery.overlaps('"Stone Setting"', _selectedStoneSettings);
        designerQuery = designerQuery.overlaps('"Stone Setting"', _selectedStoneSettings);
        manufacturerQuery = manufacturerQuery.overlaps('"Stone Setting"', _selectedStoneSettings);
      }
      if (_selectedFeaturedTags.isNotEmpty) {
        productsQuery = productsQuery.overlaps('"Product Tags"', _selectedFeaturedTags);
        designerQuery = designerQuery.overlaps('"Product Tags"', _selectedFeaturedTags);
        manufacturerQuery = manufacturerQuery.overlaps('"Product Tags"', _selectedFeaturedTags);
      }

      // OPTIMIZED: Use pagination instead of loading all products
      // Note: 'products' table doesn't have 'created_at', so order by id instead
      productsQuery = productsQuery
          .order('id', ascending: false)
          .range(offset, offset + limit - 1);
      // 'designerproducts' table has 'created_at' column
      designerQuery = designerQuery
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      manufacturerQuery = manufacturerQuery
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      // Fetch from both tables in parallel
      final responses = await Future.wait<dynamic>([
        productsQuery as Future<dynamic>,
        designerQuery as Future<dynamic>,
        manufacturerQuery as Future<dynamic>,
      ]);

      final List<JewelryItem> allItems = [];

      // Parse products
      if (responses[0] is List) {
        allItems.addAll(
          (responses[0] as List).map(
              (item) => JewelryItem.fromJson(item as Map<String, dynamic>)),
        );
      }

      // Parse designer products with flag
      if (responses[1] is List) {
        allItems.addAll(
          (responses[1] as List).map((item) {
            final map = item as Map<String, dynamic>;
            map['is_designer_product'] = true;
            return JewelryItem.fromJson(map);
          }),
        );
      }

      // Parse manufacturer products with flag
      if (responses[2] is List) {
        allItems.addAll(
          (responses[2] as List).map((item) {
            final map = item as Map<String, dynamic>;
            map['is_manufacturer_product'] = true;
            return JewelryItem.fromJson(map);
          }),
        );
      }

      // Shuffle only on first load, keep order for pagination
      if (offset == 0) {
        allItems.shuffle();
      }

      return allItems;
    } catch (e) {
      debugPrint('Error fetching filtered products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
      return [];
    } finally {
      if (mounted && offset == 0) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  Future<List<JewelryItem>> _fetchInHouseProducts(
      {int offset = 0, int limit = _pageSize}) async {
    try {
      const selectColumns =
          'id, "Product Title", "Images", "Description", "Product Type", '
          '"Category", "Sub Category", '
          '"Metal Type", "Metal Purity", Plain, Studded, "Price", created_at, '
          '"Metal Color"';

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
          designerQuery =
              designerQuery.overlaps('Category', [_selectedCategory]);
        }
        if (_selectedSubCategory != 'All') {
          designerQuery =
              designerQuery.eq('"Sub Category"', _selectedSubCategory);
        }
        if (_selectedMetalPurity != 'All') {
          designerQuery =
              designerQuery.eq('"Metal Purity"', _selectedMetalPurity);
        }
        if (_selectedPlain != null) {
          designerQuery = designerQuery.eq('Plain', _selectedPlain!);
        }
        if (_selectedStudded != null) {
          designerQuery =
              designerQuery.contains('Studded', ['$_selectedStudded']);
        }
        var q = designerQuery;

        // Advanced Filters
        if (_selectedJewelleryType == 'Plain') {
          designerQuery = designerQuery.not('Plain', 'is', 'null');
        } else if (_selectedJewelleryType == 'Studded') {
          designerQuery = designerQuery.not('Studded', 'is', 'null');
        }

        if (_selectedMetalColors.isNotEmpty) {
          designerQuery =
              designerQuery.overlaps('Metal Color', _selectedMetalColors);
        }
        if (_selectedMetalPurities.isNotEmpty) {
          designerQuery =
              designerQuery.inFilter('"Metal Purity"', _selectedMetalPurities);
        }
        if (_isEnamelWorkChecked) {
          designerQuery = designerQuery.not('"Enamel Work"', 'is', 'null');
        }
        if (_selectedStoneShapes.isNotEmpty) {
          designerQuery =
              designerQuery.overlaps('"Stone Cut"', _selectedStoneShapes);
        }
        if (_selectedStoneTypes.isNotEmpty) {
          designerQuery =
              designerQuery.overlaps('"Stone Type"', _selectedStoneTypes);
        }
        if (_selectedStoneQualities.isNotEmpty) {
          designerQuery =
              designerQuery.overlaps('"Stone Purity"', _selectedStoneQualities);
        }
        if (_selectedStoneSettings.isNotEmpty) {
          designerQuery =
              designerQuery.overlaps('"Stone Setting"', _selectedStoneSettings);
        }
        if (_selectedFeaturedTags.isNotEmpty) {
          designerQuery =
              designerQuery.overlaps('"Product Tags"', _selectedFeaturedTags);
        }
        // Sliders (approximate matching could be added later, for now we skip strict SQL weight filtering due to string parsing limits in postgrest)

        final designerQueryPaged = designerQuery
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        designerData = await designerQueryPaged;
      } catch (e) {
        debugPrint('Error fetching designer products: $e');
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
          manufacturerQuery =
              manufacturerQuery.overlaps('Category', [_selectedCategory]);
        }
        if (_selectedSubCategory != 'All') {
          manufacturerQuery =
              manufacturerQuery.eq('"Sub Category"', _selectedSubCategory);
        }
        if (_selectedMetalPurity != 'All') {
          manufacturerQuery =
              manufacturerQuery.eq('"Metal Purity"', _selectedMetalPurity);
        }
        if (_selectedPlain != null) {
          manufacturerQuery = manufacturerQuery.eq('Plain', _selectedPlain!);
        }
        if (_selectedStudded != null) {
          manufacturerQuery =
              manufacturerQuery.contains('Studded', ['$_selectedStudded']);
        }
        var mq = manufacturerQuery;

        // Advanced Filters
        if (_selectedJewelleryType == 'Plain') {
          manufacturerQuery = manufacturerQuery.not('Plain', 'is', 'null');
        } else if (_selectedJewelleryType == 'Studded') {
          manufacturerQuery = manufacturerQuery.not('Studded', 'is', 'null');
        }

        if (_selectedMetalColors.isNotEmpty) {
          manufacturerQuery = manufacturerQuery.overlaps(
              'Metal Color', _selectedMetalColors);
        }
        if (_selectedMetalPurities.isNotEmpty) {
          manufacturerQuery = manufacturerQuery.inFilter(
              '"Metal Purity"', _selectedMetalPurities);
        }
        if (_isEnamelWorkChecked) {
          manufacturerQuery =
              manufacturerQuery.not('"Enamel Work"', 'is', 'null');
        }
        if (_selectedStoneShapes.isNotEmpty) {
          manufacturerQuery =
              manufacturerQuery.overlaps('"Stone Cut"', _selectedStoneShapes);
        }
        if (_selectedStoneTypes.isNotEmpty) {
          manufacturerQuery =
              manufacturerQuery.overlaps('"Stone Type"', _selectedStoneTypes);
        }
        if (_selectedStoneQualities.isNotEmpty) {
          manufacturerQuery = manufacturerQuery.overlaps(
              '"Stone Purity"', _selectedStoneQualities);
        }
        if (_selectedStoneSettings.isNotEmpty) {
          manufacturerQuery = manufacturerQuery.overlaps(
              '"Stone Setting"', _selectedStoneSettings);
        }
        if (_selectedFeaturedTags.isNotEmpty) {
          manufacturerQuery = manufacturerQuery.overlaps(
              '"Product Tags"', _selectedFeaturedTags);
        }
        // Sliders (approximate matching could be added later, for now we skip strict SQL weight filtering due to string parsing limits in postgrest)

        final manufacturerQueryPaged = manufacturerQuery
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        manufacturerData = await manufacturerQueryPaged;
      } catch (e) {
        debugPrint('Error fetching manufacturer products: $e');
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

      // Shuffle only on first load
      if (offset == 0) {
        allItems.shuffle();
      }

      return allItems;
    } catch (e) {
      debugPrint('Error loading Instant: $e');
      return [];
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMoreProducts) return;

    setState(() => _isLoadingMore = true);

    try {
      final newProducts = await _fetchFilteredProducts(
        offset: _currentOffset,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          if (newProducts.isEmpty) {
            _hasMoreProducts = false;
          } else {
            _products.addAll(newProducts);
            _currentOffset += newProducts.length;
            // If we got fewer products than requested, we've reached the end
            if (newProducts.length < _pageSize) {
              _hasMoreProducts = false;
            }
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more products: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  // This function just applies the filters and updates the product list
  Future<void> _applyFilters() async {
    // Reset pagination when filters change
    _currentOffset = 0;
    _hasMoreProducts = true;

    final productList =
        await _fetchFilteredProducts(offset: 0, limit: _pageSize);
    if (mounted) {
      setState(() {
        _products = productList;
        _currentOffset = productList.length;
        // If we got fewer products than page size, no more to load
        if (productList.length < _pageSize) {
          _hasMoreProducts = false;
        }
      });
    }
  }

  // Handlers for dependent dropdowns
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

  Future<List<String>> _fetchProductTypesForMetal(String metalType) async {
    try {
      final Set<String> allTypes = {};

      try {
        final query = _supabase.from('products').select('"Product Type"');
        final productsTypes = (metalType == 'AKD'
            ? await query.ilike('"Metal Type"', 'AKD%')
            : await query.eq('"Metal Type"', metalType)) as List;

        for (var item in productsTypes) {
          final productType = item['Product Type'] as String?;
          if (productType != null && productType.isNotEmpty) {
            allTypes.add(productType);
          }
        }
      } catch (e) {
        debugPrint('Error fetching product types from products: $e');
      }

      try {
        final query =
            _supabase.from('designerproducts').select('"Product Type"');
        final designerTypes = (metalType == 'AKD'
            ? await query.ilike('"Metal Type"', 'AKD%')
            : await query.eq('"Metal Type"', metalType)) as List;

        for (var item in designerTypes) {
          final productType = item['Product Type'] as String?;
          if (productType != null && productType.isNotEmpty) {
            allTypes.add(productType);
          }
        }
      } catch (e) {
        debugPrint('Error fetching designer product types: $e');
      }

      try {
        final query =
            _supabase.from('manufacturerproducts').select('"Product Type"');
        final manufacturerTypes = (metalType == 'AKD'
            ? await query.ilike('"Metal Type"', 'AKD%')
            : await query.eq('"Metal Type"', metalType)) as List;

        for (var item in manufacturerTypes) {
          final productType = item['Product Type'] as String?;
          if (productType != null && productType.isNotEmpty) {
            allTypes.add(productType);
          }
        }
      } catch (e) {
        debugPrint('Error fetching manufacturer product types: $e');
      }

      final types = allTypes.toList();
      types.sort();
      return types;
    } catch (e) {
      debugPrint('Error fetching product types for metal $metalType: $e');
      return [];
    }
  }

  Future<void> _loadAkdMetalTypes() async {
    setState(() {
      _isLoadingAkdMetalTypes = true;
      _akdMetalTypeOptions = ['All'];
    });
    try {
      final Set<String> akdTypes = {};

      // Query designerproducts table
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

      // Query manufacturerproducts table
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

      // Convert back and sort
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
      _selectedSubCategory = 'All';
      _selectedMetalPurity = 'All';
      _productTypeOptions = ['All'];
      _categoryOptions = ['All'];
      _subCategoryOptions = ['All'];
      _metalPurity = ['All'];
      _isLoadingProductTypes = true;
    });

    final effectiveMetal = _effectiveMetalTypeForFilters('Instant');
    final newProductTypes = await _fetchProductTypesForMetal(effectiveMetal!);

    if (mounted) {
      setState(() {
        _productTypeOptions = ['All', ...newProductTypes];
        _isLoadingProductTypes = false;
      });
    }
    _applyFilters();
  }

  /// Called when "Metal Type" filter changes
  Future<void> _onMetalTypeChanged(String value,
      {bool applyImmediately = true}) async {
    setState(() {
      _selectedMetalType = value;
      _selectedAkdMetalType = 'All';
      // Reset all dependent filters
      _selectedProductType = 'All';
      _selectedCategory = 'All';
      _selectedSubCategory = 'All';
      _selectedMetalPurity = 'All';
      // Clear options and show loading
      _productTypeOptions = ['All'];
      _akdMetalTypeOptions = ['All'];
      _categoryOptions = ['All'];
      _subCategoryOptions = ['All'];
      _metalPurity = ['All'];
      _isLoadingProductTypes = true;
    });

    if (value == 'Instant') {
      await _loadAkdMetalTypes();
    }

    // Fetch Product Types based on Metal Type
    List<String> newProductTypes;
    final effectiveMetal = _effectiveMetalTypeForFilters(value);
    if (value == 'All' || effectiveMetal == null) {
      // If Metal Type is 'All', get all Product Types
      newProductTypes = await _filterService.getDistinctValues('Product Type');
    } else {
      newProductTypes = await _fetchProductTypesForMetal(effectiveMetal);
    }

    if (mounted) {
      setState(() {
        _productTypeOptions = ['All', ...newProductTypes];
        _isLoadingProductTypes = false;
      });
    }
    _loadAdvancedFilters();
    if (applyImmediately) {
      // Refetch products
      _applyFilters();
    }
  }

  /// Called when "Product Type" dropdown changes
  Future<void> _onProductTypeChanged(String? value,
      {bool applyImmediately = true}) async {
    if (value == null) return;

    setState(() {
      _selectedProductType = value;
      // Reset dependent filters
      _selectedCategory = 'All';
      _selectedSubCategory = 'All';
      _selectedMetalPurity = 'All';
      // Clear options and show loading
      _categoryOptions = ['All'];
      _subCategoryOptions = ['All'];
      _metalPurity = ['All'];
      _isLoadingCategories = true;
    });

    // Build filters including Metal Type if selected
    final filters = <String, String?>{};
    final effectiveMetal = _effectiveMetalTypeForFilters(_selectedMetalType);
    if (effectiveMetal != null) {
      filters['Metal Type'] = effectiveMetal;
    }
    filters['Product Type'] = value;

    final newCategories =
        await _filterService.getDependentDistinctValues('Category', filters);

    if (mounted) {
      setState(() {
        _categoryOptions = ['All', ...newCategories];
        _isLoadingCategories = false;
      });
    }
    _loadAdvancedFilters();
    if (applyImmediately) {
      // Refetch products
      _applyFilters();
    }
  }

  /// Called when "Category" dropdown changes
  Future<void> _onCategoryChanged(String? value,
      {bool applyImmediately = true}) async {
    if (value == null) return;

    setState(() {
      _selectedCategory = value;
      // Reset dependent filter
      _selectedSubCategory = 'All';
      // Clear options and show loading
      _subCategoryOptions = ['All'];
      _isLoadingSubCategories = true;
    });

    // Fetch new options for 'Sub Category'
    final filters = <String, String?>{};
    final effectiveMetal = _effectiveMetalTypeForFilters(_selectedMetalType);
    if (effectiveMetal != null) {
      filters['Metal Type'] = effectiveMetal;
    }
    if (_selectedProductType != 'All') {
      filters['Product Type'] = _selectedProductType;
    }
    filters['Category'] = value;

    final newSubCategories = await _filterService.getDependentDistinctValues(
        'Sub Category', filters);

    if (mounted) {
      setState(() {
        _subCategoryOptions = ['All', ...newSubCategories];
        _isLoadingSubCategories = false;
      });
    }
    _loadAdvancedFilters();
    if (applyImmediately) {
      // Refetch products
      _applyFilters();
    }
  }

  /// Called when "Sub Category" dropdown changes
  void _onSubCategoryChanged(String? value, {bool applyImmediately = true}) {
    if (value == null) return;
    setState(() {
      _selectedSubCategory = value;
    });
    _loadAdvancedFilters();
    if (applyImmediately) {
      // Just refetch products, no new options to load
      _applyFilters();
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedMetalType = 'All';
      _selectedAkdMetalType = 'All';
      _selectedProductType = 'All';
      _selectedCategory = 'All';
      _selectedSubCategory = 'All';
      _selectedMetalPurity = 'All';
      _selectedPlain = null;
      _selectedStudded = null;
      _selectedJewelleryType = null;
      _selectedMetalColors = [];
      _selectedMetalPurities = [];
      _isEnamelWorkChecked = false;
      _selectedStoneShapes = [];
      _selectedStoneTypes = [];
      _selectedStoneQualities = [];
      _selectedStoneSettings = [];
      _selectedFeaturedTags = [];
      _currentMetalWeightRange = null;
      _currentStoneWeightRange = null;

      // Reset option lists to default
      _productTypeOptions = ['All'];
      _akdMetalTypeOptions = ['All'];
      _categoryOptions = ['All'];
      _subCategoryOptions = ['All'];
    });
    _loadAdvancedFilters();
    _applyFilters();
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
      }
    } catch (e) {
      debugPrint("Error toggling like on home screen: $e");
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

  void _saveToBoard(JewelryItem item) {
    if (_supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to save items.")),
      );
      return;
    }
    Provider.of<BoardsProvider>(context, listen: false).fetchBoards().then((_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => SaveToBoardDialog(item: item),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FloatingFilterOverlay(
        config: FloatingFilterConfig(
          selectedMetalType: _selectedMetalType,
          selectedAkdMetalType: _selectedAkdMetalType,
          selectedProductType: _selectedProductType,
          selectedCategory: _selectedCategory,
          selectedSubCategory: _selectedSubCategory,
          akdMetalTypeOptions: _akdMetalTypeOptions,
          productTypeOptions: _productTypeOptions,
          categoryOptions: _categoryOptions,
          subCategoryOptions: _subCategoryOptions,
          isLoadingAkdMetalTypes: _isLoadingAkdMetalTypes,
          isLoadingProductTypes: _isLoadingProductTypes,
          isLoadingCategories: _isLoadingCategories,
          isLoadingSubCategories: _isLoadingSubCategories,
          onMetalTypeChanged: _onMetalTypeChanged,
          onAkdMetalTypeChanged: _onAkdMetalTypeChanged,
          onProductTypeChanged: _onProductTypeChanged,
          onCategoryChanged: _onCategoryChanged,
          onSubCategoryChanged: _onSubCategoryChanged,
          onApplySelection: _applyFilters,
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
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            _currentOffset = 0;
            _hasMoreProducts = true;
            await _loadInitialData();
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildAnimatedLogo()),
              SliverToBoxAdapter(child: _buildFilterBar()),
              if (_isLoadingProducts)
                SliverFillRemaining(
                  child: Center(child: GlowingLogo(size: 80)),
                )
              else if (_products.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('Coming Soon')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(8.0),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: (MediaQuery.of(context).size.width / 200)
                        .floor()
                        .clamp(2, 6),
                    mainAxisSpacing: 8.0,
                    crossAxisSpacing: 8.0,
                    childCount: _products.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _products.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(child: GlowingLogo(size: 40)),
                        );
                      }
                      return _buildImageCard(context, _products[index]);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    // Calculate animation values based on scroll offset
    // Logo starts shrinking and fading after scrolling 100px
    final animationProgress =
        (_scrollOffset / _logoAnimationThreshold).clamp(0.0, 1.0);

    // Scale: starts at 1.0, goes to 0.0 (completely shrinks)
    final scale = 1.0 - animationProgress;

    // Opacity: starts at 1.0, goes to 0.0 (completely fades)
    final opacity = 1.0 - animationProgress;

    // Height: starts at 120, goes to 0
    final height = 120.0 * (1.0 - animationProgress);

    // Hide completely when scrolled past threshold
    if (height < 1.0) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      width: double.infinity,
      height: height,
      color: Colors.white,
      padding: EdgeInsets.only(top: 16.0 * (1.0 - animationProgress)),
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Image.asset(
            'assets/icons/dagina2.png',
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    if (_isLoadingFilters) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Center(child: LinearProgressIndicator()),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Heading - compact
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

          // Metal Type Filter - Compact buttons
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

          // AKD Metal Type Filter (only visible when Get it is selected)
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
                    _buildDropdownFilter(
                      hint: 'Metal Type',
                      options: _akdMetalTypeOptions,
                      selectedValue: _selectedAkdMetalType,
                      onChanged: _onAkdMetalTypeChanged,
                      isLoading: _isLoadingAkdMetalTypes,
                    ),
                  ],
                ),
              ),
            ),

          // Product Type Filter - Show for all metal types (Gold, Silver, In-house)
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
            child: _selectedMetalType != 'All' && _productTypeOptions.length > 1
                ? Padding(
                    key: const ValueKey('homeProductTypeFilter'),
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Center(
                      child: _selectedMetalType == 'Instant'
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    'Product Type',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                _buildBubbleFilter(
                                  options: _productTypeOptions,
                                  selectedValue: _selectedProductType,
                                  onChanged: _onProductTypeChanged,
                                  isLoading: _isLoadingProductTypes,
                                ),
                              ],
                            )
                          : _buildDropdownFilter(
                              hint: 'Product Type',
                              options: _productTypeOptions,
                              selectedValue: _selectedProductType,
                              onChanged: _onProductTypeChanged,
                              isLoading: _isLoadingProductTypes,
                            ),
                    ),
                  )
                : const SizedBox.shrink(
                    key: ValueKey('homeProductTypeFilterEmpty')),
          ),

          // Category Filter - Bubble chips
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
            child: _categoryOptions.length > 1 && _selectedProductType != 'All'
                ? Padding(
                    key: const ValueKey('homeCategoryFilter'),
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildBubbleFilter(
                      options: _categoryOptions,
                      selectedValue: _selectedCategory,
                      onChanged: _onCategoryChanged,
                      isLoading: _isLoadingCategories,
                    ),
                  )
                : const SizedBox.shrink(
                    key: ValueKey('homeCategoryFilterEmpty')),
          ),

          // Sub Category Filter - Bubble chips
          if (_subCategoryOptions.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildBubbleFilter(
                options: _subCategoryOptions,
                selectedValue: _selectedSubCategory,
                onChanged: _onSubCategoryChanged,
                isLoading: _isLoadingSubCategories,
              ),
            ),

          // Reset button - compact
          if (_selectedMetalType != 'All' ||
              _selectedProductType != 'All' ||
              _selectedCategory != 'All' ||
              _selectedSubCategory != 'All' ||
              _selectedMetalPurity != 'All' ||
              _selectedPlain != null ||
              _selectedStudded != null)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: _buildResetButton(),
            ),
        ],
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
        case 'Platinum':
          decoration = BoxDecoration(
            color: const Color(0xFFD3D3D3),
            borderRadius: BorderRadius.circular(18.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD3D3D3).withOpacity(0.25),
                blurRadius: 3,
                offset: const Offset(0, 1.5),
              ),
            ],
          );
          break;
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

  Widget _buildBubbleFilter({
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String?> onChanged,
    bool isLoading = false,
  }) {
    if (isLoading) {
      return const SizedBox(
        height: 32,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Filter out 'All' from display completely
    final displayOptions = options.where((opt) => opt != 'All').toList();

    if (displayOptions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6.0,
      runSpacing: 6.0,
      children: displayOptions
          .map((option) => _buildBubbleChip(
                option,
                selectedValue == option,
                () => onChanged(option),
              ))
          .toList(),
    );
  }

  Widget _buildBubbleChip(String label, bool isSelected, VoidCallback onTap) {
    // Shared lookup (see utils/product_type_icons.dart); null (e.g. for
    // category/subcategory options) renders the chip without an icon.
    final iconPath = productTypeIconAsset(label);
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconPath != null) ...[
                Image.asset(
                  iconPath,
                  width: 18,
                  height: 18,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF424242),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String hint,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
    bool isLoading = false,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (options.length <= 1 && hint != 'Product Type')
      return const SizedBox.shrink();

    final displayOptions =
        (options.contains('All') ? options : ['All', ...options])
            .toSet()
            .toList();

    final currentSelection =
        (selectedValue == null || !displayOptions.contains(selectedValue))
            ? 'All'
            : selectedValue;

    // Check if desktop view
    final isDesktop = MediaQuery.of(context).size.width > 700;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: isDesktop ? 320 : double.infinity,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        margin: isDesktop
            ? const EdgeInsets.symmetric(horizontal: 0)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28.0),
          border: Border.all(
            color: const Color(0xFFD8D8D8),
            width: 1.2,
          ),
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
            value: currentSelection,
            onChanged: onChanged,
            isExpanded: true,
            borderRadius: BorderRadius.circular(20),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade700,
              size: 20,
            ),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: Colors.white,
            selectedItemBuilder: (BuildContext context) {
              return displayOptions.map<Widget>((String item) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: _dropdownOptionLabel(
                    item,
                    const TextStyle(
                      color: Color(0xFF2F2F2F),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList();
            },
            items: displayOptions.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: _dropdownOptionLabel(
                  value,
                  const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Dropdown option label with the golden product-type icon when one exists
  // (see utils/product_type_icons.dart); non-product options (e.g. metal
  // types, "All") simply have no match and render as plain text.
  Widget _dropdownOptionLabel(String value, TextStyle style) {
    final label = value.replaceAll('AKD-', '');
    final iconPath = productTypeIconAsset(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconPath != null) ...[
          Image.asset(
            iconPath,
            width: 18,
            height: 18,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis, style: style),
        ),
      ],
    );
  }

  Widget _buildChoiceChipFilter({
    required String label,
    required List<String> options,
    required String? selectedOption,
    required Function(String?) onSelected,
  }) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10.0,
      runSpacing: 10.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ...options.map((option) {
          final isSelected = selectedOption == option;
          return FilterChip(
            label: Text(
              option,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF424242),
              ),
            ),
            selected: isSelected,
            onSelected: (selected) {
              onSelected(selected ? option : null);
            },
            selectedColor: const Color(0xFF006435),
            backgroundColor: Colors.white,
            checkmarkColor: Colors.white,
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF006435)
                  : const Color(0xFFE0E0E0),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          );
        }).toList(),
      ],
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

  Widget _buildImageCard(BuildContext context, JewelryItem item) {
    final bool isTapped = _tappedItemId == item.id;
    final userProfile = context.watch<UserProfileProvider>();
    final isMember = userProfile.isMember;
    final isLiking = _itemsBeingLiked.contains(item.id);
    final imageUrl = resolveImageUrl(item.image);

    String formatCount(int? count) {
      final c = count ?? 0;
      if (c == 0) return '0';
      if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
      if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}K';
      return c.toString();
    }

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
      onLongPress: () => setState(() => _tappedItemId = item.id),
      onTap: () {
        if (isTapped) {
          setState(() => _tappedItemId = null);
        } else {
          final isDesigner = item.isDesignerProduct;
          final isManufacturer = item.isManufacturerProduct;
          context.push(
              '/product/${item.uid ?? item.id}?isDesigner=$isDesigner&isManufacturer=$isManufacturer');
        }
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
                  cacheKey: imageUrl,
                  memCacheWidth: 600,
                  memCacheHeight: 900,
                  maxWidthDiskCache: 800,
                  maxHeightDiskCache: 1200,
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
                  // Like button + count
                  _ActionButton(
                    icon: isLiking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Color(0xFF555555),
                            ),
                          )
                        : Icon(
                            item.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: item.isFavorite
                                ? const Color(0xFFE53935)
                                : const Color(0xFF555555),
                            size: 16,
                          ),
                    label: formatCount(item.likes),
                    onTap: () => _likeItem(item),
                    active: item.isFavorite,
                  ),
                  const Spacer(),
                  // Share button
                  _ActionButton(
                    icon: const Icon(Icons.ios_share_rounded,
                        color: Color(0xFF555555), size: 16),
                    onTap: () => _shareItem(item),
                  ),
                  const SizedBox(width: 6),
                  // Save button
                  _ActionButton(
                    icon: const Icon(Icons.bookmark_border_rounded,
                        color: Color(0xFF555555), size: 16),
                    onTap: () => _saveToBoard(item),
                  ),
                ],
              ),
            ),
            if (isMember) ...[
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                child: Text(
                  item.productTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333),
                    letterSpacing: 0.1,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _scheduleHoverUpdate(String? itemId) {
    if (!mounted || _hoveredItemId == itemId) return;

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      setState(() => _hoveredItemId = itemId);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hoveredItemId == itemId) return;
      setState(() => _hoveredItemId = itemId);
    });
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
