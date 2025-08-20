import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/utils/user_profile_utils.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/board_detail_screen.dart';

class Board {
  final int id;
  final String name;
  final String? coverUrl;
  Board({required this.id, required this.name, this.coverUrl});
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseAuthService _authService = SupabaseAuthService();
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<Board>> _boardsFuture;
  bool _isLoggingOut = false;

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
        final id = (r['id'] is int)
            ? r['id'] as int
            : int.parse(r['id'].toString());
        String? cover;
        try {
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
        } catch (_) {}

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

    final messenger = ScaffoldMessenger.of(context);

    try {
      await UserProfileUtils.ensureUserProfile(user.id);
    } catch (e) {
      debugPrint('ensure profile failed: $e');
    }

    try {
      await _supabase.from('boards').insert({'user_id': user.id, 'name': name});
      if (mounted) setState(() => _boardsFuture = _fetchUserBoards());
    } catch (e) {
      debugPrint('create board failed: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to create board')),
      );
    }
  }

  Future<void> _renameBoard(int id, String newName) async {
    try {
      await _supabase.from('boards').update({'name': newName}).eq('id', id);
      if (mounted) setState(() => _boardsFuture = _fetchUserBoards());
    } catch (e) {
      debugPrint('rename failed: $e');
    }
  }

  Future<void> _deleteBoard(int id) async {
    try {
      await _supabase.from('boards').delete().eq('id', id);
      if (mounted) setState(() => _boardsFuture = _fetchUserBoards());
    } catch (e) {
      debugPrint('delete failed: $e');
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
            decoration: const InputDecoration(hintText: 'Board name'),
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
                final navigator = Navigator.of(ctx);
                await _createNewBoard(ctrl.text.trim());
                if (mounted) navigator.pop();
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
    final displayName =
        _supabase.auth.currentUser?.userMetadata?['username'] ??
        _supabase.auth.currentUser?.email?.split('@')[0] ??
        'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_isLoggingOut)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                setState(() => _isLoggingOut = true);
                try {
                  await _authService.signOut();
                } finally {
                  if (mounted) setState(() => _isLoggingOut = false);
                }
              },
            ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 36, child: Icon(Icons.person)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '0 following',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(
                const TabBar(
                  tabs: [
                    Tab(text: 'Boards'),
                    Tab(text: 'Pins'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ],
          body: TabBarView(
            children: [
              _boardsTab(),
              const Center(child: Text('Pins')),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _boardsTab() {
    return FutureBuilder<List<Board>>(
      future: _boardsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final boards = snap.data ?? [];
        if (boards.isEmpty) {
          return const Center(child: Text('No boards yet'));
        }

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: MasonryGridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: boards.length,
            itemBuilder: (context, idx) {
              final b = boards[idx];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 220 + idx * 30),
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, (1 - v) * 12),
                    child: child,
                  ),
                ),
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            BoardDetailScreen(boardId: b.id, boardName: b.name),
                      ),
                    );
                    if (mounted) {
                      setState(() => _boardsFuture = _fetchUserBoards());
                    }
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    elevation: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (b.coverUrl != null)
                          AspectRatio(
                            aspectRatio: 3 / 4,
                            child: Image.network(
                              b.coverUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            height: 140,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.photo,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  b.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    final ctrl = TextEditingController(
                                      text: b.name,
                                    );
                                    final newName = await showDialog<String>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Rename'),
                                        content: TextField(controller: ctrl),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(
                                              ctx,
                                              ctrl.text.trim(),
                                            ),
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (newName != null && newName.isNotEmpty) {
                                      await _renameBoard(b.id, newName);
                                    }
                                  } else if (v == 'delete') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete'),
                                        content: const Text(
                                          'Delete this board?',
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
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await _deleteBoard(b.id);
                                    }
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: tabBar,
  );

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}
