// lib/src/ui/screens/onboarding/onboarding_screen_2_gender.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';

class OnboardingScreen2Gender extends StatefulWidget {
  const OnboardingScreen2Gender({super.key});

  @override
  State<OnboardingScreen2Gender> createState() => _OnboardingScreen2GenderState();
}

class _OnboardingScreen2GenderState extends State<OnboardingScreen2Gender>
    with SingleTickerProviderStateMixin {
  
  String? _selectedGender;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectGenderAndProceed(String gender) async {
    setState(() => _selectedGender = gender);
    
    final provider = Provider.of<UserProfileProvider>(context, listen: false);
    
    // Save gender data and proceed
    await provider.saveOnboardingData(
      gender: gender,
      isFinalSubmission: false,
    );

    if (mounted) {
      GoRouter.of(context).go('/onboarding/age');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogoSection(),
                  const SizedBox(height: 60),
                  _buildProgressIndicator(0),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 60),
                child: _buildFormContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
        child: Column(
          children: [
            _buildLogoSection(),
            const SizedBox(height: 32),
            _buildProgressIndicator(0),
            const SizedBox(height: 40),
            _buildFormContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "What's Your Gender?", 
          style: TextStyle(
            fontSize: 24, 
            fontWeight: FontWeight.bold, 
            color: Colors.black87
          )
        ),
        const SizedBox(height: 8),
        const Text(
          "This helps us find you more relevant content.\nWe won't show it on your profile.", 
          style: TextStyle(
            fontSize: 14, 
            color: Colors.black54, 
            height: 1.5
          )
        ),
        const SizedBox(height: 32),
        
        _buildGenderButton('Female'),
        const SizedBox(height: 16),
        _buildGenderButton('Male'),
        const SizedBox(height: 16),
        _buildGenderButton('Other'),
      ],
    );
  }

  Widget _buildGenderButton(String gender) {
    bool isSelected = _selectedGender == gender;
    return SizedBox(
      height: 55,
      child: OutlinedButton(
        onPressed: () => _selectGenderAndProceed(gender),
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF006435) : Colors.white,
          side: BorderSide(
            color: isSelected ? const Color(0xFF006435) : const Color(0xFFE0E0E0)
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30)
          ),
        ),
        child: Text(
          gender, 
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87, 
            fontWeight: FontWeight.w600,
            fontSize: 16
          )
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int activeIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildProgressDot(index == activeIndex),
        );
      }),
    );
  }

  Widget _buildProgressDot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF006435) : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Image.asset(
          'assets/icons/dagina2.png',
          height: 80,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF006435),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.diamond,
                size: 40,
                color: Colors.white,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'FIND THE PERFECT JEWELRY FOR ANY OCCASION',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            color: Color(0xFF006435),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}