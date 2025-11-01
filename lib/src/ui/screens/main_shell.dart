import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/providers/theme_provider.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';
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
import 'package:jewelry_nafisa/src/ui/widgets/search_overlay.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final _searchController = TextEditingController();
  late final List<Widget> _pages;
  // static const List<Widget> _pages = <Widget>[
  //   HomeScreen(),
  //   SearchScreen(),
  //   BoardsScreen(),
  //   NotificationsScreen(),
  //   ProfileScreen(),
  // ];

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      const HomeScreen(), 
      SearchScreen(searchController: _searchController),
      const BoardsScreen(), 
      const NotificationsScreen(), 
      const ProfileScreen(), 
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    try {
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

  Future<void> _handleBusinessRequest(BuildContext context) async {
    // Show a confirmation dialog first
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Business Account?'),
        content: const Text(
            'Your account will be submitted for approval. You will be notified once a decision is made.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await context.read<UserProfileProvider>().requestBusinessAccount();
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExitConfirmationDialog(BuildContext context) {
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Exit App?'),
          content: const Text('Are you sure you want to exit Dagina Designs?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(), // Dismiss dialog
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true), // Allow pop/exit
              child: const Text('Exit'),
            ),
          ],
        ),
      ).then((confirmed) {
        if (confirmed == true && mounted) {
          SystemNavigator.pop();
        }
      });
    }
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

  Widget _buildWideLayout() {
    final userProfile = Provider.of<UserProfileProvider>(context);
    final theme = Theme.of(context);

    // The problematic PopScope has been removed from here
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
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
                  icon: Icon(Icons.search),
                  selectedIcon: Icon(Icons.search),
                  label: Text('Search'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.add_box_outlined),
                  selectedIcon: Icon(Icons.add_box_rounded),
                  label: Text('Boards'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: Text('Notifications'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 16),
            Expanded(
              child: Column(
                children: [
                  _buildAppBar(isWide: true, selectedIndex: _selectedIndex),
                  Expanded(child: _pages.elementAt(_selectedIndex)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          _onItemTapped(0);
        } else {
          _showExitConfirmationDialog(context);
        }
      },
      child: Scaffold(
        // The Scaffold no longer handles the pop directly
        appBar: _buildAppBar(isWide: false, selectedIndex: _selectedIndex),
        body: _pages.elementAt(_selectedIndex),
        bottomNavigationBar: _buildFixedNavBar(),
      ),
    );
    // The problematic PopScope has been removed from here
    // return Scaffold(
    //  appBar: _buildAppBar(isWide: false, selectedIndex: _selectedIndex),
    //   body: _pages.elementAt(_selectedIndex),
    //   bottomNavigationBar: _buildFixedNavBar(),
    // );
  }

  Widget _buildFixedNavBar() {
    final theme = Theme.of(context);
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor: theme.colorScheme.surface,
      elevation: 8.0,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search_outlined),
          activeIcon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_box_outlined),
          activeIcon: Icon(Icons.add_box_rounded),
          label: 'Boards',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications),
          label: 'Notifications',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(
      {required bool isWide, required int selectedIndex}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProfile = Provider.of<UserProfileProvider>(context);
    final theme = Theme.of(context);

    final bool isSearchScreen = selectedIndex == 1;
    final bool isBoardsScreen = selectedIndex == 2;
    final bool isNotificationScreen = selectedIndex == 3;
    final bool isProfileScreen = selectedIndex == 4;

    final bool shouldHideSearchBar = isSearchScreen ||
        isBoardsScreen ||
        isNotificationScreen ||
        isProfileScreen;
    return AppBar(
      automaticallyImplyLeading: !isWide,
      titleSpacing: 16.0,
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      title: shouldHideSearchBar ? null : _buildSearchBar(theme),
      actions: [
        IconButton(
          icon: Icon(
            themeProvider.themeMode == ThemeMode.light
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => themeProvider.toggleTheme(),
          tooltip: 'Toggle Theme',
        ),
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
        backgroundColor: const Color(0xFFDAB766),
        child: user.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    // It's no longer an InkWell, it's a TextField
    return TextField(
      controller: _searchController, // <-- Use the shared controller
      decoration: InputDecoration(
        hintText: 'Search',
        prefixIcon: Icon(
          Icons.search,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        fillColor: theme.splashColor,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      ),
      onTap: () {
        // 6. When the user taps the bar, navigate to the search screen
        _onItemTapped(1);
      },
      onSubmitted: (query) {
        // 7. When the user hits "enter" on the keyboard:
        //    The controller already has the text.
        //    The SearchScreen is already listening and searching.
        //    We just need to make sure we are on the SearchScreen.
        _onItemTapped(1);
      },
    );
  }

  Widget _buildClickableProfileAvatar(UserProfileProvider user) {
    final avatarUrl = user.userProfile?.avatarUrl;
    return GestureDetector(
      onTap: () {
        _onItemTapped(4);
      },
      child: CircleAvatar(
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: user.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : (avatarUrl == null)
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
      ),
    );
  }

  Widget _buildProfileDropdown(UserProfileProvider user) {
    final avatarUrl = user.userProfile?.avatarUrl;
    final bool isMember = user.userProfile?.role == UserRole.member;
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
          case 'account_management':
            showDialog(
              context: context,
              builder: (context) => const AccountManagementDialog(),
            );
            break;
          case 'request_business_account':
            _handleBusinessRequest(context);
            break;
          case 'logout':
            _signOut();
            break;
        }
      },
      icon: Icon(
        Icons.arrow_drop_down,
        color: Theme.of(context).colorScheme.onSurface,
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
            value: 'account_management',
            child: Text('Account Management'),
          ),
        ];

        // Conditionally add the business request item
        if (isMember) {
          items.add(
            const PopupMenuItem<String>(
              value: 'request_business_account',
              child: Text('Request Business Account'),
            ),
          );
        }

        items.addAll([
          const PopupMenuDivider(),
          const PopupMenuItem<String>(value: 'logout', child: Text('Log out')),
        ]);

        return items;
      },
    );
  }
}
