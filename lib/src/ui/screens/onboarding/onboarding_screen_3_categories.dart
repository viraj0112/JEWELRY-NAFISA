// onboarding_screen_3_categories.dart (Theme-Compliant)

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

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
   // The gradients here are preserved to maintain the visual effect,
      // but they are replaced by dynamic color retrieval in the build method.
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
   'image':'https://images.unsplash.com/photo-1619119069152-a2b331eb392a?q=80&w=1171&auto=format&fit:crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
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
  
 // Helper function to get a color based on the theme's primary color
 Color _getColorForGradient(Color primary, int index) {
  // Using simple interpolation to map the index to a shade difference
  double t = index / categoryOptions.length;
  if (Theme.of(context).brightness == Brightness.dark) {
   // Interpolate towards a slightly lighter shade in Dark Mode
   return Color.lerp(primary.withOpacity(0.5), primary, t)!;
  } else {
   // Interpolate towards a slightly darker shade in Light Mode
   return Color.lerp(primary, primary.withOpacity(0.5), t)!;
  }
 }


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

 void _finishSetup() async {
  final colorScheme = Theme.of(context).colorScheme;
  
  if (_selectedCategories.isEmpty) {
   ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
     content: const Text('Please select at least one category'),
     // FIX: Use a theme-appropriate error color
     backgroundColor: colorScheme.error, 
     behavior: SnackBarBehavior.floating,
     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
   );
   return;
  }

  final provider = Provider.of<UserProfileProvider>(context, listen: false);

  await provider.saveOnboardingData(
   categories: _selectedCategories, 
   isFinalSubmission: true,
  );

  // 2. Trigger the final DB write
  try {
    await FirebaseAnalytics.instance.logTutorialComplete();
    await provider.finalizeOnboardingMigration();
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    }
    return;
  }

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
   // FIX: Use scaffoldBackgroundColor
   backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
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
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  return Container(
   padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 24 : 16)),
   // FIX: Use surface color for the header background
   decoration: BoxDecoration(
    color: colorScheme.surface, 
    boxShadow: [
     BoxShadow(
      // FIX: Use onSurface color for shadow
      color: colorScheme.onSurface.withOpacity(0.05), 
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
        // FIX: Use onSurface for icon color
        icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface), 
        iconSize: 28,
       ),
       const Spacer(),
       // Dots are active as this is the final step
       _buildProgressDot(true), 
       const SizedBox(width: 8),
       _buildProgressDot(true),
       const SizedBox(width: 8),
       _buildProgressDot(true),
       const SizedBox(width: 16),
       Text(
        '3 of 3',
        // FIX: Use theme text style and onSurface color
        style: textTheme.bodyMedium!.copyWith(
         fontSize: 14,
         fontWeight: FontWeight.w600,
         color: colorScheme.onSurface.withOpacity(0.6),
        ),
       ),
      ],
     ),
     SizedBox(height: isDesktop ? 32 : (isTablet ? 24 : 16)),
     Text(
      'Choose your style',
      // FIX: Use headlineMedium/titleLarge and onSurface color
      style: textTheme.headlineMedium!.copyWith(
       fontSize: isDesktop ? 36 : (isTablet ? 28 : 24),
       fontWeight: FontWeight.bold,
       color: colorScheme.onSurface,
      ),
      textAlign: TextAlign.center,
     ),
     const SizedBox(height: 8),
     Text(
      'Select jewelry categories that catch your eye',
      // FIX: Use bodyMedium and onSurface color
      style: textTheme.bodyMedium!.copyWith(
       fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
       color: colorScheme.onSurface.withOpacity(0.6),
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
  final colorScheme = theme.colorScheme;
  final primaryColor = colorScheme.primary;

  // Dynamic gradient colors based on the theme's primary color
  final Color gradientStart = _getColorForGradient(primaryColor, index * 2);
  final Color gradientEnd = _getColorForGradient(primaryColor, index * 2 + 1);


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
        // FIX: Use onSurface for shadow color
        color: colorScheme.onSurface.withOpacity(isSelected ? 0.2 : 0.08), 
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
           colors: [gradientStart, gradientEnd], // Using dynamic theme-aware colors
          ),
         ),
        ),
         
         // Network Image with Loading/Error Handling
         CachedNetworkImage(
          imageUrl: category['image']!,
          fit: BoxFit.cover,
          color: theme.brightness == Brightness.dark 
           ? Colors.black.withOpacity(0.2) // Subtle darkening of image in Dark Mode
           : null,
          colorBlendMode: BlendMode.darken,
          placeholder: (context, url) => Center(
           child: CircularProgressIndicator.adaptive(
             strokeWidth: 2,
             valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary.withOpacity(0.7)), 
             backgroundColor: colorScheme.onPrimary.withOpacity(0.1),
            ),
           ),
          errorWidget: (context, url, error) => Center(
           child: Icon(Icons.broken_image, color: colorScheme.onPrimary.withOpacity(0.8), size: 40), 
           ),
         ),
        
        // 2. Dark overlay (for readability)
        Container(
         decoration: BoxDecoration(
          gradient: LinearGradient(
           begin: Alignment.topCenter,
           end: Alignment.bottomCenter,
           colors: [
            Colors.transparent,
            // Dark overlay should be dark regardless of theme
            Colors.black.withOpacity(0.7), 
           ],
          ),
         ),
        ),
        
        // 3. Selection overlay
        if (isSelected)
         Container(
          // FIX: Use Theme Primary Color for selection overlay
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
            // FIX: Use onPrimary (White) for text on a dark background/image
            style: theme.textTheme.titleLarge!.copyWith(
             fontSize: 20,
             fontWeight: FontWeight.bold,
             color: Colors.white,
             shadows: const [
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
            // FIX: Use Theme Primary Color for checkmark background
            color: primaryColor, 
            shape: BoxShape.circle,
            boxShadow: [
             BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
             ),
            ],
           ),
           child: Icon(
            Icons.check,
            // FIX: Use onPrimary for checkmark icon (White/Black, depending on theme)
            color: colorScheme.onPrimary, 
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
           // FIX: Use Theme Primary Color for border
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
  final colorScheme = Theme.of(context).colorScheme;

  return Container(
   padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 24 : 20)),
   // FIX: Use surface color for the bar background
   decoration: BoxDecoration(
    color: colorScheme.surface, 
    boxShadow: [
     BoxShadow(
      // FIX: Use onSurface color for shadow
      color: colorScheme.onSurface.withOpacity(0.08), 
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
          // Remove style block to use ElevatedButtonThemeData from AppTheme
         child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
           const Text(
            'Start Browsing',
            // Text style is already handled by ElevatedButtonThemeData
           ),
           if (_selectedCategories.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
             padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
             ),
             decoration: BoxDecoration(
              // FIX: Text is on Primary color background, so use onPrimary for contrast.
              color: colorScheme.onPrimary.withOpacity(0.3), 
              borderRadius: BorderRadius.circular(12),
             ),
             child: Text(
              '${_selectedCategories.length}',
              // FIX: Text color is primary color's contrast color
              style: TextStyle(
               fontSize: 14,
               fontWeight: FontWeight.bold,
               color: colorScheme.onPrimary,
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
  final colorScheme = Theme.of(context).colorScheme;

  return AnimatedContainer(
   duration: const Duration(milliseconds: 300),
   width: isActive ? 24 : 8,
   height: 8,
   decoration: BoxDecoration(
    // FIX: Use primary for active, and surface/onSurface for inactive
    color: isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.3),
    borderRadius: BorderRadius.circular(4),
   ),
  );
 }
}