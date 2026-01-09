import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final TextEditingController? searchController;
  const SearchScreen({super.key, this.searchController});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  bool _isExternalController = false;

  final _debouncer = Debouncer(milliseconds: 500);
  late final JewelryService _jewelryService;

  final ImagePicker _picker = ImagePicker();


  // final _searchController = TextEditingController();
  // final _debouncer = Debouncer(milliseconds: 500);
  // late final JewelryService _jewelryService;

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

    _isExternalController = widget.searchController != null;
    _searchController = widget.searchController ?? TextEditingController();

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
    if (!_isExternalController) {
      _searchController.dispose();
    }
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _loadInitialContent() async {
    if (!mounted) return;
    setState(() => _isLoadingInitial = true);
    try {
      final latestFuture = _jewelryService.getProducts(limit: 20);

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
        FirebaseAnalytics.instance.logEvent(
          name: 'search',
          parameters: {
            'query': _currentSearchQuery,
            'result_count': 0,
          },
        );
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

  Future<void> _searchByImage() async {
    // 1. Ask user for source
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Search by Image'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Row(children: [
              Icon(Icons.camera_alt),
              SizedBox(width: 10),
              Text('Camera')
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Row(children: [
              Icon(Icons.image),
              SizedBox(width: 10),
              Text('Gallery')
            ]),
          ),
        ],
      ),
    );

    if (source == null) return;

    // 2. Pick the image
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 512, // Optimization 1: Built-in picker resize
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image == null) return;

    if (mounted) {
      FocusScope.of(context).unfocus();
      setState(() {
        _isLoadingSearch = true;
        // Prevent the listener from triggering a text search
        _currentSearchQuery = "Analyzing image..."; 
        _searchController.text = "Analyzing image...";
        _searchResults.clear();
      });
    }

    try {
      // 3. Read bytes
      Uint8List imageBytes = await image.readAsBytes();

      // 4. CRITICAL OPTIMIZATION: Resize to exactly 224x224 (CLIP Native Size)
      // This makes the payload tiny and the API response much faster.
      try {
        final img.Image? decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          // Resize using cubic interpolation for quality at small size
          final img.Image resized = img.copyResize(
            decodedImage,
            width: 224,
            height: 224,
            interpolation: img.Interpolation.cubic,
          );
          imageBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
        }
      } catch (e) {
        debugPrint("Resize failed, sending original (slower): $e");
      }

      // 5. Call the service with Supabase client for image storage
      final supabaseClient = Supabase.instance.client;
      final rawResults = await JewelryService.searchByImage(
        imageBytes,
        supabaseClient: supabaseClient,
      );

      if (mounted) {
        setState(() {
          _searchResults = rawResults
              .map((json) => JewelryItem.fromJson(json))
              .toList();
        });
      }

    } catch (e) {
      // Error handling...
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSearch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (This function remains the same as before)
    final theme = Theme.of(context);
    final bool isSearching = _currentSearchQuery.isNotEmpty;

    return PopScope(
      canPop: true,
      child: Scaffold(
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
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              fillColor: Colors.white,
              filled: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min, // Keeps the row compact
                children: [
                  // Camera Icon
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    onPressed: _searchByImage,
                    tooltip: 'Search by Image (AI Lens)',
                  ),

                  // Conditional Clear Icon
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    ),
                ],
              ),
            ),
            onSubmitted: _performSearch,
          ),
        ),
        body: _buildBody(isSearching),
      ),
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
        final isDesigner = item.isDesignerProduct;
        context.push('/product/${item.id}?isDesigner=$isDesigner');
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
