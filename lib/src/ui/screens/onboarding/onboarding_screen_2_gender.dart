// lib/src/ui/screens/onboarding/onboarding_screen_2_gender.dart
// Combined Gender + Age screen (Stage 1)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';

class OnboardingScreen2Gender extends StatefulWidget {
  const OnboardingScreen2Gender({super.key});

  @override
  State<OnboardingScreen2Gender> createState() =>
      _OnboardingScreen2GenderState();
}

class _OnboardingScreen2GenderState extends State<OnboardingScreen2Gender>
    with SingleTickerProviderStateMixin {
  String? _selectedGender;
  final TextEditingController _ageController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
        parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _nextStage() async {
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Please select your gender.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final ageText = _ageController.text.trim();
    if (ageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Please enter your age.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final age = int.tryParse(ageText);
    if (age == null || age < 13 || age > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Please enter a valid age (13–120).'),
          backgroundColor: const Color(0xFFFF5252),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final provider = Provider.of<UserProfileProvider>(context, listen: false);

    // Save both gender and age, advance stage
    await provider.saveOnboardingData(
      gender: _selectedGender,
      age: age,
      isFinalSubmission: false,
    );

    if (mounted) {
      // Stage 1 done → go to Categories (stage 2); occasions screen is skipped
      GoRouter.of(context).go('/onboarding/categories');
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
                  _buildProgressIndicator(),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 40, horizontal: 60),
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
            _buildProgressIndicator(),
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
          'About You',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "This helps us find you more relevant content.\nWe won't show it on your profile.",
          style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
        ),
        const SizedBox(height: 32),

        // ── Gender ────────────────────────────────────────────────────────────
        const Text(
          "What's Your Gender?",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildGenderButton('Female'),
        const SizedBox(height: 12),
        _buildGenderButton('Male'),
        const SizedBox(height: 12),
        _buildGenderButton('Other'),

        const SizedBox(height: 32),

        // ── Age ───────────────────────────────────────────────────────────────
        const Text(
          'How old are you?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFF006435),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter your age',
                    hintStyle: TextStyle(color: Colors.black38, fontSize: 18),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // ── Next Button ───────────────────────────────────────────────────────
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _nextStage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006435),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Next',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderButton(String gender) {
    final bool isSelected = _selectedGender == gender;
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: () => setState(() => _selectedGender = gender),
        style: OutlinedButton.styleFrom(
          backgroundColor:
              isSelected ? const Color(0xFF006435) : Colors.white,
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF006435)
                : const Color(0xFFE0E0E0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          gender,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    // 3 steps: Location (done), Gender+Age (active), Categories
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildProgressDot(false),
        const SizedBox(width: 8),
        _buildProgressDot(true),
        const SizedBox(width: 8),
        _buildProgressDot(false),
      ],
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
              child: const Icon(Icons.diamond, size: 40, color: Colors.white),
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
