import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _featuredItemsFuture = _jewelryService.fetchJewelryItems(limit: 6);
    _trendingItemsFuture = _jewelryService.fetchJewelryItems(
      limit: 6,
      offset: 6,
    );
  }

  // Palette matching the mock
  static const _cream = Color(0xFFF5E8CC);
  static const _creamLight = Color(0xFFF9EDD2);
  static const _gold = Color(0xFFC6A23B);
  static const _goldDark = Color(0xFFB18E2F);
  static const _brownText = Color(0xFF5C432B);
  static const _darkBar = Color(0xFF3A2A1C);

  TextStyle get _serifTitle =>
      GoogleFonts.playfairDisplay(color: _brownText, letterSpacing: 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _creamLight,
      drawer: const _AppDrawer(),
      body: LayoutBuilder(
        builder: (context, c) {
          final isMobile = c.maxWidth < 700;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  isMobile: isMobile,
                  onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ),
              SliverToBoxAdapter(child: _HeroBlock(isMobile: isMobile)),
              SliverToBoxAdapter(child: _CategoriesRow(isMobile: isMobile)),
              SliverToBoxAdapter(child: _WideGoldButtons(isMobile: isMobile)),
              SliverToBoxAdapter(
                child: _DynamicJewelrySection(
                  title: 'Featured Boards',
                  future: _featuredItemsFuture,
                  isMobile: isMobile,
                ),
              ),
              SliverToBoxAdapter(
                child: _DynamicJewelrySection(
                  title: 'Trending Collections',
                  future: _trendingItemsFuture,
                  isMobile: isMobile,
                ),
              ),
              const SliverToBoxAdapter(child: _Footer()),
            ],
          );
        },
      ),
    );
  }
}

// ------------------ HEADER ------------------
class _Header extends StatelessWidget {
  final bool isMobile;
  final VoidCallback onMenuPressed;

  const _Header({required this.isMobile, required this.onMenuPressed});

  static const _gold = _WelcomeScreenState._gold;
  static const _darkBar = _WelcomeScreenState._darkBar;

  @override
  Widget build(BuildContext context) {
    final brand = Text(
      'AKD',
      style: GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
        letterSpacing: 1.2,
      ),
    );

    final nav = Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 8,
      children: [
        _navText('HOME'),
        _navText('EXPLORE'),
        _navText('FEATURED'),
        _navText('TRENDING-DESIGNS'),
      ],
    );

    final auth = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
          child: const Text(
            'LOGIN',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SignUpScreen()),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            elevation: 0,
          ),
          child: const Text('REGISTER'),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: _gold,
            padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: onMenuPressed,
                  tooltip: 'Menu',
                ),
                brand,
                auth,
              ],
            ),
          ),
          Container(height: 6, color: _darkBar),
        ],
      );
    }

    // tablet/desktop
    return Column(
      children: [
        Container(
          color: _gold,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
          ).copyWith(top: 14, bottom: 14),
          child: Row(
            children: [brand, const Spacer(), nav, const Spacer(), auth],
          ),
        ),
        Container(height: 6, color: _darkBar),
      ],
    );
  }

  Widget _navText(String text) => Text(
    text,
    style: GoogleFonts.openSans(
      fontSize: 12,
      color: Colors.black87,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w600,
    ),
  );
}

// ------------------ DRAWER ------------------
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: _WelcomeScreenState._gold),
            child: Text(
              'Menu',
              style: GoogleFonts.playfairDisplay(
                color: Colors.black87,
                fontSize: 28,
              ),
            ),
          ),
          ListTile(title: const Text('HOME'), onTap: () {}),
          ListTile(title: const Text('EXPLORE'), onTap: () {}),
          ListTile(title: const Text('FEATURED'), onTap: () {}),
          ListTile(title: const Text('TRENDING-DESIGNS'), onTap: () {}),
        ],
      ),
    );
  }
}

// ------------------ HERO ------------------
class _HeroBlock extends StatelessWidget {
  final bool isMobile;
  const _HeroBlock({required this.isMobile});

  static const _cream = _WelcomeScreenState._creamLight;
  static const _gold = _WelcomeScreenState._gold;
  static const _brownText = _WelcomeScreenState._brownText;

