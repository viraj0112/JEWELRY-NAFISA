import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/auth/signup_screen.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:google_fonts/google_fonts.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const _WelcomeAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 650;
          return SingleChildScrollView(
            child: Column(
              children: [
                _HeroSection(isMobile: isMobile),
                _DynamicJewelrySection(
                  title: 'Featured Boards',
                  future: _featuredItemsFuture,
                  isMobile: isMobile,
                ),
                _DynamicJewelrySection(
                  title: 'Trending Collections',
                  future: _trendingItemsFuture,
                  isMobile: isMobile,
                ),
                const _WelcomeFooter(),
              ],
            ),
          );
        },
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
class _HeroSection extends StatefulWidget {
  final bool isMobile;
  const _HeroSection({this.isMobile = true});

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = widget.isMobile ? size.height * 0.45 : 420.0;

    return FadeTransition(
      opacity: _fade,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              'https://images.unsplash.com/photo-1599351432809-ac94d1784652?w=1600&auto=format&fit=crop&q=80',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: const Color.fromRGBO(0, 0, 0, 0.45),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'NEW COLLECTION',
                  style:
                      Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        letterSpacing: 2,
                      ) ??
                      GoogleFonts.ptSerif(fontSize: 36, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isMobile ? 24 : 80,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(8),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search Filter',
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
  final bool isMobile;

  const _DynamicJewelrySection({
    required this.title,
    required this.future,
    this.isMobile = true,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isMobile ? 16.0 : 48.0;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
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
              // responsive grid: 2 columns on mobile, 3-4 on larger screens
              final crossAxis = isMobile ? 2 : 4;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxis,
                  mainAxisExtent: isMobile ? 260 : 300,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _JewelryCard(item: items[index]),
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: item.id,
                child: Image.network(
                  item.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${item.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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
