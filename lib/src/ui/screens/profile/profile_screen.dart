import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Board {
  final String name;
  Board({required this.name});
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseAuthService authService = SupabaseAuthService();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoggingOut = false; // Keep this state variable

  late Future<List<Board>> _boardsFuture;

  @override
  void initState() {
    super.initState();
    _boardsFuture = _fetchUserBoards();
  }

  // Fetches boards for the current user from Supabase
  Future<List<Board>> _fetchUserBoards() async {
    // Use the Supabase user object, not Firebase
    final supabaseUser = _supabase.auth.currentUser;
    if (supabaseUser == null) return [];
    try {
      final response = await _supabase
          .from('boards')
          .select('name')
          .eq('user_id', supabaseUser.id);

      final boards = (response as List)
          .map((data) => Board(name: data['name'] as String))
          .toList();
      return boards;
    } catch (e) {
      print("Error fetching boards: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not fetch boards')));
      }
      return [];
    }
  }

  // Shows a dialog to create a new board
  void _showCreateBoardDialog() {
    final boardNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Board'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: boardNameController,
              decoration: const InputDecoration(hintText: "Board Name"),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter a name' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await _createNewBoard(boardNameController.text);
                  if (mounted) Navigator.of(context).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  // Saves the new board to Supabase
  Future<void> _createNewBoard(String name) async {
    // --- FIX #2: Use the Supabase user object, not Firebase ---
    final supabaseUser = _supabase.auth.currentUser;
    if (supabaseUser == null) {
      // Handle case where user is not logged into Supabase
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not logged in. Please restart the app.'),
          ),
        );
      }
      return;
    }

    try {
      await _supabase.from('boards').insert({
        'user_id': supabaseUser.id, // This is the correct UUID
        'name': name,
      });
      setState(() {
        _boardsFuture = _fetchUserBoards();
      });
    } catch (e) {
      print("Error creating board: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create board.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_isLoggingOut)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                setState(() {
                  _isLoggingOut = true;
                });

                try {
                  await authService.signOut();
                  // ADD THIS LINE:
                  // This ensures that we pop all screens until we get back to the root.
                  if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  print("Error during sign out: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Error signing out. Please try again."),
                      ),
                    );
                    // Also set loading to false in case of an error
                    setState(() {
                      _isLoggingOut = false;
                    });
                  }
                }
              },
            ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        child: Icon(Icons.person, size: 50),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _supabase.auth.currentUser?.userMetadata?['username'] ??
                        _supabase.auth.currentUser?.email?.split('@')[0] ?? 'Username',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '0 following',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
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
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildBoardsGrid(),
              const Center(child: Text('Your saved pins will appear here')),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateBoardDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBoardsGrid() {
    return FutureBuilder<List<Board>>(
      future: _boardsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading boards'));
        }
        final boards = snapshot.data ?? [];
        if (boards.isEmpty) {
          return const Center(
            child: Text(
              'Your boards will appear here',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(8.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 4 / 3,
          ),
          itemCount: boards.length,
          itemBuilder: (context, index) {
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Container(color: Colors.grey[200]), // Placeholder background
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      boards[index].name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Delegate for making the TabBar sticky
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
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
