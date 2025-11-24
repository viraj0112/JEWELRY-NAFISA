// onboarding_screen_2_occasions.dart - Pinterest Style with Green Theme

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';

class OnboardingScreen2Occasions extends StatefulWidget {
  const OnboardingScreen2Occasions({super.key});

  @override
  State<OnboardingScreen2Occasions> createState() =>
      _OnboardingScreen2OccasionsState();
}

class _OnboardingScreen2OccasionsState extends State<OnboardingScreen2Occasions>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedOccasions = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, dynamic>> occasionOptions = [
    {'name': 'Wedding', 'icon': Icons.favorite, 'color': Color(0xFF006435)},
    {'name': 'Anniversary', 'icon': Icons.celebration, 'color': Color(0xFF00854D)},
    {'name': 'Birthday', 'icon': Icons.cake, 'color': Color(0xFF66BB94)},
    {'name': 'Daily Wear', 'icon': Icons.sunny, 'color': Color(0xFF4A9D6F)},
    {'name': 'Gifting', 'icon': Icons.card_giftcard, 'color': Color(0xFF2E7D52)},
    {'name': 'Festive/Holiday', 'icon': Icons.auto_awesome, 'color': Color(0xFF52A876)},
    {'name': 'Engagement', 'icon': Icons.diamond, 'color': Color(0xFF1B5E3A)},
    {'name': 'Just Because', 'icon': Icons.mood, 'color': Color(0xFF81C9A8)},
  ];

  @override
  void initState() {
    super.initState();
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
    if (_selectedOccasions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one occasion'),
          backgroundColor: Color(0xFF006435),
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
      backgroundColor: Colors.white,
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
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 24 : 16)),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => GoRouter.of(context).go('/onboarding/location'),
                icon: const Icon(Icons.arrow_back_rounded),
                iconSize: 28,
              ),
              const Spacer(),
              _buildProgressDot(true),
              const SizedBox(width: 8),
              _buildProgressDot(true),
              const SizedBox(width: 8),
              _buildProgressDot(false),
              const SizedBox(width: 16),
              Text(
                '2 of 3',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 40 : (isTablet ? 32 : 24)),
          Text(
            'What occasions do you shop for?',
            style: TextStyle(
              fontSize: isDesktop ? 36 : (isTablet ? 28 : 24),
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Select all that apply',
            style: TextStyle(
              fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
              color: Colors.grey.shade600,
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
          color: isSelected
              ? occasion['color'].withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? occasion['color'] : Colors.grey.shade200,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: occasion['color'].withOpacity(0.3),
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
                color: isSelected
                    ? occasion['color'].withOpacity(0.2)
                    : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                occasion['icon'],
                size: 40,
                color: isSelected ? occasion['color'] : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              occasion['name'],
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? occasion['color'] : Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelected) ...[
              const SizedBox(height: 8),
              Icon(
                Icons.check_circle,
                color: occasion['color'],
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDesktop, bool isTablet) {
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
          child: ElevatedButton(
            onPressed: _nextStage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF006435),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              minimumSize: const Size(double.infinity, 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: Text(
              'Continue (${_selectedOccasions.length} selected)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? Color(0xFF006435) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}