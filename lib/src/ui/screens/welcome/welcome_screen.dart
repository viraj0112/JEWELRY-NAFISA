import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/auth/signup_screen.dart';
import 'package:jewelry_nafisa/src/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final List<String> _imageUrls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final jsonString = await rootBundle.loadString('assets/result.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      final List<String> allImages = [];
      for (var entry in jsonList) {
        final item = entry as Map<String, dynamic>;
        if (item['images'] != null && item['images'] is List) {
          final images = List<String>.from(
            (item['images'] as List).where(
              (img) => img is String && img.startsWith('http'),
            ),
          );
          allImages.addAll(images);
        }
      }
      final validImages = allImages
          .where(
            (url) =>
                url.toLowerCase().contains('.jpg') ||
                url.toLowerCase().contains('.png'),
          )
          .toSet()
          .toList();
      validImages.shuffle();
      if (mounted) {
        setState(() {
          _imageUrls.addAll(validImages.take(100));
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading images from JSON: $e');
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
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _imageUrls.isEmpty
          ? const Center(child: Text("No images found."))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return isWide ? _buildWideLayout() : _buildNarrowLayout();
              },
            ),
    );
  }

  // --- LAYOUTS ---

  Widget _buildWideLayout() {
    return Row(
      children: [
        _buildNavigationRail(),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: Scaffold(appBar: _buildAppBar(), body: _buildImageGrid()),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(children: [_buildImageGrid(), _buildFloatingNavBar()]),
    );
  }

  // --- NAVIGATION WIDGETS ---

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: 0,
      onDestinationSelected: (index) => _navigateToLogin(),
      labelType: NavigationRailLabelType.all,
      leading: const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Icon(Icons.diamond_outlined, size: 24),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.search_outlined),
          label: Text('Search'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.notifications_outlined),
          label: Text('Updates'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          label: Text('Profile'),
        ),
      ],
    );
  }

  Widget _buildFloatingNavBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24.0),
              ),
              child: BottomNavigationBar(
                currentIndex: 0,
                onTap: (index) => _navigateToLogin(),
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: Theme.of(context).colorScheme.primary,
                unselectedItemColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.6),
                items: const <BottomNavigationBarItem>[
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_filled),
                    activeIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.search_sharp),
                    activeIcon: Icon(Icons.search),
                    label: 'Search',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.notifications_active),
                    activeIcon: Icon(Icons.notifications_active_outlined),
                    label: 'Notifications',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_pin),
                    activeIcon: Icon(Icons.person_pin),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- CORE UI WIDGETS ---

  PreferredSizeWidget _buildAppBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return AppBar(
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
        _buildGuestMenu(context),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        onTap: _navigateToLogin,
        readOnly: true,
        decoration: InputDecoration(
          hintText: 'Search for designs',
          prefixIcon: const Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
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
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: 'login', child: Text('Login')),
        const PopupMenuItem<String>(value: 'register', child: Text('Register')),
      ],
      child: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Text(
          'G',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildFilterTags()),
        SliverPadding(
          padding: const EdgeInsets.all(8.0),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: (MediaQuery.of(context).size.width / 200)
                .floor()
                .clamp(2, 8),
            childCount: _imageUrls.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: _navigateToLogin,
                child: _buildImageCard(context, _imageUrls[index]),
              );
            },
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTags() {
    const tags = ['All', 'Necklaces', 'Rings', 'Bracelets', 'Earrings'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: tags
            .map(
              (tag) => ActionChip(
                label: Text(tag),
                onPressed: _navigateToLogin,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surface.withAlpha((255 * 0.8).round()),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildImageCard(BuildContext context, String imageUrl) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: Theme.of(
              context,
            ).colorScheme.surface.withAlpha((255 * 0.1).round()),
            child: const Center(child: CircularProgressIndicator.adaptive()),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(
              context,
            ).colorScheme.surface.withAlpha((255 * 0.1).round()),
            child: Icon(Icons.error_outline, color: Colors.grey[400]),
          );
        },
      ),
    );
  }
}
