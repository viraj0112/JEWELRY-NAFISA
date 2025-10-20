import 'dart:math';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/ui/widgets/save_to_board_dialog.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:jewelry_nafisa/src/providers/boards_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;
  late final JewelryService _jewelryService;
  List<JewelryItem> _items = [];
  List<JewelryItem> _filteredItems = []; 
  bool _isLoading = false;
  String _selectedProductType = 'All'; 
  final List<String> _productTypes = ['All']; 
 
  String? _hoveredItemId;
  String? _tappedItemId;
  final Set<String> _itemsBeingLiked = {};

  @override
  void initState() {
    super.initState();
    _jewelryService = JewelryService(_supabase);
    _loadItems(); // Initial load
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // Fetch items (you might want pagination later)
      final allItems = await _jewelryService.getProducts(limit: 100); // Increased limit slightly

      // --- Extract Unique Product Types ---
      final Set<String> uniqueTypes = {'All'}; // Start with 'All'
      for (var item in allItems) {
        // Use 'productType' field from the model
        if (item.productType != null && item.productType!.isNotEmpty) {
          uniqueTypes.add(item.productType!);
        }
      }
      // ------------------------------------

      // Shuffle for variety if desired
      allItems.shuffle(Random());

      if (mounted) {
        setState(() {
          _items = allItems;
          _filteredItems = allItems; // Initially show all
          _productTypes.clear();
          _productTypes.addAll(uniqueTypes.toList()..sort()); // Update list for chips
          _selectedProductType = 'All'; // Reset filter selection
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading items from Supabase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load designs: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // --- FILTER FUNCTION ---
  void _filterItems(String productType) {
    setState(() {
      _selectedProductType = productType;
      if (productType == 'All') {
        _filteredItems = _items; // Show all items
      } else {
        // Filter based on the selected productType
        _filteredItems = _items
            .where((item) => item.productType == productType)
            .toList();
      }
    });
  }
  // ---------------------

  Future<void> _likeItem(JewelryItem item) async {
     // ... (like logic remains the same)
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
          .eq('image_url', item.image) // Use item.image
          .maybeSingle();

      String pinId;
      if (pinData != null) {
        pinId = pinData['id'];
      } else {
        final newPin = await _supabase
            .from('pins')
            .insert({
              'owner_id': uid,
              'title': item.productTitle, // Use item.productTitle
              'image_url': item.image, // Use item.image
              'description': item.description, // Use item.description
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
        // Update the state in both lists to ensure consistency
        final itemIndex = _items.indexWhere((i) => i.id == item.id);
        if (itemIndex != -1) {
          _items[itemIndex].isFavorite = !_items[itemIndex].isFavorite;
        }
         final filteredIndex = _filteredItems.indexWhere((i) => i.id == item.id);
         if (filteredIndex != -1) {
          setState(() => _filteredItems[filteredIndex].isFavorite = !_filteredItems[filteredIndex].isFavorite);
         } else {
          setState(() {}); // Still trigger rebuild if not in filtered list currently
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
    // ... (share logic remains the same)
    Share.share(
        'Check out this beautiful ${item.productTitle} from Dagina Designs!');
  }

  void _saveToBoard(JewelryItem item) {
    // ... (save logic remains the same)
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
          // --- ADD FILTER CHIPS ---
          _buildFilterChips(), // Add the filter chips UI here
          // -----------------------
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadItems, // Reload all items on refresh
                    child: MasonryGridView.count(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8.0),
                      // Adjust cross axis count based on screen width
                      crossAxisCount:
                          (MediaQuery.of(context).size.width / 200)
                              .floor()
                              .clamp(2, 6),
                      // Use the _filteredItems list here
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        // Build card using item from _filteredItems
                        return _buildImageCard(
                            context, _filteredItems[index]);
                      },
                      mainAxisSpacing: 8.0,
                      crossAxisSpacing: 8.0,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET FOR FILTER CHIPS ---
  Widget _buildFilterChips() {
    // Handle case where product types haven't loaded yet
    if (_productTypes.isEmpty) return const SizedBox(height: 48);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: 40, // Give the ListView a fixed height
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _productTypes.length,
          itemBuilder: (context, index) {
            final type = _productTypes[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChip(
                label: Text(type),
                selected: _selectedProductType == type,
                onSelected: (selected) {
                  if (selected) {
                    _filterItems(type); // Call filter function on select
                  }
                },
                // Optional: Style selected chip differently
                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                checkmarkColor: Theme.of(context).colorScheme.primary,
              ),
            );
          },
        ),
      ),
    );
  }
  // -------------------------------

  Widget _buildImageCard(BuildContext context, JewelryItem item) {
    // ... (card building logic remains the same)
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
                loadingBuilder: (context, child, progress) =>
                    progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator.adaptive()),
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
                        if (!isMember) const Spacer(), // Takes up space if not member
                        Row(
                          mainAxisSize: MainAxisSize.min, // Keep buttons compact
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
                              constraints: const BoxConstraints(), // Remove extra constraints
                            ),
                            IconButton(
                              icon: const Icon(Icons.share,
                                  color: Colors.white),
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