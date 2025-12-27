import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/providers/theme_provider.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:jewelry_nafisa/src/ui/screens/info_screen.dart';
import 'package:jewelry_nafisa/src/widgets/account_management_dialog.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/boards_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/home/home_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/notifications_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/profile_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/search_screen.dart';
import 'package:jewelry_nafisa/src/widgets/edit_profile_dialog.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:jewelry_nafisa/src/ui/widgets/search_dropdown.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/ui/theme/app_theme.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({
    super.key,
    required this.navigationShell,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _searchController = TextEditingController();

  // Search state management
  List<JewelryItem> _searchResults = [];
  String _currentSearchQuery = '';
  bool _isSearchMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    // Ignore taps on the Info button (index 4) if it's just a placeholder for the menu
    // But if we want it to be a real tab, we can navigate.
    // Based on previous code, index 4 was "Profile" in bottom nav but "Info" in rail.
    // And it had a special handler in the app bar.
    
    // For now, let's allow navigation to all tabs defined in branches.
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _signOut() async {
    try {
      await Provider.of<ThemeProvider>(context, listen: false).setThemeMode(ThemeMode.light);

      await SupabaseAuthService().signOut();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Provider.of<UserProfileProvider>(context, listen: false).reset();

        });
        
        context.go('/welcome');

      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
    }
  }

  // Handle search results from SearchDropdown
  void _onSearchResults(List<JewelryItem> results, String query) {
    setState(() {
      _searchResults = results;
      _currentSearchQuery = query;
      _isSearchMode = true;
      // Navigate to search screen (index 2)
      widget.navigationShell.goBranch(2);
    });
  }

  // Clear search
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _currentSearchQuery = '';
      _isSearchMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return isWide ? _buildWideLayout() : _buildNarrowLayout();
      },
    );
  }

 Widget _buildNarrowLayout() {
  // Removed PopScope to allow GoRouter to handle back navigation
  return Scaffold(
    appBar: _buildAppBar(isWide: false, selectedIndex: widget.navigationShell.currentIndex),
    body: _buildContent(),
    bottomNavigationBar: _buildFixedNavBar(),
  );
}

  Widget _buildWideLayout() {
    final userProfile = Provider.of<UserProfileProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NavigationRail(
              selectedIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: _onItemTapped,
              labelType: NavigationRailLabelType.all,
              leading: _buildLogo(userProfile),
              indicatorColor: Colors.transparent,
              selectedIconTheme: IconThemeData(
                color: theme.colorScheme.primary,
              ),
              unselectedIconTheme: IconThemeData(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              selectedLabelTextStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              unselectedLabelTextStyle: TextStyle(
                fontWeight: FontWeight.normal,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bookmark_add_outlined),
                  selectedIcon: Icon(Icons.bookmark_add),
                  label: Text('Boards'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.search),
                  selectedIcon: Icon(Icons.search),
                  label: Text('Search'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: Text('Notifications'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.chat_bubble_outline_outlined),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: Text('Info'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 16),
            Expanded(
              child: Column(
                children: [
                  _buildAppBar(isWide: true, selectedIndex: widget.navigationShell.currentIndex),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isSearchMode && widget.navigationShell.currentIndex == 2) {
      return _buildSearchResults();
    }
    // Return the child from StatefulShellRoute
    return widget.navigationShell;
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "$_currentSearchQuery"',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clearSearch,
              child: const Text('Clear search'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search results header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Search results for "$_currentSearchQuery" (${_searchResults.length} items)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              IconButton(
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear),
                tooltip: 'Clear search',
              ),
            ],
          ),
        ),
        // Search results grid
        Expanded(
          child: MasonryGridView.count(
            padding: const EdgeInsets.all(8.0),
            crossAxisCount:
                (MediaQuery.of(context).size.width / 200).floor().clamp(2, 6),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              return _buildImageCard(context, _searchResults[index]);
            },
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
          ),
        ),
      ],
    );
  }

  Widget _buildImageCard(BuildContext context, JewelryItem item) {
    return GestureDetector(
      onTap: () {
        // Use GoRouter to push the product page
        context.push('/product/${item.id}');
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: item.aspectRatio,
          child: Image.network(
            item.image,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator.adaptive()),
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.error_outline, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildFixedNavBar() {
    final theme = Theme.of(context);
    final  customGreen = const Color(0xFF336B43);
    return BottomNavigationBar(
      currentIndex: widget.navigationShell.currentIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor: customGreen,
      elevation: 8.0,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark_add_outlined),
          activeIcon: Icon(Icons.bookmark_add),
          label: 'Boards',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search_outlined),
          activeIcon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications),
          label: 'Notifications',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: 'Info',
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(
      {required bool isWide, required int selectedIndex}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProfile = Provider.of<UserProfileProvider>(context);
    final theme = Theme.of(context);

    final bool isSearchScreen = selectedIndex == 2;
    final bool isBoardsScreen = selectedIndex == 1;
    final bool isNotificationScreen = selectedIndex == 3;
    final bool isInfoScreen = selectedIndex == 4;

    final bool shouldHideSearchBar = isSearchScreen ||
        isBoardsScreen ||
        isNotificationScreen ||
        isInfoScreen;

    return AppBar(
      automaticallyImplyLeading: !isWide,
      titleSpacing: 16.0,
      elevation: 0,
      backgroundColor: Color(0xFF336B43),
      title: shouldHideSearchBar ? null : _buildSearchBar(),
      actions: [
    
        _buildClickableProfileAvatar(userProfile),
        _buildProfileDropdown(userProfile),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildLogo(UserProfileProvider user) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 52.0),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Color(0xFF006435) ,
        // --- FIX: Removed user.isLoading check ---
        child: Text(
          user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        // --- END FIX ---
      ),
    );
  }

  Widget _buildSearchBar() {
    return SearchDropdown(
      searchController: _searchController,
      onSearchResults: _onSearchResults,
    );
  }

  Widget _buildClickableProfileAvatar(UserProfileProvider user) {
    final avatarUrl = user.userProfile?.avatarUrl;
    return GestureDetector(
      onTap: () {
        _onItemTapped(4);
      },
      child: CircleAvatar(
        backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
        backgroundColor: Theme.of(context).colorScheme.primary,
        // --- FIX: Removed user.isLoading check ---
        child: (avatarUrl == null)
            ? Text(
                user.username.isNotEmpty
                    ? user.username[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
        // --- END FIX ---
      ),
    );
  }

  Widget _buildProfileDropdown(UserProfileProvider user) {
    final avatarUrl = user.userProfile?.avatarUrl;
    final bool isMember = user.userProfile?.role == UserRole.member;
    final themeProvider = Provider.of<ThemeProvider>(context); // Add this line

    return PopupMenuButton<String>(
      tooltip: 'Profile Menu',
      offset: const Offset(0, 50),
      onSelected: (value) {
        switch (value) {
          case 'edit_profile':
            showDialog(
              context: context,
              builder: (context) => const EditProfileDialog(),
            );
            break;
          case 'change_password':
            showDialog(
              context: context,
              builder: (context) => const AccountManagementDialog(),
            );
            break;
        // Inside MainShell -> _buildProfileDropdown
               case 'my_profile':
  Navigator.of(context).push(
    MaterialPageRoute(builder: (context) => const ProfileScreen()),
  );

            
          // case 'toggle_theme':  // Add this case
          // themeProvider.toggleTheme();
          break;
          // case 'request_business_account':
          //   _handleBusinessRequest(context);
          //   break;
          case 'logout':
            _signOut();
            break;
        }
      },
      icon: Icon(
        Icons.arrow_drop_down,
        color: Colors.white,
      ),
      itemBuilder: (BuildContext context) {
        List<PopupMenuEntry<String>> items = [
          PopupMenuItem<String>(
            enabled: false,
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: (avatarUrl == null)
                    ? Text(
                        user.username.isNotEmpty
                            ? user.username[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              ),
              title: Text(
                user.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(user.isMember ? 'Premium Member' : 'Free Account'),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'edit_profile',
            child: Text('Edit Profile'),
          ),
          const PopupMenuItem<String>(
            value: 'change_password',
            child: Text('Change Password'),
          ),
           const PopupMenuItem<String>(
            value: 'my_profile',
            child: Text('My Profile'),
          ),
        //   const PopupMenuDivider(),  // Add divider
        // PopupMenuItem<String>(  // Add theme toggle option
        //   value: 'toggle_theme',
        //   child: Row(
        //     children: [
        //       Icon(
        //         themeProvider.themeMode == ThemeMode.light
        //             ? Icons.dark_mode_outlined
        //             : Icons.light_mode_outlined,
        //       ),
        //       const SizedBox(width: 12),
        //       Text(
        //         themeProvider.themeMode == ThemeMode.light
        //             ? 'Dark Mode'
        //             : 'Light Mode',
        //       ),
        //     ],
        //   ),
        // ),
        ];

        // Conditionally add the business request item
        // if (isMember) {
        //   items.add(
        //     const PopupMenuItem<String>(
        //       value: 'request_business_account',
        //       child: Text('Request Business Account'),
        //     ),
        //   );
        // }

        items.addAll([
          const PopupMenuDivider(),
          const PopupMenuItem<String>(value: 'logout', child: Text('Log out')),
        ]);

        return items;
      },
    );
  }
}