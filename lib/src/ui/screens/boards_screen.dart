import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/board.dart'; // Import the model from the correct path
import 'package:jewelry_nafisa/src/providers/boards_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/board_detail_screen.dart';
import 'package:jewelry_nafisa/src/ui/widgets/board_card.dart'; // Import the updated BoardCard
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- ADDED: SortMode enum ---
enum SortMode { newest, nameAsc, nameDesc }

class BoardsScreen extends StatefulWidget {
  const BoardsScreen({super.key});

  @override
  State<BoardsScreen> createState() => _BoardsScreenState();
}

class _BoardsScreenState extends State<BoardsScreen> {
  final _supabase = Supabase.instance.client;
  List<Board> _allBoards = [];
  List<Board> _filteredBoards = [];
  bool _isLoadingBoards = true;
  final _searchController = TextEditingController();
  SortMode _sortMode = SortMode.newest; // --- ADDED: Sort state ---

  @override
  void initState() {
    super.initState();
    _fetchUserBoards();
    // --- UPDATED: Listener now rebuilds state to show/hide clear icon ---
    _searchController.addListener(() {
      setState(() {}); // Rebuilds to show/hide clear icon
      _filterBoards(); // Calls the existing filter logic
    });
  }

  @override
  void dispose() {
    // --- UPDATED: Make sure to remove the correct listener ---
    _searchController.removeListener(() {
      setState(() {});
      _filterBoards();
    });
    _searchController.dispose();
    super.dispose();
  }

