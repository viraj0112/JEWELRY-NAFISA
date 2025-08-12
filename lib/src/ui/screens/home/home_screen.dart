import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:math';

import 'package:jewelry_nafisa/src/auth/firebase_auth_service.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/profile_screen.dart'; // Import the new profile screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final _imageList = <String>[];
  final _random = Random();
  // Service for handling sign out
  final FirebaseAuthService _authService = FirebaseAuthService();

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
    for (int i = 0; i < 10; i++) {
      final imageId = _random.nextInt(1000);
      _imageList.add('https://picsum.photos/id/$imageId/200/300');
    }
    setState(() {});
  }

  // New method to build the category filter chips
  Widget _buildCategoryFilters() {
    // Dummy categories based on your screenshot
    final categories = ['All', 'Necklace', 'Earring', 'Ring', 'Wedding Jewellery'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: categories.map((category) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Chip(
              label: Text(category),
              backgroundColor:
                  category == 'All' ? Colors.black : Colors.grey[200],
              labelStyle: TextStyle(
                color: category == 'All' ? Colors.white : Colors.black,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // The title is now a custom search bar
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            ),
          ),
        ),
        actions: [
          // Profile Button
          IconButton(
            icon: const Icon(Icons.person, color: Colors.black54),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              ));
            },
          ),
          // Logout Button (You can keep this here or just have it in the profile screen)
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: () async {
              // The AuthGate will automatically navigate to the LoginScreen
              await _authService.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Add the category filters below the AppBar
          _buildCategoryFilters(),
          // The grid now takes the remaining space
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount;
                if (constraints.maxWidth > 1200) {
                  crossAxisCount = 5;
                } else if (constraints.maxWidth > 800) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth > 500) {
                  crossAxisCount = 3;
                } else {
                  crossAxisCount = 2;
                }

                return MasonryGridView.count(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8.0), // Added padding
                  crossAxisCount: crossAxisCount,
                  itemCount: _imageList.length,
                  itemBuilder: (context, index) {
                    return Card(
                      clipBehavior: Clip.antiAlias, // For rounded corners
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.network(
                            _imageList[index],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                    ? child
                                    : const AspectRatio(
                                        aspectRatio: 2 / 3,
                                        child: Center(
                                            child: CircularProgressIndicator()),
                                      ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Image $index'),
                          ),
                        ],
                      ),
                    );
                  },
                  mainAxisSpacing: 8.0, // Increased spacing
                  crossAxisSpacing: 8.0, // Increased spacing
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}