import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/providers/boards_provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/services/filter_service.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:jewelry_nafisa/src/ui/widgets/save_to_board_dialog.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  String _selectedMetalType = 'All';
  String _selectedProductType = 'All';
  String _selectedCategory = 'All';
  String _selectedSubCategory = 'All';
  String _selectedMetalPurity = 'All';
  String? _selectedPlain;
  String? _selectedStudded;

  String? _hoveredItemId;
  String? _tappedItemId;
  final Set<String> _itemsBeingLiked = {};

  @override
  void initState() {
    super.initState();
    _jewelryService = JewelryService(_supabase);
    _loadInitialData();
    // Add scroll listener for infinite scroll
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
      final allProductTypes = await _filterService.getDistinctValues('Product Type');
      
      // 2. Load Initial Products (with default filters) - First page only
      final productList = await _fetchFilteredProducts(offset: 0, limit: _pageSize);

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

  Future<List<JewelryItem>> _fetchFilteredProducts({int offset = 0, int limit = _pageSize}) async {
    if (mounted && offset == 0) {
      setState(() => _isLoadingProducts = true);
    }
    try {
      // OPTIMIZED: Select only essential columns for list view
      // This reduces data transfer significantly
      // Note: 'products' table doesn't have 'created_at' or 'aspect_ratio'
      // Note: 'designerproducts' table has 'created_at' but not 'aspect_ratio'
      // The model will default aspectRatio to 1.0 if not present
      const selectColumns = 'id, "Product Title", Image, Description, "Product Type", '
          'Category, Category1, Category2, Category3, "Sub Category", '
          '"Metal Type", "Metal Purity", Plain, Studded';
      
      // For designerproducts, we can include created_at
      const designerSelectColumns = '$selectColumns, created_at';
      
      // Build query for 'products' table
      dynamic productsQuery = _supabase
          .from('products')
          .select(selectColumns);
      
      // Build query for 'designerproducts' table (includes created_at)
      dynamic designerQuery = _supabase
          .from('designerproducts')
          .select(designerSelectColumns);

      // Apply filters to both queries
      // Metal Type filter (first in hierarchy)
      if (_selectedMetalType != 'All') {
        productsQuery = productsQuery.eq('"Metal Type"', _selectedMetalType);
        designerQuery = designerQuery.eq('"Metal Type"', _selectedMetalType);
      }
      if (_selectedProductType != 'All') {
        productsQuery = productsQuery.eq('Product Type', _selectedProductType);
        designerQuery = designerQuery.eq('Product Type', _selectedProductType);
      }
      if (_selectedCategory != 'All') {
        // Filter by Category OR Category1 OR Category2 OR Category3 for both tables
        final categoryFilter = 'Category.eq.$_selectedCategory,Category1.eq.$_selectedCategory,Category2.eq.$_selectedCategory,Category3.eq.$_selectedCategory';
        productsQuery = productsQuery.or(categoryFilter);
        designerQuery = designerQuery.or(categoryFilter);
      }
      if (_selectedSubCategory != 'All') {
        productsQuery = productsQuery.eq('"Sub Category"', _selectedSubCategory);
        designerQuery = designerQuery.eq('"Sub Category"', _selectedSubCategory);
      }
      if (_selectedMetalPurity != 'All') {
        productsQuery = productsQuery.eq('Metal Purity', _selectedMetalPurity);
        designerQuery = designerQuery.eq('Metal Purity', _selectedMetalPurity);
      }
      if (_selectedPlain != null) {
        productsQuery = productsQuery.eq('Plain', _selectedPlain!);
        designerQuery = designerQuery.eq('Plain', _selectedPlain!);
      }
      if (_selectedStudded != null) {
        productsQuery = productsQuery.contains('Studded', ['$_selectedStudded']);
        designerQuery = designerQuery.contains('Studded', ['$_selectedStudded']);
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
      
      // Fetch from both tables in parallel
      final responses = await Future.wait<dynamic>([
        productsQuery as Future<dynamic>,
        designerQuery as Future<dynamic>,
      ]);

      final List<JewelryItem> allItems = [];

      // Parse products
      if (responses[0] is List) {
        allItems.addAll(
          (responses[0] as List).map((item) => 
            JewelryItem.fromJson(item as Map<String, dynamic>)
          ),
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
    
    final productList = await _fetchFilteredProducts(offset: 0, limit: _pageSize);
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

  /// Called when "Metal Type" filter changes
  Future<void> _onMetalTypeChanged(String value) async {
    setState(() {
      _selectedMetalType = value;
      // Reset all dependent filters
      _selectedProductType = 'All';
      _selectedCategory = 'All';
      _selectedSubCategory = 'All';
      _selectedMetalPurity = 'All';
      // Clear options and show loading
      _productTypeOptions = ['All'];
      _categoryOptions = ['All'];
      _subCategoryOptions = ['All'];
      _metalPurity = ['All'];
      _isLoadingProductTypes = true;
    });

    // Fetch Product Types based on Metal Type
    List<String> newProductTypes;
    if (value == 'All') {
      // If Metal Type is 'All', get all Product Types
      newProductTypes = await _filterService.getDistinctValues('Product Type');
    } else {
      // Otherwise, get Product Types filtered by Metal Type
      final filters = {'Metal Type': value};
      newProductTypes =
          await _filterService.getDependentDistinctValues('Product Type', filters);
    }

    if (mounted) {
      setState(() {
        _productTypeOptions = ['All', ...newProductTypes];
        _isLoadingProductTypes = false;
      });
    }
    // Refetch products
    _applyFilters();
  }

  /// Called when "Product Type" dropdown changes
  Future<void> _onProductTypeChanged(String? value) async {
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
    if (_selectedMetalType != 'All') {
      filters['Metal Type'] = _selectedMetalType;
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
    // Refetch products
    _applyFilters();
  }

  /// Called when "Category" dropdown changes
  Future<void> _onCategoryChanged(String? value) async {
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
    if (_selectedMetalType != 'All') {
      filters['Metal Type'] = _selectedMetalType;
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
    // Refetch products
    _applyFilters();
  }

  /// Called when "Sub Category" dropdown changes
  void _onSubCategoryChanged(String? value) {
    if (value == null) return;
    setState(() {
      _selectedSubCategory = value;
    });
    // Just refetch products, no new options to load
    _applyFilters();
  }

  void _resetFilters() {
    setState(() {
      _selectedMetalType = 'All';
      _selectedProductType = 'All';
      _selectedCategory = 'All';
      _selectedSubCategory = 'All';
      _selectedPlain = null;
      _selectedStudded = null;

      // Reset option lists to default
      _productTypeOptions = ['All'];
      _categoryOptions = ['All'];
      _subCategoryOptions = ['All'];
    });
    _applyFilters();
  }

  Future<void> _likeItem(JewelryItem item) async {
    if (_itemsBeingLiked.contains(item.id)) return;

    setState(() {
      _itemsBeingLiked.add(item.id);
    });

    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to like items.")),
      );
      setState(() => _itemsBeingLiked.remove(item.id));
      return;
    }

    try {
      final pinData = await _supabase
          .from('pins')
          .select('id')
          .eq('image_url', item.image)
          .maybeSingle();

      String pinId;
      if (pinData != null) {
        pinId = pinData['id'];
      } else {
        final newPin = await _supabase
            .from('pins')
            .insert({
              'owner_id': uid,
              'title': item.productTitle,
              'image_url': item.image,
              'description': item.description,
            })
            .select('id')
            .single();
        pinId = newPin['id'];
      }

      if (item.isFavorite) {
        await _supabase
            .from('user_likes')
            .delete()
            .match({'user_id': uid, 'pin_id': pinId});
        await _supabase.rpc('increment_like_count',
            params: {'pin_id_to_update': pinId, 'delta': -1});
      } else {
        await _supabase
            .from('user_likes')
            .insert({'user_id': uid, 'pin_id': pinId});
        await _supabase.rpc('increment_like_count',
            params: {'pin_id_to_update': pinId, 'delta': 1});
      }

      if (mounted) {
        final productIndex = _products.indexWhere((i) => i.id == item.id);
        if (productIndex != -1) {
          setState(() => _products[productIndex].isFavorite =
              !_products[productIndex].isFavorite);
        }
      }
    } catch (e) {
      debugPrint("Error toggling like on home screen: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not update like status.")),
      );
    } finally {
      if (mounted) {
        setState(() => _itemsBeingLiked.remove(item.id));
      }
    }
  }

  void _shareItem(JewelryItem item) {
    Share.share(
        'Check out this beautiful ${item.productTitle} from jewelry_nafisa!');
  }

  void _saveToBoard(JewelryItem item) {
    Provider.of<BoardsProvider>(context, listen: false).fetchBoards().then((_) {
      showDialog(
        context: context,
        builder: (context) => SaveToBoardDialog(item: item),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoadingProducts
                ? const Center(child: CircularProgressIndicator())
                : _buildHomeGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeGrid() {
    return RefreshIndicator(
      onRefresh: () async {
        // Reset pagination on refresh
        _currentOffset = 0;
        _hasMoreProducts = true;
        await _loadInitialData();
      },
      child: _products.isEmpty && !_isLoadingProducts
          ? const Center(child: Text('No products found matching your filters.'))
          : MasonryGridView.count(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              crossAxisCount:
                  (MediaQuery.of(context).size.width / 200).floor().clamp(2, 6),
              itemCount: _products.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                // Show loading indicator at the bottom when loading more
                if (index == _products.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _buildImageCard(context, _products[index]);
              },
              mainAxisSpacing: 8.0,
              crossAxisSpacing: 8.0,
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
                _buildMetalTypeButton('Gold', _selectedMetalType == 'Gold'),
                const SizedBox(width: 6.0),
                _buildMetalTypeButton('Silver', _selectedMetalType == 'Silver'),
                const SizedBox(width: 6.0),
                _buildMetalTypeButton('Platinum', _selectedMetalType == 'Platinum'),
              ],
            ),
          ),
          
          // Product Type Filter - Bubble chips
          if (_productTypeOptions.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildBubbleFilter(
                options: _productTypeOptions,
                selectedValue: _selectedProductType,
                onChanged: _onProductTypeChanged,
                isLoading: _isLoadingProductTypes,
              ),
            ),
          
          // Category Filter - Bubble chips
          if (_categoryOptions.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildBubbleFilter(
                options: _categoryOptions,
                selectedValue: _selectedCategory,
                onChanged: _onCategoryChanged,
                isLoading: _isLoadingCategories,
              ),
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
            metalType,
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
      children: displayOptions.map((option) => _buildBubbleChip(
        option,
        selectedValue == option,
        () => onChanged(option),
      )).toList(),
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
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF006435).withOpacity(0.15),
                      blurRadius: 3,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
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

  Widget _buildDropdownFilter({
    required String hint,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
    bool isLoading = false,
  }) {
    // Show loading indicator if this specific dropdown is loading
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            )),
      );
    }

    // Don't build a dropdown if there are no options (besides 'All')
    if (options.length <= 1 && hint != 'Product Type')
      return const SizedBox.shrink();

    // Ensure 'All' is always an option and selected if value is null
    final displayOptions =
        (options.contains('All') ? options : ['All', ...options])
            .toSet() // Remove duplicates
            .toList();

    final currentSelection =
        (selectedValue == null || !displayOptions.contains(selectedValue))
            ? 'All'
            : selectedValue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1.5,
        ),
      ),
      child: DropdownButton<String>(
        hint: Text(
          hint,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 15,
          ),
        ),
        value: currentSelection,
        onChanged: onChanged,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: Colors.grey.shade600,
          size: 20,
        ),
        iconSize: 20,
        style: const TextStyle(
          color: Color(0xFF212121),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        dropdownColor: Colors.white,
        items: displayOptions.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                value,
                style: TextStyle(
                  color: value == 'All' 
                      ? Colors.grey.shade600 
                      : const Color(0xFF212121),
                  fontSize: 15,
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
        'Reset',
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
    final bool isHovered = _hoveredItemId == item.id;
    final bool isTapped = _tappedItemId == item.id;
    final userProfile = context.watch<UserProfileProvider>();
    final isMember = userProfile.isMember;
    final isLiking = _itemsBeingLiked.contains(item.id);

    return GestureDetector(
      onLongPress: () => setState(() => _tappedItemId = item.id),
      onTap: () {
        if (isTapped) {
          setState(() => _tappedItemId = null);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => JewelryDetailScreen(jewelryItem: item),
            ),
          );
        }
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoveredItemId = item.id),
          onExit: (_) => setState(() => _hoveredItemId = null),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // OPTIMIZED: Use CachedNetworkImage for better performance and caching
              CachedNetworkImage(
                imageUrl: item.image,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.error_outline,
                  color: Colors.grey,
                ),
                // Cache images for 7 days
                cacheKey: item.image,
                maxWidthDiskCache: 800, // Limit cached image size
                maxHeightDiskCache: 1200,
              ),
              if (isHovered || isTapped)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha((255 * 0.7).round()),
                        Colors.transparent
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (isMember)
                          Expanded(
                            child: Text(
                              item.productTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (!isMember)
                          const Spacer(), // Takes up space if not member
                        Row(
                          mainAxisSize:
                              MainAxisSize.min, // Keep buttons compact
                          children: [
                            IconButton(
                              icon: isLiking
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      item.isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: item.isFavorite
                                          ? Colors.red
                                          : Colors.white,
                                    ),
                              onPressed: () => _likeItem(item),
                              tooltip: 'Like',
                              iconSize: 20, // Adjust size
                              padding: EdgeInsets.zero, // Reduce padding
                              constraints:
                                  const BoxConstraints(), // Remove extra constraints
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.share, color: Colors.white),
                              onPressed: () => _shareItem(item),
                              tooltip: 'Share',
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.bookmark_border,
                                  color: Colors.white),
                              onPressed: () => _saveToBoard(item),
                              tooltip: 'Save',
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}