  void _filterBoards() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBoards = _allBoards
          .where((board) => board.name.toLowerCase().contains(query))
          .toList();
      _sortBoards(); // Apply sorting after filtering
    });
  }

  // --- ADDED: Sort Function ---
  void _sortBoards() {
    setState(() {
      switch (_sortMode) {
        case SortMode.nameAsc:
          _filteredBoards
              .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          break;
        case SortMode.nameDesc:
          _filteredBoards
              .sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
          break;
        case SortMode.newest:
          // Sort by ID descending (assuming higher ID is newer)
          _filteredBoards.sort((a, b) => b.id.compareTo(a.id));
          break;
      }
    });
  }

  Future<void> _fetchUserBoards() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingBoards = false);
      return;
    }
    try {
      if (!mounted) return;
      setState(() => _isLoadingBoards = true);

      final res = await _supabase
          .from('boards')
          .select('id, name, is_secret')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final rows = List<Map<String, dynamic>>.from(res as List<dynamic>);
      final result = <Board>[];

      await Future.wait(rows.map((r) async {
        final id = r['id'] as int;
        final pinRes = await _supabase
            .from('boards_pins')
            .select('pins(image_url)')
            .eq('board_id', id)
            .limit(3);

        final imageUrls = (pinRes as List<dynamic>)
            .map((e) => e['pins']['image_url'] as String?)
            .where((url) => url != null)
            .cast<String>()
            .toList();

        result.add(
          Board(
            id: id,
            name: r['name'] as String,
            coverUrls: imageUrls,
            isSecret: r['is_secret'] as bool? ?? false,
          ),
        );
      }));

      // Sort boards after fetching covers to maintain order
      result.sort((a, b) => b.id.compareTo(a.id));

      if (mounted) {
        setState(() {
          _allBoards = result;
          _filteredBoards = result;
          _isLoadingBoards = false;
          _sortBoards(); // --- ADDED: Apply initial sort ---
        });
      }
    } catch (e) {
      debugPrint('fetch boards error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error loading boards: ${e is PostgrestException ? e.message : e.toString()}'),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoadingBoards = false);
      }
    }
  }

  Future<void> _deleteBoard(int boardId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Board?"),
          content: const Text(
              "Are you sure you want to delete this board and all its Pins? This action cannot be undone."),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _supabase.from('boards').delete().eq('id', boardId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Board deleted.'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchUserBoards();
      }
    } catch (e) {
      debugPrint('Error deleting board: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete board.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildBoardToolbar(),
          Expanded(child: _buildBoardsGrid()),
        ],
      ),
    );
  }

  // --- UPDATED: Toolbar with Search, Sort, and Add Button ---
  Widget _buildBoardToolbar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search your boards...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                // --- IMPLEMENTED: Clear Button ---
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // --- IMPLEMENTED: Sort Button ---
          IconButton.filledTonal(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
            tooltip: 'Sort Boards',
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.add),
            onPressed: _showCreateBoardDialog,
            tooltip: 'Create New Board',
          ),
        ],
      ),
    );
  }

  // --- ADDED: Sort Options Modal ---
  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(_sortMode == SortMode.newest ? Icons.check_circle : Icons.circle_outlined),
              title: const Text('Sort by Newest'),
              onTap: () {
                Navigator.pop(context);
                _sortMode = SortMode.newest;
                _sortBoards();
              },
            ),
            ListTile(
              leading: Icon(_sortMode == SortMode.nameAsc ? Icons.check_circle : Icons.circle_outlined),
              title: const Text('Sort A-Z'),
              onTap: () {
                Navigator.pop(context);
                _sortMode = SortMode.nameAsc;
                _sortBoards();
              },
            ),
            ListTile(
              leading: Icon(_sortMode == SortMode.nameDesc ? Icons.check_circle : Icons.circle_outlined),
              title: const Text('Sort Z-A'),
              onTap: () {
                Navigator.pop(context);
                _sortMode = SortMode.nameDesc;
                _sortBoards();
              },
            ),
          ],
        );
      },
    );
  }

  // --- Dialog for Creating New Boards (includes Secret option) ---
  void _showCreateBoardDialog() {
    final TextEditingController nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSecret = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Create Board"),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Board Name"),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Board name cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Keep this board secret?"),
                        Switch(
                          value: isSecret,
                          onChanged: (value) {
                            setDialogState(() {
                              isSecret = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final name = nameController.text.trim();
                      try {
                        await context.read<BoardsProvider>().createBoard(
                              name,
                              isSecret: isSecret,
                            );
                        Navigator.of(context).pop();
                        _fetchUserBoards();
                      } catch (e) {
                        if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text('Error creating board: $e'), backgroundColor: Colors.red),
                           );
                        }
                      }
                    }
                  },
                  child: const Text("Create"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- ADDED: Edit Board Dialog ---
  void _showEditBoardDialog(Board board) {
    final TextEditingController nameController =
        TextEditingController(text: board.name);
    final formKey = GlobalKey<FormState>();
    bool isSecret = board.isSecret;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Board"),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Board Name"),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Board name cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Keep this board secret?"),
                        Switch(
                          value: isSecret,
                          onChanged: (value) {
                            setDialogState(() {
                              isSecret = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final newName = nameController.text.trim();
                      if (newName == board.name && isSecret == board.isSecret) {
                        Navigator.of(context).pop(); // No changes
                        return;
                      }

                      try {
                        // Call the provider's updateBoard method
                        await context.read<BoardsProvider>().updateBoard(
                              board.id,
                              newName,
                              isSecret,
                            );
                        Navigator.of(context).pop(); // Close the dialog
                        _fetchUserBoards(); // Refresh the boards list
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error updating board: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Grid View for Displaying Boards ---
  Widget _buildBoardsGrid() {
    if (_isLoadingBoards) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredBoards.isEmpty && _searchController.text.isEmpty) {
      return const Center(
          child: Text(
        "You haven't created any boards yet.\nTap the '+' button to start!",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey),
      ));
    }
    if (_filteredBoards.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(
          child: Text(
        "No boards found matching your search.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey),
      ));
    }

    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      crossAxisCount:
          (MediaQuery.of(context).size.width / 200).floor().clamp(2, 5),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: _filteredBoards.length,
      itemBuilder: (context, idx) {
        final board = _filteredBoards[idx];
        return GestureDetector(
          onLongPress: () => _showEditBoardDialog(board),
          child: BoardCard(
            board: board,
            onTap: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      BoardDetailScreen(boardId: board.id, boardName: board.name),
                ),
              );
              if (result == true) {
                _fetchUserBoards();
              }
            },
            onDelete: () => _deleteBoard(board.id),
          ),
        );
      },
    );
  }
}