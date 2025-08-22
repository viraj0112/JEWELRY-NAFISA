import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/board_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/ui/widgets/board_card.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class Board {
  final int id;
  final String name;
  final List<String> coverUrls;
  Board({required this.id, required this.name, this.coverUrls = const []});
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<Board>> _boardsFuture;

  @override
  void initState() {
    super.initState();
    _boardsFuture = _fetchUserBoards();
  }

   Future<List<Board>> _fetchUserBoards() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
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
            .select('pins!fk_boards_pins_pin_id(image_url)')
            .eq('board_id', id)
            .limit(3);
        
        final imageUrls = (pinRes as List<dynamic>)
            .map((e) => e['pins']['image_url'] as String)
            .toList();

        result.add(Board(
          id: id,
          name: r['name'] as String,
          coverUrls: imageUrls,
        ));
      }
      return result;
    } catch (e) {
      debugPrint('fetch boards error: $e');
      return [];
    }
  }


  Future<void> _createNewBoard(String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('boards').insert({'user_id': user.id, 'name': name});
      if (mounted) {
        setState(() {
          _boardsFuture = _fetchUserBoards();
        });
      }
    } catch (e) {
      debugPrint('create board failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to create board')));
      }
    }
  }

  Future<void> _deleteBoard(int boardId) async {
    try {
      await _supabase.from('boards_pins').delete().eq('board_id', boardId);
      await _supabase.from('boards').delete().eq('id', boardId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Board deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _boardsFuture = _fetchUserBoards();
        });
      }
    } catch (e) {
      debugPrint('Delete board error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete board. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateDialog() {
    final ctrl = TextEditingController();
    final key = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create board'),
        content: Form(
          key: key,
          child: TextFormField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Board name'),
            validator: (v) => v == null || v.isEmpty ? 'Enter a name' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (key.currentState?.validate() ?? false) {
                final boardName = ctrl.text.trim();
                final user = _supabase.auth.currentUser;
                final scaffoldMessenger = ScaffoldMessenger.of(ctx);
                final navigator = Navigator.of(ctx);
                if (user == null) return;

                try {
                  final existingBoards = await _supabase
                      .from('boards')
                      .select('id')
                      .eq('user_id', user.id)
                      .eq('name', boardName)
                      .limit(1);

                  if (existingBoards.isNotEmpty) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'A board with this name already exists.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Error checking boards: $e')),
                  );
                  return;
                }

                await _createNewBoard(boardName);
                navigator.pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = Provider.of<UserProfileProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        tooltip: 'Create Board',
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildProfileHeader(context, userProfile, theme),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 24.0,
              ),
              child: Text(
                'My Boards',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _buildBoardsGrid(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    UserProfileProvider user,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
              style: const TextStyle(fontSize: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(user.username, style: theme.textTheme.headlineMedium),
          Text(
            '@${user.username.toLowerCase().replaceAll(' ', '')}',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardsGrid() {
    return FutureBuilder<List<Board>>(
      future: _boardsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final boards = snap.data ?? [];
        if (boards.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Text('No boards yet. Create one!'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Create Board"),
                      onPressed: _showCreateDialog,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(12.0),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: (MediaQuery.of(context).size.width / 250)
                .floor()
                .clamp(2, 5),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childCount: boards.length,
            itemBuilder: (context, idx) {
              final board = boards[idx];
              return BoardCard(
                board: board,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BoardDetailScreen(
                        boardId: board.id,
                        boardName: board.name,
                      ),
                    ),
                  );
                  if (mounted) {
                    setState(() {
                      _boardsFuture = _fetchUserBoards();
                    });
                  }
                },
                onDelete: () => _deleteBoard(board.id),
              );
            },
          ),
        );
      },
    );
  }
}

