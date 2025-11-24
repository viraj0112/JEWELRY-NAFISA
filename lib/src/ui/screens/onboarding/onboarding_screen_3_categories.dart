// onboarding_screen_3_categories.dart 

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';

class OnboardingScreen3Categories extends StatefulWidget {
  const OnboardingScreen3Categories({super.key});

  @override
  State<OnboardingScreen3Categories> createState() =>
      _OnboardingScreen3CategoriesState();
}

class _OnboardingScreen3CategoriesState
    extends State<OnboardingScreen3Categories>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedCategories = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late ScrollController _scrollController;

  // IMPORTANT: All image paths must be valid network URLs now.
  final List<Map<String, dynamic>> categoryOptions = [
    {
      'name': 'Rings',
      'image': 'https://images.unsplash.com/photo-1598560917807-1bae44bd2be8?q=80&w=880&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      'gradient': [const Color(0xFF006435), const Color(0xFF00854D)],
    },
    {
      'name': 'Necklaces',
      'image': 'https://images.unsplash.com/photo-1635767798638-3e25273a8236?q=80&w=764&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      'gradient': [const Color(0xFF4A9D6F), const Color(0xFF66BB94)],
    },
    {
      'name': 'Earrings',
      'image': 'https://images.unsplash.com/photo-1561172478-a203d9c8290e?q=80&w=687&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      'gradient': [const Color(0xFF2E7D52), const Color(0xFF52A876)],
    },
    {
      'name': 'Bracelets',
      'image':'https://images.unsplash.com/photo-1619119069152-a2b331eb392a?q=80&w=1171&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      'gradient': [const Color(0xFF1B5E3A), const Color(0xFF4A9D6F)],
    },
    {
      'name': 'Pendants',
      'image': 'https://plus.unsplash.com/premium_photo-1681276170092-446cd1b5b32d?q=80&w=688&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      'gradient': [const Color(0xFF52A876), const Color(0xFF81C9A8)],
    },
    {
      'name': 'Custom Design',
      'image': 'https://images.unsplash.com/photo-1692421098809-6cdfcfea289a?q=80&w=880&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      'gradient': [const Color(0xFF66BB94), const Color(0xFF9FD4B8)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- FIX 2 & 3: Correct parameter names and type conversion ---
  void _finishSetup() async {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one category'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final provider = Provider.of<UserProfileProvider>(context, listen: false);

    await provider.saveOnboardingData(
  categories: _selectedCategories, // ✅ Already a Set
  isFinalSubmission: true,
);

    if (mounted) {
      GoRouter.of(context).go('/');
    }
  }

  void _toggleSelection(String categoryName) {
    setState(() {
      if (_selectedCategories.contains(categoryName)) {
        _selectedCategories.remove(categoryName);
      } else {
        _selectedCategories.add(categoryName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isTablet = size.width > 600 && size.width <= 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildHeader(isDesktop, isTablet),
              Expanded(
                child: _buildContent(isDesktop, isTablet),
              ),
              _buildBottomBar(isDesktop, isTablet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 24 : 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => GoRouter.of(context).go('/onboarding/occasions'),
                icon: const Icon(Icons.arrow_back_rounded),
                iconSize: 28,
              ),
              const Spacer(),
              _buildProgressDot(true),
              const SizedBox(width: 8),
              _buildProgressDot(true),
              const SizedBox(width: 8),
              _buildProgressDot(true),
              const SizedBox(width: 16),
              Text(
                '3 of 3',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 32 : (isTablet ? 24 : 16)),
          Text(
            'Choose your style',
            style: TextStyle(
              fontSize: isDesktop ? 36 : (isTablet ? 28 : 24),
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Select jewelry categories that catch your eye',
            style: TextStyle(
              fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDesktop, bool isTablet) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 2);
        final spacing = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);
        final padding = isDesktop ? 40.0 : (isTablet ? 32.0 : 20.0);

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(padding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = categoryOptions[index];
                    final isSelected = _selectedCategories.contains(category['name']);
                    return _buildCategoryCard(category, isSelected, index);
                  },
                  childCount: categoryOptions.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryCard(
    Map<String, dynamic> category,
    bool isSelected,
    int index,
  ) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final List<Color> gradientColors =
        (category['gradient'] as List<dynamic>).cast<Color>();


    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: () => _toggleSelection(category['name']),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.08),
                blurRadius: isSelected ? 20 : 10,
                offset: Offset(0, isSelected ? 8 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Background gradient (fallback if image doesn't load)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                  ),
                ),
                
                // --- FIX 1: Network Image with Loading/Error Handling ---
                Image.network(
                  category['image']!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator.adaptive(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
                        backgroundColor: Colors.white.withOpacity(0.1),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    // Show gradient + icon on error
                    return Center(
                      child: Icon(Icons.broken_image, color: Colors.white.withOpacity(0.8), size: 40),
                    );
                  },
                ),
                
                // 2. Dark overlay (for readability)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                
                // 3. Selection overlay
                if (isSelected)
                  Container(
                    // --- FIX 4: Use Theme Primary Color for selection overlay ---
                    color: primaryColor.withOpacity(0.3), 
                  ),
                
                // 4. Content (Text)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category['name'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 5. Checkmark
                if (isSelected)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        // --- FIX 4: Use Theme Primary Color for checkmark background ---
                        color: primaryColor, 
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                
                // 6. Border overlay
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      // --- FIX 4: Use Theme Primary Color for border ---
                      color: isSelected ? primaryColor : Colors.transparent,
                      width: 4,
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

  Widget _buildBottomBar(bool isDesktop, bool isTablet) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 24 : 20)),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isDesktop ? 500 : double.infinity),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                transform: Matrix4.identity()
                  ..scale(_selectedCategories.isNotEmpty ? 1.0 : 0.95),
                child: ElevatedButton(
                  onPressed: _finishSetup,
                  style: ElevatedButton.styleFrom(
                    // --- FIX 4: Use Theme Primary Color for button background ---
                    backgroundColor: primaryColor, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    minimumSize: const Size(double.infinity, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: _selectedCategories.isNotEmpty ? 4 : 0,
                    // --- FIX 4: Use Theme Primary Color for shadow ---
                    shadowColor: primaryColor.withOpacity(0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Start Browsing',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_selectedCategories.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedCategories.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDot(bool isActive) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        // --- FIX 4: Use Theme Primary Color for active dot ---
        color: isActive ? primaryColor : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
