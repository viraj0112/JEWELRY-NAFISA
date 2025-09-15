import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/providers/boards_provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/membership/buy_membership_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/board_detail_screen.dart';
import 'package:jewelry_nafisa/src/ui/widgets/board_card.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/ui/screens/referral_screen.dart';
import 'package:jewelry_nafisa/src/ui/widgets/credit_info_card.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Board> _allBoards = [];
  List<Board> _filteredBoards = [];
  bool _isLoadingBoards = true;
  final _searchController = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchUserBoards();
    _searchController.addListener(_filterBoards);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            .select('pins!fk_boards_pins_pin_id(image_url)')
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
    final userProfile = context.watch<UserProfileProvider>();
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: _buildProfileHeader(context, userProfile),
            ),
            SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'My Account'),
                    Tab(text: 'My Boards'),
                    Tab(text: 'My Credits'), // New Tab
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMyAccountTab(userProfile),
            _buildMyBoardsTab(),
            const ReferralScreen(), // New Screen
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserProfileProvider user) {
    final theme = Theme.of(context);
    final userProfileData = user.userProfile;
    final avatarUrl = userProfileData?['avatar_url'] as String?;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                backgroundColor: theme.colorScheme.surface,
                child: avatarUrl == null
                    ? Text(
                        user.username.isNotEmpty
                            ? user.username[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 48,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: -10,
                child: user.isMember
                    ? Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.scaffoldBackgroundColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.6),
                              blurRadius: 12.0,
                              spreadRadius: 3.0,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 32),
                      )
                    : Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.scaffoldBackgroundColor,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.star_rounded,
                                color: Colors.grey[400], size: 32),
                            Icon(Icons.lock,
                                color: Colors.grey[600], size: 14),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(user.username, style: theme.textTheme.headlineMedium),
          Text(
            userProfileData?['email'] ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

   Widget _buildMyAccountTab(UserProfileProvider userProfile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The new animated credit card
          const CreditInfoCard(),
          const SizedBox(height: 16),
          if (!userProfile.isMember) ...[
            _buildMembershipSection(context),
            const SizedBox(height: 16),
          ],
          _buildQuotesCard(context, userProfile),
        ],
      ),
    );
  }
  
  Widget _buildQuotesCard(BuildContext context, UserProfileProvider userProfile) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Quotes', style: theme.textTheme.titleLarge),
                TextButton(
                  onPressed: () { /* TODO: Navigate to Quote History */ },
                  child: const Text('View Detail History'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatRow('Total Quotes:', '6'),
            _buildStatRow('Expired:', '5'),
            _buildStatRow('Valid:', '1'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMyBoardsTab() {
    return Column(
      children: [
        _buildBoardToolbar(),
        Expanded(child: _buildBoardsGrid()),
      ],
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

  Widget _buildMembershipSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Membership Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Eligible for Free Making on Jewelry, Get Discount on Making Charges, Free Jewelry Cleaning, Discount on your Occasions',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BuyMembershipScreen(),
                ),
              ),
              child: const Text('Become a Lifetime Golden Member'),
            ),
          ],
        ),
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
      crossAxisCount: (MediaQuery.of(context).size.width / 250).floor().clamp(
        2,
        5,
      ),
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

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class Board {
  final int id;
  final String name;
  final List<String> coverUrls;
  Board({required this.id, required this.name, this.coverUrls = const []});
}