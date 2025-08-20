import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/auth/signup_screen.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final JewelryService _jewelryService = JewelryService();
  late Future<List<JewelryItem>> _featuredItemsFuture;
  late Future<List<JewelryItem>> _trendingItemsFuture;

  @override
  void initState() {
    super.initState();
    _featuredItemsFuture = _jewelryService.fetchJewelryItems(limit: 6);
    _trendingItemsFuture = _jewelryService.fetchJewelryItems(
      limit: 6,
      offset: 6,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const _WelcomeAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _HeroSection(),
            _DynamicJewelrySection(
              title: 'Featured Boards',
              future: _featuredItemsFuture,
            ),
            _DynamicJewelrySection(
              title: 'Trending Collections',
              future: _trendingItemsFuture,
            ),
            const _WelcomeFooter(),
          ],
        ),
      ),
    );
  }
}

// Header Section
class _WelcomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _WelcomeAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      title: Row(
        children: [
          _navButton('Explore'),
          _navButton('Categories'),
          _navButton('Gift Suggestions'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
          child: const Text('LOGIN', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SignUpScreen()),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          child: const Text('REGISTER'),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _navButton(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: TextButton(
        onPressed: () {},
        child: Text(text, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Hero and Search Section
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1599351432809-ac94d1784652?w=1600&auto=format&fit=crop&q=80',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'NEW COLLECTION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: 600,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Search Filter',
                    icon: Icon(Icons.search),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dynamic Section for Jewelry Items
class _DynamicJewelrySection extends StatelessWidget {
  final String title;
  final Future<List<JewelryItem>> future;

  const _DynamicJewelrySection({required this.title, required this.future});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<JewelryItem>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return const Center(child: Text('No items to display.'));
              }

              final items = snapshot.data!;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: items
                    .map((item) => _JewelryCard(item: item))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Jewelry Item Card
class _JewelryCard extends StatelessWidget {
  final JewelryItem item;
  const _JewelryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 200,
        child: Column(
          children: [
            Image.network(item.imageUrl, height: 150, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('\$${item.price.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Footer Section
class _WelcomeFooter extends StatelessWidget {
  const _WelcomeFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _footerLink('Help Center'),
              _footerLink('Contact Us'),
              _footerLink('Blog'),
            ],
          ),
          Row(
            children: [
              _socialIcon(Icons.camera_alt_outlined),
              _socialIcon(Icons.facebook),
              _socialIcon(Icons.all_inclusive_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String text) => Padding(
    padding: const EdgeInsets.only(right: 16),
    child: TextButton(
      onPressed: () {},
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    ),
  );

  Widget _socialIcon(IconData icon) => IconButton(
    onPressed: () {},
    icon: Icon(icon, color: Colors.black54),
  );
}
