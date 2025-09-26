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
  String _selectedCategory = 'All';
  final List<String> _categories = ['All'];

  String? _hoveredItemId;
  String? _tappedItemId;
  final Set<String> _itemsBeingLiked = {};

  @override
  void initState() {
    super.initState();
    _jewelryService = JewelryService(_supabase);
    _loadItems();
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
      final allItems = await _jewelryService.getProducts(limit: 100);

      final seenImageUrls = <String>{};
      final uniqueItems = <JewelryItem>[];
      for (final item in allItems) {
        if (seenImageUrls.add(item.imageUrl)) {
          uniqueItems.add(item);
        }
      }

      final Set<String> allCategories = {'All'};
      for (var item in uniqueItems) {
        if (item.category != null && item.category!.isNotEmpty) {
          allCategories.add(item.category!);
        }
      }

      uniqueItems.shuffle(Random());

      if (mounted) {
        setState(() {
          _items = uniqueItems;
          _filteredItems = _items;
          _categories.clear();
          _categories.addAll(allCategories.toList()..sort());
          _selectedCategory = 'All';
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

  void _filterItems(String category) {
    setState(() {
      _selectedCategory = category;
      if (category == 'All') {
        _filteredItems = _items;
      } else {
        _filteredItems =
            _items.where((item) => item.category == category).toList();
      }
    });
  }

  Future<void> _likeItem(JewelryItem item) async {
    if (_itemsBeingLiked.contains(item.id)) return; // Prevent multiple clicks

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
          .eq('image_url', item.imageUrl)
          .maybeSingle();

      String pinId;
      if (pinData != null) {
        pinId = pinData['id'];
      } else {
        final newPin = await _supabase
            .from('pins')
            .insert({
              'owner_id': uid,
              'title': item.name,
              'image_url': item.imageUrl,
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
        // --- Like ---
        await _supabase
            .from('user_likes')
            .insert({'user_id': uid, 'pin_id': pinId});
        await _supabase.rpc('increment_like_count',
            params: {'pin_id_to_update': pinId, 'delta': 1});
      }

      // Update the UI state
      if (mounted) {
        setState(() => item.isFavorite = !item.isFavorite);
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
        'Check out this beautiful ${item.name} from Nafisa Jewellers!');
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
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadItems,
                    child: MasonryGridView.count(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8.0),
                      crossAxisCount:
                          (MediaQuery.of(context).size.width / 200)
                              .floor()
                              .clamp(2, 6),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        return _buildImageCard(context, _filteredItems[index]);
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

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChip(
                label: Text(category),
                selected: _selectedCategory == category,
                onSelected: (selected) {
                  if (selected) {
                    _filterItems(category);
                  }
                },
              ),
            );
          },
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
              Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) =>
                    progress == null
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
                              item.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (!isMember) const Spacer(),
                        Row(
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
                            ),
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.white),
                              onPressed: () => _shareItem(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.bookmark_border,
                                  color: Colors.white),
                              onPressed: () => _saveToBoard(item),
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