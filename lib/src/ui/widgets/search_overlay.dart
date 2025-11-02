import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/services/search_history_service.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';

class SearchOverlay extends StatefulWidget {
  final TextEditingController searchController;
  final VoidCallback onClose;
  final Function(String query)
      onSuggestionTapped; // Callback for when a suggestion is tapped

  const SearchOverlay({
    super.key,
    required this.searchController,
    required this.onClose,
    required this.onSuggestionTapped,
  });

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  late final JewelryService _jewelryService;
  late final SearchHistoryService _searchHistoryService;

  List<JewelryItem> _suggestions = [];
  bool _isLoading = false;
  String _currentQuery = '';

  // Simulate recent searches and ideas for you
  List<String> _recentSearches = [];
  List<String> _ideasForYou = [];
  bool _isLoadingInit = true;

  @override
  void initState() {
    super.initState();
    _jewelryService = Provider.of<JewelryService>(context, listen: false);
    _searchHistoryService =
        Provider.of<SearchHistoryService>(context, listen: false);
    widget.searchController.addListener(_onSearchQueryChanged);
    _currentQuery = widget.searchController.text;

    _loadInitialData();

    if (_currentQuery.isNotEmpty) {
      _fetchSuggestions(_currentQuery);
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingInit = true);
    try {
      final ideas = await _jewelryService.getInitialSearchIdeas();
      if (mounted) {
        setState(() {
          _ideasForYou = ideas;
          _recentSearches = _searchHistoryService.recentSearches;
          _isLoadingInit = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading search ideas: $e");
      if (mounted) {
        setState(() => _isLoadingInit = false);
      }
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchQueryChanged);
    super.dispose();
  }

  void _onSearchQueryChanged() {
    final newQuery = widget.searchController.text;
    if (newQuery != _currentQuery) {
      setState(() {
        _currentQuery = newQuery;
      });
      if (newQuery.isEmpty) {
        setState(() {
          _suggestions = []; // Clear suggestions if query is empty
        });
      } else {
        _fetchSuggestions(newQuery);
      }
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final results = await _jewelryService.searchProducts(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Optionally show an error message
        });
      }
      print('Error fetching suggestions: $e');
    }
  }

  Widget _buildSuggestionTile(String text, {Widget? leading}) {
    return ListTile(
      leading: leading,
      title: Text(text),
      onTap: () {
        widget.onSuggestionTapped(text); // Use the callback
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use a PopScope to handle back button press to close overlay
    return PopScope(
      canPop: false, // Prevent immediate pop
      onPopInvoked: (didPop) {
        if (didPop) return;
        widget.onClose(); // Close the overlay
      },
      child: GestureDetector(
        // Close overlay when tapping outside the content
        onTap: widget.onClose,
        child: Container(
          color: Colors.black.withOpacity(0.5), // Semi-transparent background
          child: Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: () {
                // Prevent GestureDetector from propagating to the parent GestureDetector
                // This makes sure tapping on the overlay content itself doesn't close it
              },
              child: Container(
                margin: const EdgeInsets.only(top: kToolbarHeight + 56.0),
                width: MediaQuery.of(context).size.width,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height *
                      0.7, // Max height for the overlay
                ),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _currentQuery.isEmpty
                    ? _buildInitialSuggestions()
                    : _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _suggestions.isEmpty
                            ? Center(
                                child: Text('No results for "$_currentQuery"'))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _suggestions.length,
                                itemBuilder: (context, index) {
                                  final item = _suggestions[index];
                                  return _buildSuggestionTile(
                                    item.productTitle,
                                    leading: const Icon(Icons.search),
                                  );
                                },
                              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialSuggestions() {
    if (_isLoadingInit) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    return ListView(
      shrinkWrap: true,
      children: [
        if (_recentSearches.isNotEmpty) ...[
          _buildSectionTitle(context, 'Recent searches'),
          ..._recentSearches.map((search) =>
              _buildSuggestionTile(search, leading: const Icon(Icons.history))),
          Divider(height: 1, color: theme.dividerColor),
        ],
        _buildSectionTitle(context, 'Ideas for you'),
        ..._ideasForYou.map((idea) =>
            _buildSuggestionTile(idea,
                leading: const Icon(Icons.lightbulb_outline))),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}