import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:math';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/membership/buy_membership_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final _imageList = <String>[];
  final _random = Random();
  bool _isLoggingOut = false;
  final SupabaseAuthService _authService = SupabaseAuthService();

  // --- NEW: LOGIC FOR MEMBERSHIP GATE & QUOTES ---
  void _onGetQuotePressed(BuildContext context) {
    final profile = Provider.of<UserProfileProvider>(context, listen: false);

    if (profile.isMember) {
      if (profile.creditsRemaining > 0) {
        _useQuoteCredit(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are out of quotes for today!')),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Member Exclusive"),
          content: const Text(
            "Getting a quote is a premium feature available only to lifetime members.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Maybe Later"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BuyMembershipScreen(),
                  ),
                );
              },
              child: const Text("Upgrade Now"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _useQuoteCredit(BuildContext context) async {
    final profile = Provider.of<UserProfileProvider>(context, listen: false);
    final supabase = Supabase.instance.client;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // Call the Supabase RPC function
      await supabase.rpc('decrement_credit');

      // Update the UI immediately
      profile.decrementCredit();

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Quote request sent! One credit used.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Error using quote credit: $e");
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Could not get quote. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
    final categories = [
      'All',
      'Necklace',
      'Earring',
      'Ring',
      'Wedding Jewellery',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: categories.map((category) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Chip(
              label: Text(category),
              backgroundColor: category == 'All'
                  ? Colors.black
                  : Colors.grey[200],
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 11,
              ),
            ),
          ),
        ),
        actions: [
          // --- NEW: CREDITS UI ---
          Consumer<UserProfileProvider>(
            builder: (context, profile, child) {
              if (profile.isLoading || !profile.isMember) {
                return const SizedBox.shrink(); // Hide if loading or not a member
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: Chip(
                    avatar: const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 18,
                    ),
                    label: Text('${profile.creditsRemaining} Left'),
                  ),
                ),
              );
            },
          ),
          // --- END OF CREDITS UI ---
          IconButton(
            icon: const Icon(Icons.person, color: Colors.black54),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          if (_isLoggingOut)
            const Padding(
              padding: EdgeInsets.all(10.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: () async {
                setState(() {
                  _isLoggingOut = true;
                });
                // Get provider before async operation
                final profile = Provider.of<UserProfileProvider>(
                  context,
                  listen: false,
                );
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                try {
                  await _authService.signOut();
                  // Reset local provider state after successful sign out
                  profile.reset();
                } catch (e) {
                  debugPrint("Error during sign out: $e");
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text("Error signing out. Please try again."),
                      ),
                    );
                    setState(() {
                      _isLoggingOut = false;
                    });
                  }
                }
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
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => JewelryDetailScreen(
                              imageUrl: _imageList[index],
                              itemName:
                                  'Image $index', // You'll replace this with real data later
                            ),
                          ),
                        );
                      },
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          alignment: Alignment.bottomCenter,
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
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.center,
                                  colors: [
                                    Colors.black.withAlpha(153),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Image $index',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _onGetQuotePressed(context),
                                      icon: const Icon(
                                        // Icons.request_quote_outlined,
                                        Icons.remove_red_eye_sharp,
                                        size: 16,
                                      ),
                                      label: const Text('Get Details'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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
