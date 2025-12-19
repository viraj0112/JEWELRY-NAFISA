import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/services/search_history_service.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:provider/provider.dart';

class SearchDropdown extends StatefulWidget {
  final TextEditingController searchController;
  final Function(List<JewelryItem> searchResults, String query) onSearchResults;
  final VoidCallback? onFocusChanged;

  const SearchDropdown({
    super.key,
    required this.searchController,
    required this.onSearchResults,
    this.onFocusChanged,
  });

  @override
  State<SearchDropdown> createState() => _SearchDropdownState();
}

class _SearchDropdownState extends State<SearchDropdown> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isLoading = false;
  List<JewelryItem> _suggestions = [];
  List<String> _recentSearches = [];
  List<String> _ideasForYou = [];
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
    _focusNode.addListener(_onFocusChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    _focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final jewelryService = Provider.of<JewelryService>(context, listen: false);
      final searchHistoryService = Provider.of<SearchHistoryService>(context, listen: false);
      
      final ideas = await jewelryService.getInitialSearchIdeas();
      if (mounted) {
        setState(() {
          _ideasForYou = ideas;
          _recentSearches = searchHistoryService.recentSearches;
        });
      }
    } catch (e) {
      debugPrint("Error loading search data: $e");
    }
  }

  void _onFocusChanged() {
    widget.onFocusChanged?.call();
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      // Delay hiding to allow for clicks on dropdown items
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _onSearchChanged() {
    final query = widget.searchController.text;
    if (query != _currentQuery) {
      setState(() {
        _currentQuery = query;
      });
      
      if (query.isEmpty) {
        _updateSuggestions();
      } else {
        _fetchSuggestions(query);
      }
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final jewelryService = Provider.of<JewelryService>(context, listen: false);
      final results = await jewelryService.searchProducts(query);
      if (mounted) {
        setState(() {
          _suggestions = results.take(10).toList(); // Limit to 10 suggestions
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
    }
  }

  void _updateSuggestions() {
    setState(() {
      _suggestions = [];
    });
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          showWhenUnlinked: false,
          link: _layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: _currentQuery.isEmpty
                  ? _buildInitialSuggestions()
                  : _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _suggestions.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'No results found for "$_currentQuery"',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _suggestions.length,
                              itemBuilder: (context, index) {
                                final item = _suggestions[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: NetworkImage(item.image),
                                    backgroundColor: Colors.grey[300],
                                    onBackgroundImageError: (exception, stackTrace) {
                                      // Handle error
                                    },
                                  ),
                                  title: Text(
                                    item.productTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    item.category ?? '',
                                    style: TextStyle(color: Colors.grey[600]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    _selectSuggestion(item);
                                  },
                                );
                              },
                            ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildInitialSuggestions() {
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Recent searches',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          ..._recentSearches.take(5).map((search) => ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(search),
                onTap: () => _selectSearchTerm(search),
              )),
          const Divider(height: 1),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Popular searches',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ..._ideasForYou.take(8).map((idea) => ListTile(
              leading: const Icon(Icons.lightbulb_outline, color: Colors.orange),
              title: Text(idea),
              onTap: () => _selectSearchTerm(idea),
            )),
      ],
    );
  }

  void _selectSuggestion(JewelryItem item) {
    _focusNode.unfocus();
    _removeOverlay();
    
    // Navigate to product detail
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => JewelryDetailScreen(jewelryItem: item),
      ),
    );
  }

  void _selectSearchTerm(String term) {
    widget.searchController.text = term;
    _focusNode.unfocus();
    _removeOverlay();
    
    // Execute search and show results
    _executeSearch(term);
  }

  Future<void> _executeSearch(String query) async {
    if (query.isEmpty) return;

    try {
      final jewelryService = Provider.of<JewelryService>(context, listen: false);
      final results = await jewelryService.searchProducts(query);
      
      // Add to search history
      Provider.of<SearchHistoryService>(context, listen: false).addSearchTerm(query);
      
      // Notify parent about search results
      widget.onSearchResults(results, query);
    } catch (e) {
      debugPrint('Error executing search: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'Search for designs, categories...',
          prefixIcon: const Icon(Icons.search, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          fillColor: Colors.white,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          suffixIcon: widget.searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    widget.searchController.clear();
                    setState(() {
                      _suggestions = [];
                      _currentQuery = '';
                    });
                  },
                )
              : null,
        ),
        onSubmitted: (query) {
          _executeSearch(query);
          _focusNode.unfocus();
          _removeOverlay();
        },
      ),
    );
  }
}