  @override
  Widget build(BuildContext context) {
    final title1 = Text(
      'WELCOME TO',
      textAlign: TextAlign.center,
      style: GoogleFonts.playfairDisplay(
        fontSize: isMobile ? 18 : 22,
        color: _brownText,
        letterSpacing: 2,
      ),
    );

    final title2 = Text(
      'JEWELLERY',
      textAlign: TextAlign.center,
      style: GoogleFonts.playfairDisplay(
        fontSize: isMobile ? 36 : 54,
        fontWeight: FontWeight.w700,
        color: _brownText,
        letterSpacing: 3,
      ),
    );

    final ring = SizedBox(
      height: isMobile ? 160 : 200,
      child: Image.network(
        'https://images.unsplash.com/photo-1617038260897-3b1382a1eb8a?w=800&auto=format&fit=crop&q=80',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.diamond, size: isMobile ? 120 : 160, color: _gold),
      ),
    );

    final btn = ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        'SHOP NOW',
        style: GoogleFonts.openSans(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );

    return Container(
      color: _cream,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 40,
        vertical: isMobile ? 28 : 36,
      ),
      child: Column(
        children: [
          title1,
          const SizedBox(height: 6),
          title2,
          const SizedBox(height: 16),
          ring,
          const SizedBox(height: 8),
          btn,
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ------------------ CATEGORIES (3 tiles) ------------------
class _CategoriesRow extends StatelessWidget {
  final bool isMobile;
  const _CategoriesRow({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _CategoryTile(
        label: 'RINGS',
        image:
            'https://images.unsplash.com/photo-1522312346375-d1a52e2b99b3?w=1200&auto=format&fit=crop&q=80',
      ),
      _CategoryTile(
        label: 'NECKLACES',
        image:
            'https://images.unsplash.com/photo-1520962918287-7448c2878f65?w=1200&auto=format&fit=crop&q=80',
      ),
      _CategoryTile(
        label: 'EARRINGS',
        image:
            'https://images.unsplash.com/photo-1605100804763-247f67b3557e?w=1200&auto=format&fit=crop&q=80',
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 28,
        vertical: isMobile ? 18 : 24,
      ),
      child: Center(
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: tiles
              .map((t) => SizedBox(width: _tileWidth(context), child: t))
              .toList(),
        ),
      ),
    );
  }

  double _tileWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 700;
    final hPadding = isMobile ? 16.0 : 28.0;
    final spacing = 16.0;

    if (w < 500) return w - hPadding * 2; // 1 column
    if (w < 900) return (w - hPadding * 2 - spacing) / 2; // 2 columns
    return (w - hPadding * 2 - (spacing * 2)) / 3; // 3 columns
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final String image;
  const _CategoryTile({required this.label, required this.image});

  static const _brownText = _WelcomeScreenState._brownText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.brown.shade200,
                child: const Icon(Icons.image, color: Colors.white70, size: 40),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.openSans(
            color: _brownText,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ------------------ WIDE BUTTONS ------------------
class _WideGoldButtons extends StatelessWidget {
  final bool isMobile;
  const _WideGoldButtons({required this.isMobile});

  static const _gold = _WelcomeScreenState._gold;
  static const _goldDark = _WelcomeScreenState._goldDark;

  @override
  Widget build(BuildContext context) {
    final items = ['BRACELETS', 'EARRINGS', 'BRACELETS'];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 28,
        vertical: isMobile ? 8 : 10,
      ),
      child: Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: items
              .map(
                (t) => SizedBox(
                  width: _btnWidth(context),
                  child: ElevatedButton(
                    onPressed: () {},
                    style:
                        ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ).copyWith(
                          overlayColor: WidgetStateProperty.all(_goldDark),
                        ),
                    child: Text(
                      t,
                      style: GoogleFonts.openSans(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  double _btnWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 700;
    final hPadding = isMobile ? 16.0 : 28.0;
    final spacing = 12.0;

    if (w < 500) return w - hPadding * 2; // 1 column
    if (w < 900) return (w - hPadding * 2 - spacing) / 2; // 2 columns
    return (w - hPadding * 2 - (spacing * 2)) / 3; // 3 columns
  }
}

// ------------------ DYNAMIC SECTIONS ------------------
class _DynamicJewelrySection extends StatelessWidget {
  final String title;
  final Future<List<JewelryItem>> future;
  final bool isMobile;

  const _DynamicJewelrySection({
    required this.title,
    required this.future,
    required this.isMobile,
  });

  static const _brownText = _WelcomeScreenState._brownText;

  @override
  Widget build(BuildContext context) {
    final padH = isMobile ? 16.0 : 28.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(padH, 22, padH, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.w700,
              color: _brownText,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<JewelryItem>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No items to display.'),
                  ),
                );
              }

              final items = snapshot.data!;
              final w = MediaQuery.of(context).size.width;
              int crossAxisCount = 4;
              if (w < 500)
                crossAxisCount = 2;
              else if (w < 900)
                crossAxisCount = 3;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: isMobile ? 250 : 280,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => _JewelryCard(item: items[i]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _JewelryCard extends StatelessWidget {
  final JewelryItem item;
  const _JewelryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.brown.shade200,
                    child: const Icon(Icons.image, color: Colors.white70),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: DefaultTextStyle(
                style: GoogleFonts.openSans(color: Colors.black87),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('\$${item.price.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------ FOOTER ------------------
class _Footer extends StatelessWidget {
  const _Footer();

  static const _darkBar = _WelcomeScreenState._darkBar;
  static const _gold = _WelcomeScreenState._gold;

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to create a responsive layout
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 800;

        return Container(
          color: _darkBar,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
        );
      },
    );
  }

  // Layout for wide screens (tablets, desktops)
  Widget _buildWideLayout() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2, // Contact form takes more space
          child: _ContactUsForm(),
        ),
        SizedBox(width: 48), // Spacer between columns
        Expanded(
          flex: 2, // Links and social icons
          child: _LinksAndSocial(),
        ),
      ],
    );
  }

  // Layout for narrow screens (mobile)
  Widget _buildNarrowLayout() {
    return const Column(
      children: [
        _ContactUsForm(),
        Divider(color: Colors.white24, height: 48),
        _LinksAndSocial(),
      ],
    );
  }

  // Extracted Links and Social Icons for reusability
  static Widget _icon(IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: _gold,
          child: Icon(icon, size: 16, color: Colors.black),
        ),
      );

  static Widget _link(String text) => TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Text(
          text,
          style: GoogleFonts.openSans(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 0.6,
          ),
        ),
      );
}

// Widget for all the links and social media icons
class _LinksAndSocial extends StatelessWidget {
  const _LinksAndSocial();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(height: 16),
        Wrap(
          spacing: 18,
          alignment: WrapAlignment.start,
          children: [
            _Footer._link('ABOUT US'),
            _Footer._link('BLOG'),
            _Footer._link('CAREERS'),
            _Footer._link('AFFILIATES'),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 18,
          alignment: WrapAlignment.start,
          children: [
            _Footer._link('TERMS OF SERVICE'),
            _Footer._link('PRIVACY POLICY'),
            _Footer._link('SHIPPING & RETURNS'),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Footer._icon(Icons.camera_alt_outlined),
            _Footer._icon(Icons.facebook),
            _Footer._icon(Icons.all_inclusive_outlined),
          ],
        ),
      ],
    );
  }
}


// --- The ContactUsForm remains the same ---
class _ContactUsForm extends StatefulWidget {
  const _ContactUsForm();

  @override
  State<_ContactUsForm> createState() => _ContactUsFormState();
}

class _ContactUsFormState extends State<_ContactUsForm> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Contact Us',
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Name'),
            validator: (v) => v!.isEmpty ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Email'),
            validator: (v) =>
                v!.isEmpty || !v.contains('@') ? 'Please enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Message'),
            maxLines: 3,
            validator: (v) => v!.isEmpty ? 'Please enter your message' : null,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thank you for your message!')),
                );
                _formKey.currentState!.reset();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _WelcomeScreenState._gold,
              foregroundColor: Colors.black,
            ),
            child: const Text('Send Message'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _WelcomeScreenState._gold),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white54),
      ),
    );
  }
}