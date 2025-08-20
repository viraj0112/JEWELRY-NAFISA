import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/membership/buy_membership_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/profile_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/welcome/welcome_screen.dart';
import 'package:jewelry_nafisa/src/ui/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final _imageList = <String>[];
  final _random = Random();
  final SupabaseAuthService _authService = SupabaseAuthService();

  @override
  void initState() {
    super.initState();
    _loadMoreImages();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMoreImages();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMoreImages() {
    // Placeholder to load more images
    for (int i = 0; i < 15; i++) {
      final imageId = _random.nextInt(1000);
      _imageList.add('https://picsum.photos/id/$imageId/400/${_random.nextInt(200) + 400}');
    }
    if(mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = Provider.of<UserProfileProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: _buildSearchBar(theme),
        actions: [
          _buildUserProfileDropdown(context, userProfile),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = (constraints.maxWidth / 200).floor().clamp(2, 6);
          return MasonryGridView.count(
            controller: _scrollController,
            padding: const EdgeInsets.all(8.0),
            crossAxisCount: crossAxisCount,
            itemCount: _imageList.length,
            itemBuilder: (context, index) {
              return _buildImageCard(context, index, 'Item $index');
            },
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.grey.shade200
            : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search for designs',
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface.withOpacity(0.6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildUserProfileDropdown(BuildContext context, UserProfileProvider user) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      icon: CircleAvatar(
        backgroundColor: AppTheme.darkGoldenrod,
        child: Text(
          user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      onSelected: (value) async {
        if (value == 'profile') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
        } else if (value == 'logout') {
          await _authService.signOut();
          if (mounted) {
            Provider.of<UserProfileProvider>(context, listen: false).reset();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              (route) => false,
            );
          }
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('View Profile'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log Out'),
          ),
        ),
      ],
    );
  }

  Widget _buildImageCard(BuildContext context, int index, String itemName) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => JewelryDetailScreen(
              imageUrl: _imageList[index],
              itemName: itemName,
            ),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        child: Image.network(
          _imageList[index],
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : Container(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}