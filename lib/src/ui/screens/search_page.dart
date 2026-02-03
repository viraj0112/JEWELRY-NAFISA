import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/services/search_history_service.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class SearchPage extends StatefulWidget {
  final String? initialQuery;
  const SearchPage({super.key, this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final JewelryService _jewelryService;
  late final SearchHistoryService _searchHistoryService;
  final _searchController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  List<JewelryItem> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _jewelryService =
        JewelryService(Supabase.instance.client); // Or get from Provider
    _searchHistoryService =
        Provider.of<SearchHistoryService>(context, listen: false);

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    _searchHistoryService.addSearchTerm(query);
    final results = await _jewelryService.searchProducts(query);

    if (mounted) {
      setState(() {
        _results = results.cast<JewelryItem>();
        _isLoading = false;
      });
    }
  }

  Future<void> _searchByImage() async {
    // 1. Ask user for source (Camera or Gallery)
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Image Source. \n Feature Coming Soon at your fingertips!🤳🏻'),
        actions: <Widget>[
          TextButton(
            child: Text('Camera'),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
          TextButton(
            child: Text('Gallery'),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null) return; // User cancelled the dialog

    // 2. Pick the image
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return; // User cancelled the picker

    // 3. Set loading state
    if (mounted) {
      FocusScope.of(context).unfocus(); // Dismiss keyboard
      setState(() {
        _isLoading = true;
        _hasSearched = true;
        _searchController.text = "Searching by image...";
        _results.clear();
      });
    }

    try {
      // 4. Read image bytes
      Uint8List imageBytes = await image.readAsBytes();

      // 5. Convert WebP or unsupported formats to JPEG for compatibility
      try {
        // Decode the image
        final img.Image? decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          // Re-encode as JPEG with 85% quality for good balance
          imageBytes =
              Uint8List.fromList(img.encodeJpg(decodedImage, quality: 85));
        }
      } catch (e) {
        debugPrint(
            "Image conversion warning: $e - proceeding with original format");
        // If conversion fails, continue with original bytes
      }

      // 6. Call the service
      // final results =
      //     await _jewelryService.findSimilarProductsByImage(imageBytes);
      final results = await JewelryService.searchByImage(imageBytes);


      if (mounted) {
        setState(() {
          _results = results.cast<JewelryItem>();
          _searchController.text = "Similar items to your image";
        });
      }
    } catch (e) {
      debugPrint("Error searching by image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error searching by image: $e")),
        );
      }
    } finally {
      // 5. Reset loading state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _searchController,
            autofocus: widget.initialQuery == null,
            decoration: const InputDecoration(
              hintText: 'Search for jewelry...',
              border: InputBorder.none,
            ),
            onSubmitted: _performSearch,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _performSearch(_searchController.text),
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              onPressed: _searchByImage,
              tooltip:
                  'Search by Image (AI Lens)',
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _performSearch('');
                },
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return const Center(child: Text('Enter a term to start your search.'));
    }

    if (_results.isEmpty) {
      return Center(
          child: Text('No results found for "${_searchController.text}".'));
    }

    return MasonryGridView.count(
      padding: const EdgeInsets.all(8.0),
      crossAxisCount:
          (MediaQuery.of(context).size.width / 200).floor().clamp(2, 6),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        return _buildImageCard(context, _results[index]);
      },
      mainAxisSpacing: 8.0,
      crossAxisSpacing: 8.0,
    );
  }

  Widget _buildImageCard(BuildContext context, JewelryItem item) {
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
                  children: [
                    Expanded(
                      child: Text(
                        item.productTitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
