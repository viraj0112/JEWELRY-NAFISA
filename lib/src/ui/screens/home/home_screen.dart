import 'dart:convert';
import 'dart:math';
import 'package:jewelry_nafisa/src/ui/widgets/save_to_board_dialog.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:jewelry_nafisa/src/providers/boards_provider.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  List<JewelryItem> _items = [];
  List<JewelryItem> _filteredItems = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All'];

  String? _hoveredItemId;
  String? _tappedItemId;

  @override
  void initState() {
    super.initState();
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
      final jsonString = await rootBundle.loadString('assets/result.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      final allItems = jsonList
          .map((item) => JewelryItem.fromMap(item as Map<String, dynamic>))
          .toList();

      final Set<String> allCategories = {'All'};
      for (var item in allItems) {
        allCategories.addAll(item.category.map((c) => c.trim()));
      }

      allItems.shuffle(Random());

      if (mounted) {
        setState(() {
          _items = allItems;
          _filteredItems = _items;
          _categories.clear();
          _categories.addAll(allCategories.toList()..sort());
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading items from JSON: $e');
      if (mounted) {
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
        _filteredItems = _items
            .where(
              (item) => item.category.map((e) => e.trim()).contains(category),
            )
            .toList();
      }
    });
  }

  void _likeItem(JewelryItem item) {
    setState(() => item.isFavorite = !item.isFavorite);
    // You can add your database logic here
  }

  void _shareItem(JewelryItem item) {
    Share.share('Check out this beautiful ${item.name} from Nafisa Jewellers!');
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
                      crossAxisCount: (MediaQuery.of(context).size.width / 200)
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

  // ✨ UPDATED: This widget now handles both hover and long-press
  Widget _buildImageCard(BuildContext context, JewelryItem item) {
    final bool isHovered = _hoveredItemId == item.url;
    final bool isTapped = _tappedItemId == item.url;

    return GestureDetector(
      // ✨ On mobile, a long press will show the buttons
      onLongPress: () {
        setState(() {
          _tappedItemId = item.url;
        });
      },
      // ✨ On mobile, a regular tap performs an action
      onTap: () {
        // If buttons are visible from a long press, tapping again hides them
        if (isTapped) {
          setState(() {
            _tappedItemId = null;
          });
        } else {
          // Otherwise, navigate to the detail screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => JewelryDetailScreen(
                imageUrl: item.imageUrl,
                itemName: item.name,
                pinId: item.url,
              ),
            ),
          );
        }
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: MouseRegion(
          // On desktop, mouse hover shows the buttons
          onEnter: (_) => setState(() => _hoveredItemId = item.url),
          onExit: (_) => setState(() => _hoveredItemId = null),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // The main image
              Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error_outline, color: Colors.grey);
                },
              ),
              // ✨ Show overlay if hovered (desktop) OR tapped (mobile)
              if (isHovered || isTapped)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withAlpha((255 * 0.7).round()), Colors.transparent],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                item.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: item.isFavorite ? Colors.red : Colors.white,
                              ),
                              onPressed: () => _likeItem(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.white),
                              onPressed: () => _shareItem(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.bookmark_border, color: Colors.white),
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