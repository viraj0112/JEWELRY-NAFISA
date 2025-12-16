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
  bool _isLoadingCategories = false;
  bool _isLoadingSubCategories = false;

  // Filter options
  List<String> _productTypeOptions = ['All'];
  List<String> _categoryOptions = ['All'];
  List<String> _subCategoryOptions = ['All'];
  List<String> _metalPurity = ['All'];
  List<String> _plainOptions = [];
  List<String> _studdedOptions = [];

  // Selected filter values
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingFilters = true;
      _isLoadingProducts = true;
    });
    try {
      // 1. Load Initial Filter Options (Independent filters only)
      final options = await _filterService.getInitialFilterOptions();
      options.updateAll((key, value) {
        if (value.isNotEmpty && !value.contains('All')) {
          if (key == 'Product Type') {
            return ['All', ...value];
          }
        }
        return value;
      });

      // 2. Load Initial Products (with default filters)
      final productList = await _fetchFilteredProducts();

      if (mounted) {
        setState(() {
          _productTypeOptions = options['Product Type'] ?? ['All'];
          _plainOptions = options['Plain'] ?? [];
          _metalPurity = options['Metal Purity'] ?? [];
          _studdedOptions = options['Studded'] ?? [];
          _products = productList;
          _isLoadingFilters = false;
          _isLoadingProducts = false;
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

  Future<List<JewelryItem>> _fetchFilteredProducts() async {
    if (mounted) {
      setState(() => _isLoadingProducts = true);
    }
    try {
      // Build query for 'products' table
      dynamic productsQuery = _supabase.from('products').select();
      
      // Build query for 'designerproducts' table
      dynamic designerQuery = _supabase.from('designerproducts').select();

      // Apply filters to both queries
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

      productsQuery = productsQuery.limit(500000);
      designerQuery = designerQuery.limit(500000);
      
      // Fetch from both tables in parallel
      // Execute queries and cast to Future<dynamic> for Future.wait
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

      allItems.shuffle();
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
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  // This function just applies the filters and updates the product list
  Future<void> _applyFilters() async {
    final productList = await _fetchFilteredProducts();
    if (mounted) {
      setState(() => _products = productList);
    }
  }

  // Handlers for dependent dropdowns

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

    final filters = {'Product Type': value};
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
    final filters = {
      'Product Type': _selectedProductType,
      'Category': value,
    };
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
      _selectedProductType = 'All';
      _selectedCategory = 'All';
      _selectedSubCategory = 'All';
      _selectedPlain = null;
      _selectedStudded = null;

      // Reset option lists to default
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
      onRefresh: _loadInitialData,
      child: _products.isEmpty
          ? const Center(child: Text('No products found matching your filters.'))
          : MasonryGridView.count(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              crossAxisCount:
                  (MediaQuery.of(context).size.width / 200).floor().clamp(2, 6),
              itemCount: _products.length,
              itemBuilder: (context, index) {
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
        padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Center(child: LinearProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        alignment: WrapAlignment.start,
        children: [
          _buildDropdownFilter(
            hint: 'Product Type',
            options: _productTypeOptions,
            selectedValue: _selectedProductType,
            onChanged: _onProductTypeChanged,
          ),
          _buildDropdownFilter(
            hint: 'Category',
            options: _categoryOptions,
            selectedValue: _selectedCategory,
            onChanged: _onCategoryChanged,
            isLoading: _isLoadingCategories,
          ),
          _buildDropdownFilter(
            hint: 'Sub Category',
            options: _subCategoryOptions,
            selectedValue: _selectedSubCategory,
            onChanged: _onSubCategoryChanged,
            isLoading: _isLoadingSubCategories,
          ),
          _buildDropdownFilter(
            hint: 'Metal Purity',
            options: _metalPurity,
            selectedValue: _selectedMetalPurity,
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedMetalPurity = value;
              });
              _applyFilters();
            },
          ),
          _buildChoiceChipFilter(
            label: 'Plain',
            options: _plainOptions,
            selectedOption: _selectedPlain,
            onSelected: (value) {
              setState(() => _selectedPlain = value);
              _applyFilters();
            },
          ),
          _buildChoiceChipFilter(
            label: 'Studded',
            options: _studdedOptions,
            selectedOption: _selectedStudded,
            onSelected: (value) {
              setState(() => _selectedStudded = value);
              _applyFilters();
            },
          ),
          if (_selectedProductType != 'All' ||
              _selectedCategory != 'All' ||
              _selectedSubCategory != 'All' ||
              _selectedMetalPurity != 'All' ||
              _selectedPlain != null ||
              _selectedStudded != null)
            ActionChip(
              avatar: const Icon(Icons.clear, size: 18),
              label: const Text('Reset'),
              onPressed: _resetFilters,
            ),
        ],
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

    return DropdownButton<String>(
      hint: Text(hint),
      value: currentSelection,
      onChanged: onChanged,
      items: displayOptions.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
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
      spacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ...options.map((option) {
          final isSelected = selectedOption == option;
          return ChoiceChip(
            label: Text(option),
            selected: isSelected,
            onSelected: (selected) {
              onSelected(selected ? option : null);
            },
            selectedColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.2),
            checkmarkColor: Theme.of(context).colorScheme.primary,
          );
        }).toList(),
      ],
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
              Image.network(
                item.image,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator.adaptive()),
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.error_outline, color: Colors.grey),
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