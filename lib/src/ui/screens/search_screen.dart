// src/ui/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 500);
  late final JewelryService _jewelryService;

  List<JewelryItem> _searchResults = [];
  List<JewelryItem> _trendingItems = [];
  List<JewelryItem> _latestItems = [];
  bool _isLoadingSearch = false;
  bool _isLoadingInitial = true;
  String _currentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _jewelryService = Provider.of<JewelryService>(context, listen: false);
    _loadInitialContent();
    _searchController.addListener(() {
      _debouncer.run(() {
        final query = _searchController.text;
        if (mounted && query != _currentSearchQuery) {
          _performSearch(query);
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  // --- UPDATED _loadInitialContent ---
  Future<void> _loadInitialContent() async {
    if (!mounted) return;
    setState(() => _isLoadingInitial = true);
    try {
      // Fetch latest items (assuming getProducts fetches recent items first)
      final latestFuture = _jewelryService.getProducts(limit: 20);

      // Fetch "trending" items using the new RPC
      final trendingFuture = _jewelryService.getTrendingProducts(limit: 20);

      // Wait for both to finish
      final results = await Future.wait([latestFuture, trendingFuture]);
      final latest = results[0];
      final trending = results[1];

      if (mounted) {
        setState(() {
          _latestItems = latest;
          _trendingItems = trending; // This is now real trending data
          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error loading initial content: $e');
        setState(() => _isLoadingInitial = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading content: ${e.toString()}')),
        );
      }
    }
  }
  // --- END UPDATED _loadInitialContent ---

  Future<void> _performSearch(String query) async {
    // ... (This function remains the same as before)
    _currentSearchQuery = query.trim();
    if (!mounted) return;

    if (_currentSearchQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoadingSearch = false;
        if (_trendingItems.isEmpty || _latestItems.isEmpty) {
          _loadInitialContent();
        }
      });
      return;
    }

    setState(() => _isLoadingSearch = true);
    try {
      final results = await _jewelryService.searchProducts(_currentSearchQuery);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoadingSearch = false;
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error during search: $e');
        setState(() => _isLoadingSearch = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (This function remains the same as before)
    final theme = Theme.of(context);
    final bool isSearching = _currentSearchQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16.0,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search designs, categories...',
            prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            fillColor: theme.splashColor,
            filled: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          onSubmitted: _performSearch,
        ),
      ),
      body: _buildBody(isSearching),
    );
  }

  Widget _buildBody(bool isSearching) {
    // ... (This function remains the same as before)
    if (isSearching) {
      // --- Display Search Results (Masonry Grid) ---
      if (_isLoadingSearch) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_searchResults.isEmpty) {
        return Center(
            child: Text(
          'No results found for "$_currentSearchQuery".',
          style: TextStyle(color: Colors.grey[600]),
        ));
      }
      // Use the full-page masonry grid for search results
      return _buildMasonryGrid(_searchResults);
    } else {
      // --- Display Initial Content (Grouped Sections) ---
      if (_isLoadingInitial) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_trendingItems.isEmpty && _latestItems.isEmpty) {
        return Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No collections to display.',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 10),
            ElevatedButton(
                onPressed: _loadInitialContent,
                child: const Text('Try Reloading'))
          ],
        ));
      }

      // Use a ListView to stack the grouped sections
      return RefreshIndicator(
        onRefresh: _loadInitialContent,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (_trendingItems.isNotEmpty) ...[
              _buildGroupedSection(
                context,
                title: "Trending Collection",
                items: _trendingItems,
              ),
              const SizedBox(height: 24), // Spacing between sections
            ],
            if (_latestItems.isNotEmpty) ...[
              _buildGroupedSection(
                context,
                title: "Latest Collection",
                items: _latestItems,
              ),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildGroupedSection(
    BuildContext context, {
    required String title,
    required List<JewelryItem> items,
  }) {
    // ... (This function remains the same as before)
    final theme = Theme.of(context);
    // Limit the number of items shown in the preview grid, e.g., 6
    final displayItems = items.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Use a standard GridView.builder for the square grid look
        GridView.builder(
          shrinkWrap: true, // Important for ListView
          physics:
              const NeverScrollableScrollPhysics(), // Disable grid scrolling
          itemCount: displayItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            // Adjust crossAxisCount based on screen size if needed
            crossAxisCount: (MediaQuery.of(context).size.width / 180)
                .floor()
                .clamp(2, 3), // e.g., 2 or 3 columns
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
            childAspectRatio: 1.0, // Make items square
          ),
          itemBuilder: (context, index) {
            return _buildImageCard(context, displayItems[index],
                isGrouped: true);
          },
        ),
      ],
    );
  }

  Widget _buildMasonryGrid(List<JewelryItem> items, {bool isSliver = false}) {
    // ... (This function remains the same as before)
    if (items.isEmpty) {
      return isSliver
          ? const SliverToBoxAdapter(child: SizedBox.shrink())
          : const SizedBox.shrink();
    }

    final grid = MasonryGridView.count(
      physics: isSliver
          ? const NeverScrollableScrollPhysics()
          : null, // Disable scrolling if sliver
      shrinkWrap: isSliver, // Shrink if sliver
      padding: const EdgeInsets.all(8.0),
      // Dynamic cross axis count based on screen width
      crossAxisCount:
          (MediaQuery.of(context).size.width / 180).floor().clamp(2, 5),
      itemCount: items.length,
      itemBuilder: (context, index) {
        // Call the updated card builder
        return _buildImageCard(context, items[index], isGrouped: false);
      },
      mainAxisSpacing: 8.0,
      crossAxisSpacing: 8.0,
    );

    return isSliver ? SliverToBoxAdapter(child: grid) : grid;
  }

  Widget _buildImageCard(BuildContext context, JewelryItem item,
      {bool isGrouped = false}) {
    // ... (This function remains the same as before)
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => JewelryDetailScreen(jewelryItem: item),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        // Make corners slightly less rounded for the grouped view if desired
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isGrouped ? 8 : 12)),
        child: AspectRatio(
          // Ensure image fits well in grid/masonry
          aspectRatio: isGrouped
              ? 1.0
              : item.aspectRatio, // Use 1.0 for square grid items
          child: Image.network(
            item.image,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Container(
                    color: Theme.of(context).colorScheme.surface.withAlpha(50),
                    child: const Center(
                        child: CircularProgressIndicator.adaptive()),
                  ),
            errorBuilder: (context, error, stackTrace) => Container(
              color: Theme.of(context).colorScheme.surface.withAlpha(30),
              child: const Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
            ),
          ),
        ),
      ),
    );
  }
}
