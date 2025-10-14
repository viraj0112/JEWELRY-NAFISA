import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/providers/theme_provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/boards_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/home/home_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/notifications_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/profile_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/search_screen.dart';
import 'package:jewelry_nafisa/src/widgets/edit_profile_dialog.dart';
import 'package:provider/provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    SearchScreen(),
    BoardsScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

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
                  _buildAppBar(isWide: true),
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
    return Scaffold(
      appBar: _buildAppBar(isWide: false),
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: _buildFixedNavBar(),
    );
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

  PreferredSizeWidget _buildAppBar({required bool isWide}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProfile = Provider.of<UserProfileProvider>(context);
    final theme = Theme.of(context);

    return AppBar(
      automaticallyImplyLeading: !isWide,
      titleSpacing: 16.0,
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      title: _buildSearchBar(theme),
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
    return InkWell(
      onTap: () {
        _onItemTapped(1);
      },
      hoverColor: Colors.grey.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: theme.splashColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: theme.dividerColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 8.0),
            Text(
              'Search',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 16.0,
              ),
            ),
          ],
        ),
      ),
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
          case 'logout':
            _signOut();
            break;
        }
      },
      icon: Icon(
        Icons.arrow_drop_down,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
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
        const PopupMenuItem<String>(value: 'logout', child: Text('Log out')),
      ],
    );
  }
}
