// onboarding_screen_2_occasions.dart - Pinterest Style with Green Theme (Theme-Compliant)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class OnboardingScreen2Occasions extends StatefulWidget {
const OnboardingScreen2Occasions({super.key});

@override
State<OnboardingScreen2Occasions>createState()=>
_OnboardingScreen2OccasionsState();
}

class _OnboardingScreen2OccasionsState extends State<OnboardingScreen2Occasions>
  with SingleTickerProviderStateMixin {
 
 final Set<String> _selectedOccasions = {};
 late AnimationController _animationController;
 late Animation<double> _fadeAnimation;

 // The color palette is defined here. We will retrieve the active primary color 
 // from the theme in the build methods, but the shades defined here 
 // still ensure color variation in the cards.
 final List<Map<String, dynamic>> occasionOptions = [
  {'name': 'Wedding', 'icon': Icons.favorite, 'shade': 0.8}, // Darker shade
  {'name': 'Anniversary', 'icon': Icons.celebration, 'shade': 1.0}, // Primary shade
  {'name': 'Birthday', 'icon': Icons.cake, 'shade': 0.6},
  {'name': 'Daily Wear', 'icon': Icons.sunny, 'shade': 0.5},
  {'name': 'Gifting', 'icon': Icons.card_giftcard, 'shade': 0.9},
  {'name': 'Festive/Holiday', 'icon': Icons.auto_awesome, 'shade': 0.7},
  {'name': 'Engagement', 'icon': Icons.diamond, 'shade': 0.95},
  {'name': 'Just Because', 'icon': Icons.mood, 'shade': 0.4}, // Lighter shade
 ];
  
 // Helper function to get a shaded color based on the theme's primary color
 Color _getShadedColor(Color baseColor, double shade) {
  // Simple shading logic: interpolate between the base color and a lighter/darker color
  // For the dark primary (#66BB94), it is lighter than the light primary (#006435)
  if (Theme.of(context).brightness == Brightness.dark) {
   // In dark mode, baseColor is lighter, so we interpolate towards white for lighter shade effects
   return Color.lerp(Colors.white, baseColor, shade)!;
  } else {
   // In light mode, baseColor is darker, so we interpolate towards black for darker shade effects
   return Color.lerp(Colors.black, baseColor, shade)!;
  }
 }

 @override
 void initState() {
  super.initState();
  FirebaseAnalytics.instance.logEvent(
    name: 'tutorial_progress', 
    parameters: {'step': 2, 'name': 'occasions'},
  );
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
  _animationController.dispose();
  super.dispose();
 }

 void _nextStage() async {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  
  if (_selectedOccasions.isEmpty) {
   ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
     content: const Text('Please select at least one occasion'),
     // FIX: Use theme primary color
     backgroundColor: colorScheme.primary,
     behavior: SnackBarBehavior.floating,
     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
   );
   return;
  }

  final provider = Provider.of<UserProfileProvider>(context, listen: false);

  await provider.saveOnboardingData(
   occasions: _selectedOccasions.toList(),
   isFinalSubmission: false,
  );

  if (mounted) {
   GoRouter.of(context).go('/onboarding/categories');
  }
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
        child: isDesktop
          ? _buildDesktopContent()
          : _buildMobileContent(isTablet),
       ),
       _buildBottomBar(isDesktop, isTablet),
      ],
     ),
    ),
   ),
  );
 }

 Widget _buildHeader(bool isDesktop, bool isTablet) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  
  return Container(
   padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 24 : 16)),
   child: Column(
    children: [
     Row(
      children: [
       IconButton(
        onPressed: () => GoRouter.of(context).go('/onboarding/location'),
        icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onBackground), // FIX: Use onBackground for icon color
        iconSize: 28,
       ),
       const Spacer(),
       _buildProgressDot(false), // Stage 1 is complete
       const SizedBox(width: 8),
       _buildProgressDot(true), // Stage 2 is active
       const SizedBox(width: 8),
       _buildProgressDot(false), // Stage 3 is next
       const SizedBox(width: 16),
       Text(
        '2 of 3',
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
         fontSize: 14,
         fontWeight: FontWeight.w600,
         color: colorScheme.onBackground.withOpacity(0.6), // FIX: Use onBackground
        ),
       ),
      ],
     ),
     SizedBox(height: isDesktop ? 40 : (isTablet ? 32 : 24)),
     Text(
      'What occasions do you shop for?',
      // FIX: Use headlineMedium/titleLarge and adjust size, using onBackground color
      style: Theme.of(context).textTheme.headlineMedium!.copyWith(
       fontSize: isDesktop ? 36 : (isTablet ? 28 : 24),
       fontWeight: FontWeight.bold,
       color: colorScheme.onBackground,
      ),
      textAlign: TextAlign.center,
     ),
     const SizedBox(height: 12),
     Text(
      'Select all that apply',
      // FIX: Use bodyMedium and adjust size, using onBackground color
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
       fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
       color: colorScheme.onBackground.withOpacity(0.6),
      ),
     ),
    ],
   ),
  );
 }

 Widget _buildDesktopContent() {
  return Center(
   child: Container(
    constraints: const BoxConstraints(maxWidth: 1000),
    padding: const EdgeInsets.symmetric(horizontal: 40),
    child: GridView.builder(
     shrinkWrap: true,
     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 1,
     ),
     itemCount: occasionOptions.length,
     itemBuilder: (context, index) {
      final occasion = occasionOptions[index];
      final isSelected = _selectedOccasions.contains(occasion['name']);
      return _buildOccasionCard(occasion, isSelected);
     },
    ),
   ),
  );
 }

 Widget _buildMobileContent(bool isTablet) {
  return SingleChildScrollView(
   padding: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 20),
   child: Center(
    child: Container(
     constraints: BoxConstraints(maxWidth: isTablet ? 700 : double.infinity),
     child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
       crossAxisCount: isTablet ? 3 : 2,
       crossAxisSpacing: 16,
       mainAxisSpacing: 16,
       childAspectRatio: 1,
      ),
      itemCount: occasionOptions.length,
      itemBuilder: (context, index) {
       final occasion = occasionOptions[index];
       final isSelected = _selectedOccasions.contains(occasion['name']);
       return _buildOccasionCard(occasion, isSelected);
      },
     ),
    ),
   ),
  );
 }

 Widget _buildOccasionCard(Map<String, dynamic> occasion, bool isSelected) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  final Color primaryColor = colorScheme.primary;
  final Color cardColor = _getShadedColor(primaryColor, occasion['shade']);
  
  return InkWell(
   onTap: () {
    setState(() {
     if (isSelected) {
      _selectedOccasions.remove(occasion['name']);
     } else {
      _selectedOccasions.add(occasion['name']);
     }
    });
   },
   borderRadius: BorderRadius.circular(20),
   child: AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    decoration: BoxDecoration(
     // FIX: Use surface/background colors
     color: isSelected
       ? cardColor.withOpacity(0.1)
       : colorScheme.surface, // Background of the unselected card
     borderRadius: BorderRadius.circular(20),
     border: Border.all(
      // FIX: Use cardColor for borders
      color: isSelected ? cardColor : colorScheme.onSurface.withOpacity(0.1),
      width: isSelected ? 3 : 1,
     ),
     boxShadow: isSelected
       ? [
         BoxShadow(
          color: cardColor.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 6),
         ),
        ]
       : null,
    ),
    child: Column(
     mainAxisAlignment: MainAxisAlignment.center,
     children: [
      Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
        // FIX: Use surface/background colors
        color: isSelected
          ? cardColor.withOpacity(0.2)
          : colorScheme.background, // Inner circle background
        shape: BoxShape.circle,
       ),
       child: Icon(
        occasion['icon'],
        size: 40,
        // FIX: Icon color
        color: isSelected ? cardColor : colorScheme.onSurface.withOpacity(0.6),
       ),
      ),
      const SizedBox(height: 12),
      Text(
       occasion['name'],
       style: Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: 14,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        // FIX: Text color
        color: isSelected ? cardColor : colorScheme.onSurface.withOpacity(0.8),
       ),
       textAlign: TextAlign.center,
      ),
      if (isSelected) ...[
       const SizedBox(height: 8),
       Icon(
        Icons.check_circle,
        // FIX: Checkmark color
        color: cardColor,
        size: 20,
       ),
      ],
     ],
    ),
   ),
  );
 }

 Widget _buildBottomBar(bool isDesktop, bool isTablet) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  
  return Container(
   padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 24 : 20)),
   // FIX: Use surface color for the bar background
   decoration: BoxDecoration(
    color: colorScheme.surface,
    boxShadow: [
     BoxShadow(
      color: colorScheme.onSurface.withOpacity(0.1), // FIX: Use onSurface for shadow
      blurRadius: 10,
      offset: const Offset(0, -5),
     ),
    ],
   ),
   child: Center(
    child: Container(
     constraints: BoxConstraints(maxWidth: isDesktop ? 500 : double.infinity),
     child: ElevatedButton(
      onPressed: _nextStage,
      // No need to use ElevatedButton.styleFrom if you rely on the theme!
      child: Text(
       'Continue (${_selectedOccasions.length} selected)',
       // The text style is handled by the elevatedButtonTheme data
      ),
     ),
    ),
   ),
  );
 }

 Widget _buildProgressDot(bool isActive) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  
  return AnimatedContainer(
   duration: const Duration(milliseconds: 300),
   width: isActive ? 24 : 8,
   height: 8,
   decoration: BoxDecoration(
    // FIX: Use primary and a suitable background/surface shade
    color: isActive ? colorScheme.primary : colorScheme.surface.withOpacity(0.7),
    borderRadius: BorderRadius.circular(4),
   ),
  );
 }
}