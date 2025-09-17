import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/providers/theme_provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/home/home_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/notifications_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/profile_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/search_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/welcome/welcome_screen.dart';
import 'package:jewelry_nafisa/src/widgets/edit_profile_dialog.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

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
    NotificationsScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    await SupabaseAuthService().signOut();
    if (mounted) {
      Provider.of<UserProfileProvider>(context, listen: false).reset();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
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
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelType: NavigationRailLabelType.all,
            leading: _buildLogo(userProfile),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: Text('Search'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: Text('Updates'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('Profile'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
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
    );
  }

  Widget _buildNarrowLayout() {
    return Scaffold(
      extendBody: true,
      appBar: _buildAppBar(isWide: false),
      body: Stack(
        children: [
          _pages.elementAt(_selectedIndex),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                    child: BottomNavigationBar(
                      currentIndex: _selectedIndex,
                      onTap: _onItemTapped,
                      type: BottomNavigationBarType.fixed,
                      backgroundColor: Colors.transparent,
                      elevation: 0.5, 
                      selectedItemColor: Theme.of(context).colorScheme.primary,
                      unselectedItemColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
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
                          icon: Icon(Icons.notifications_outlined),
                          activeIcon: Icon(Icons.notifications),
                          label: 'Updates',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.person_outline),
                          activeIcon: Icon(Icons.person),
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: null,
    );
  }

  PreferredSizeWidget _buildAppBar({required bool isWide}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProfile = Provider.of<UserProfileProvider>(context);
    return AppBar(
      automaticallyImplyLeading: !isWide,
      title: _buildSearchBar(Theme.of(context)),
      actions: [
        IconButton(
          icon: Icon(
            themeProvider.themeMode == ThemeMode.light
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
          ),
          onPressed: () => themeProvider.toggleTheme(),
          tooltip: 'Toggle Theme',
        ),
        _buildProfileMenu(userProfile),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLogo(UserProfileProvider user) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: CircleAvatar(
        backgroundColor: Colors.amberAccent,
        child: user.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black87,
                ),
              )
            : Text(
                user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Search for designs',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildProfileMenu(UserProfileProvider user) {
    final avatarUrl = user.userProfile?['avatar_url'] as String?;
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
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
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
                user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
    );
  }
}
