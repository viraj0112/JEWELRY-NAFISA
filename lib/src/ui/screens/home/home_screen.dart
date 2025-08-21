import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final JewelryService _jewelryService = JewelryService();
  final List<JewelryItem> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMoreItems(); // Initial data load
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent * 0.9 &&
          !_isLoading) {
        _loadMoreItems();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMoreItems() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final newItems = await _jewelryService.fetchJewelryItems(
      offset: _items.length,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (newItems.isEmpty) {
          _hasMore = false;
        } else {
          _items.addAll(newItems);
        }
      });
    }
  }

  Future<void> _onRefresh() async {
    _items.clear();
    _hasMore = true;
    await _loadMoreItems();
  }

  @override
  Widget build(BuildContext context) {
    // ✨ REMOVED: Scaffold, AppBar, and Providers as they are handled by MainShell
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: MasonryGridView.count(
        controller: _scrollController,
        padding: const EdgeInsets.all(8.0),
        crossAxisCount: (MediaQuery.of(context).size.width / 200).floor().clamp(
          2,
          6,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildImageCard(context, _items[index]);
        },
        mainAxisSpacing: 8.0,
        crossAxisSpacing: 8.0,
      ),
    );
  }

  Widget _buildImageCard(BuildContext context, JewelryItem item) {
    return GestureDetector(
      onTap: () {
        final isWide = MediaQuery.of(context).size.width > 800;
        // ✨ NEW: Show detail screen in a dialog on wide screens
        if (isWide) {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 40.0,
                vertical: 24.0,
              ),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: JewelryDetailScreen(
                  imageUrl: item.imageUrl,
                  itemName: item.name,
                  pinId: item.id,
                ),
              ),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => JewelryDetailScreen(
                imageUrl: item.imageUrl,
                itemName: item.name,
                pinId: item.id,
              ),
            ),
          );
        }
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          item.imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Theme.of(context).colorScheme.surface,
              child: const Center(child: CircularProgressIndicator.adaptive()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Theme.of(context).colorScheme.surface,
              child: const Icon(Icons.error_outline, color: Colors.grey),
            );
          },
        ),
      ),
    );
  }
}
