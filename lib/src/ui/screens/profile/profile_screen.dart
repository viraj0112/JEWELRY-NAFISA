import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/board_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Board class remains the same

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<Board>> _boardsFuture;

  @override
  void initState() {
    super.initState();
    _boardsFuture = _fetchUserBoards();
  }

  // ... _fetchUserBoards, _createNewBoard, _deleteBoard, _showCreateDialog methods are unchanged ...
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
        String? cover;
        final bp = await _supabase
            .from('boards_pins')
            .select('pin_id')
            .eq('board_id', id)
            .limit(1)
            .maybeSingle();
        if (bp != null && bp['pin_id'] != null) {
          final pin = await _supabase
              .from('pins')
              .select('image_url')
              .eq('id', bp['pin_id'])
              .maybeSingle();
          if (pin != null && pin['image_url'] != null) {
            cover = pin['image_url'] as String;
          }
        }
        result.add(Board(id: id, name: r['name'] as String, coverUrl: cover));
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
                if (user == null) return;

                try {
                  final existingBoards = await _supabase
                      .from('boards')
                      .select('id')
                      .eq('user_id', user.id)
                      .eq('name', boardName)
                      .limit(1);

                  if (existingBoards.isNotEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'A board with this name already exists.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    return;
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error checking boards: $e')),
                    );
                  }
                  return;
                }

                await _createNewBoard(boardName);
                if (mounted) Navigator.of(ctx).pop();
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
      // ✨ REMOVED: AppBar is now handled by MainShell
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

  // ... _buildProfileHeader and _buildBoardsGrid methods are unchanged ...
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
            crossAxisCount: (MediaQuery.of(context).size.width / 100)
                .floor()
                .clamp(3, 8),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childCount: boards.length,
            itemBuilder: (context, idx) {
              final board = boards[idx];
              return GestureDetector(
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await navigator.push(
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
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: board.coverUrl != null
                            ? Image.network(board.coverUrl!, fit: BoxFit.cover)
                            : Container(
                                color: Theme.of(context).colorScheme.surface,
                                child: Icon(
                                  Icons.photo_library_outlined,
                                  size: 48,
                                  color: const Color.fromARGB(
                                    255,
                                    149,
                                    148,
                                    148,
                                  ),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                board.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Board?'),
                                    content: Text(
                                      'Are you sure you want to delete the "${board.name}" board and all its images?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _deleteBoard(board.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ✨ ADDED: This is needed since the class was defined inside the build method before
class Board {
  final int id;
  final String name;
  final String? coverUrl;
  Board({required this.id, required this.name, this.coverUrl});
}
