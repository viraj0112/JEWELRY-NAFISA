// onboarding_screen_1_location.dart - Pinterest Style

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';

class OnboardingScreen1Location extends StatefulWidget {
  const OnboardingScreen1Location({super.key});

  @override
  State<OnboardingScreen1Location> createState() =>
      _OnboardingScreen1LocationState();
}

class _OnboardingScreen1LocationState extends State<OnboardingScreen1Location>
    with SingleTickerProviderStateMixin {
  String? _selectedCountry;
  String? _selectedRegion;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, dynamic>> countries = [
    {'name': 'USA', 'flag': '🇺🇸'},
    {'name': 'Canada', 'flag': '🇨🇦'},
    {'name': 'India', 'flag': '🇮🇳'},
    {'name': 'UK', 'flag': '🇬🇧'},
  ];

  final Map<String, List<String>> regions = {
    'USA': ['California', 'Texas', 'New York', 'Florida', 'Illinois'],
    'Canada': ['Ontario', 'Quebec', 'Alberta', 'British Columbia'],
    'India': ['Maharashtra', 'Delhi', 'Karnataka', 'Tamil Nadu', 'Gujarat'],
    'UK': ['London', 'Manchester', 'Scotland', 'Wales', 'Birmingham'],
  };

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
    if (_selectedCountry == null || _selectedRegion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select both Country and Region'),
          backgroundColor: Color(0xFF006435),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final provider = Provider.of<UserProfileProvider>(context, listen: false);

    await provider.saveOnboardingData(
      country: _selectedCountry,
      region: _selectedRegion,
      isFinalSubmission: false,
    );

    if (mounted) {
      GoRouter.of(context).go('/onboarding/occasions');
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
          child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(isTablet),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side - Visual
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8F5E9),
                  Color(0xFFC8E6C9),
                  Color(0xFFA5D6A7),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 80,
                      color: Color(0xFF006435),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Where are you from?',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Help us personalize your jewelry experience',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right side - Form
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: _buildFormContent(maxWidth: 480),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isTablet) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 40 : 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                 Color(0xFFE8F5E9),
                  Color(0xFFC8E6C9),
                  Color(0xFFA5D6A7),
                ],
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: isTablet ? 60 : 48,
                    color: Color(0xFF006435),
                  ),
                ),
                SizedBox(height: isTablet ? 24 : 16),
                Text(
                  'Where are you from?',
                  style: TextStyle(
                    fontSize: isTablet ? 32 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Help us personalize your jewelry experience',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Form
          _buildFormContent(maxWidth: isTablet ? 600 : double.infinity),
        ],
      ),
    );
  }

  Widget _buildFormContent({required double maxWidth}) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator
          Row(
            children: [
              _buildProgressDot(true),
              const SizedBox(width: 8),
              _buildProgressDot(false),
              const SizedBox(width: 8),
              _buildProgressDot(false),
              const Spacer(),
              Text(
                '1 of 3',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Country Selection
          Text(
            'Select your country',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: countries.map((country) {
              final isSelected = _selectedCountry == country['name'];
              return _buildCountryChip(
                country['name'],
                country['flag'],
                isSelected,
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Region Selection
          if (_selectedCountry != null) ...[
            Text(
              'Select your region',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: regions[_selectedCountry]!.map((region) {
                final isSelected = _selectedRegion == region;
                return _buildRegionChip(region, isSelected);
              }).toList(),
            ),
            const SizedBox(height: 40),
          ],

          const SizedBox(height: 20),

          // Continue Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: ElevatedButton(
              onPressed: _nextStage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF006435),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
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

  Widget _buildCountryChip(String name, String flag, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCountry = name;
          _selectedRegion = null;
        });
      },
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF006435) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Color(0xFF006435) : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Color(0xFF006435).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              flag,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionChip(String region, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRegion = region;
        });
      },
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF006435) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Color(0xFF006435) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          region,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}