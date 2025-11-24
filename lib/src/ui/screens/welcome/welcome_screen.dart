import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/auth/signup_screen.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/providers/theme_provider.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final List<JewelryItem> Jeweleries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }
Future<void> _loadImages() async {
  if (!mounted) return;
  setState(() => _isLoading = true);

  try {
    final jewelryService = JewelryService(Supabase.instance.client);
    final products = await jewelryService.getProducts(limit: 100);

    // Remove duplicates based on image
    final uniqueProducts = {
      for (var p in products) p.image: p
    }.values.toList();

    uniqueProducts.shuffle();

    if (mounted) {
      setState(() {
        Jeweleries.clear();
        Jeweleries.addAll(uniqueProducts);
        _isLoading = false;
      });
    }
  } catch (e) {
    debugPrint('Error loading images from Supabase: $e');
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}


  void _navigateToLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _navigateToRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignUpScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Jeweleries.isEmpty
              ? const Center(child: Text("No images found."))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    return isWide ? _buildWideLayout() : _buildNarrowLayout();
                  },
                  ),
        ),
      );
    }

  // ... The rest of the file remains the same, no changes needed below this line
  // ... (Omitting the rest of the build methods for brevity as they are unchanged)

  Widget _buildWideLayout() {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // _buildNavigationRail(),
            // const VerticalDivider(thickness: 1, width: 16),
            Expanded(
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(child: _buildImageGrid()),
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
      appBar: _buildAppBar(),
      body: _buildImageGrid(),
      // bottomNavigationBar: _buildFixedNavBar(),
    );
  }

  Widget _buildNavigationRail() {
    final theme = Theme.of(context);

    return NavigationRail(
      selectedIndex: 0,
      onDestinationSelected: (index) => _navigateToLogin(),
      labelType: NavigationRailLabelType.all,
      useIndicator: true,
      indicatorColor: Colors.transparent,
      selectedLabelTextStyle: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 52.0),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFDAB766),
          child: Text(
            'G',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
      unselectedIconTheme: IconThemeData(
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      ),
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
          icon: Icon(Icons.add_box_outlined),
          selectedIcon: Icon(Icons.add_box_rounded),
          label: Text('Boards'),
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
    );
  }

  // Widget _buildFixedNavBar() {
  //   final theme = Theme.of(context);
  //   return BottomNavigationBar(
  //     currentIndex: 0,
  //     onTap: (index) => _navigateToLogin(),
  //     type: BottomNavigationBarType.fixed,
  //     backgroundColor: theme.colorScheme.surface,
  //     elevation: 8.0,
  //     selectedItemColor: theme.colorScheme.primary,
  //     unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
  //     items: const <BottomNavigationBarItem>[
  //       BottomNavigationBarItem(
  //         icon: Icon(Icons.home_outlined),
  //         activeIcon: Icon(Icons.home),
  //         label: 'Home',
  //       ),
  //       BottomNavigationBarItem(
  //         icon: Icon(Icons.search_outlined),
  //         activeIcon: Icon(Icons.search),
  //         label: 'Search',
  //       ),
  //       BottomNavigationBarItem(
  //         icon: Icon(Icons.add_box_outlined),
  //         activeIcon: Icon(Icons.add_box_rounded),
  //         label: 'Boards',
  //       ),
  //       BottomNavigationBarItem(
  //         icon: Icon(Icons.notifications_outlined),
  //         activeIcon: Icon(Icons.notifications),
  //         label: 'Notifications',
  //       ),
  //       BottomNavigationBarItem(
  //         icon: Icon(Icons.person_outline),
  //         activeIcon: Icon(Icons.person),
  //         label: 'Profile',
  //       ),
  //     ],
  //   );
  // }

  PreferredSizeWidget _buildAppBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);

  return AppBar(
  automaticallyImplyLeading: false,
  titleSpacing: 16.0,
  elevation: 0,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  title: Row(
    children: [
      Image.asset(
        'icons/DDlogo.png',   // <- your logo path
        height: 32,
      ),
      const SizedBox(width: 12),
      Expanded(child: _buildSearchBar(Theme.of(context))),
    ],
  ),
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
    _buildGuestMenu(context),
    const SizedBox(width: 12),
  ],
);

  }

  Widget _buildSearchBar(ThemeData theme) {
    return InkWell(
      onTap: _navigateToLogin,
      borderRadius: BorderRadius.circular(12.0),
      autofocus: true,
      hoverColor: Colors.grey.withOpacity(0.5),
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
              'Search for designs',
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

  Widget _buildGuestMenu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      offset: const Offset(0, 50),
      onSelected: (value) {
        if (value == 'login') {
          _navigateToLogin();
        } else if (value == 'register') {
          _navigateToRegister();
        }
      },
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Text(
              'G',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: 'login', child: Text('Login')),
        const PopupMenuItem<String>(value: 'register', child: Text('Register')),
      ],
    );
  }

  Widget _buildImageGrid() {
  return CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.all(8.0),
        sliver: SliverMasonryGrid.count(
          crossAxisCount:
              (MediaQuery.of(context).size.width / 200).floor().clamp(2, 8),
          childCount: Jeweleries.length,
          itemBuilder: (context, index) {
            final item = Jeweleries[index];
            return _buildImageCard(context, item);
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JewelryDetailScreen(jewelryItem: item),
      ),
    );
  },
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: item.aspectRatio,
        child: Image.network(
          item.image,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.1),
              child: const Center(child: CircularProgressIndicator.adaptive()),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.1),
            child: Icon(Icons.error_outline, color: Colors.grey[400]),
          ),
        ),
      ),
    ),
  );
}
}
