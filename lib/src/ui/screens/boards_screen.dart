import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/board.dart'; // Import the new model
import 'package:jewelry_nafisa/src/providers/boards_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/board_detail_screen.dart';
import 'package:jewelry_nafisa/src/ui/widgets/board_card.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// The local 'Board' class has been REMOVED from this file

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

  @override
  void initState() {
    super.initState();
    _fetchUserBoards();
    _searchController.addListener(_filterBoards);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterBoards);
    _searchController.dispose();
    super.dispose();
  }

  void _filterBoards() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBoards = _allBoards
          .where((board) => board.name.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _fetchUserBoards() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingBoards = false);
      return;
    }
    try {
      final res = await _supabase
          .from('boards')
          .select('id, name')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(res as List<dynamic>);
      final result = <Board>[];
      for (final r in rows) {
        final id = r['id'] as int;
        final pinRes = await _supabase
            .from('boards_pins')
            .select('pins(image_url)')
            .eq('board_id', id)
            .limit(3);

        final imageUrls = (pinRes as List<dynamic>)
            .map((e) => e['pins']['image_url'] as String)
            .toList();
        result.add(
          Board(id: id, name: r['name'] as String, coverUrls: imageUrls),
        );
      }
      if (mounted) {
        setState(() {
          _allBoards = result;
          _filteredBoards = result;
          _isLoadingBoards = false;
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
    try {
      await _supabase.from('boards').delete().eq('id', boardId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Board deleted.'),
          backgroundColor: Colors.green,
        ),
      );
      _fetchUserBoards();
    } catch (e) {
      debugPrint('Error deleting board: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete board.'),
          backgroundColor: Colors.red,
        ),
      );
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
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Icons.add),
            onPressed: _showCreateBoardDialog,
            tooltip: 'Create New Board',
          ),
        ],
      ),
    );
  }

  void _showCreateBoardDialog() {
    final boardNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Board'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: boardNameController,
            decoration: const InputDecoration(labelText: 'Board Name'),
            validator: (v) => v!.isEmpty ? 'Name cannot be empty' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await context.read<BoardsProvider>().createBoard(
                      boardNameController.text.trim(),
                    );
                Navigator.pop(context);
                _fetchUserBoards();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardsGrid() {
    if (_isLoadingBoards) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredBoards.isEmpty) {
      return const Center(child: Text("No boards found."));
    }
    return MasonryGridView.count(
      padding: const EdgeInsets.all(12.0),
      crossAxisCount:
          (MediaQuery.of(context).size.width / 250).floor().clamp(2, 5),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: _filteredBoards.length,
      itemBuilder: (context, idx) {
        final board = _filteredBoards[idx];
        return BoardCard(
          board: board,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    BoardDetailScreen(boardId: board.id, boardName: board.name),
              ),
            );
            _fetchUserBoards();
          },
          onDelete: () => _deleteBoard(board.id),
        );
      },
    );
  }
}
