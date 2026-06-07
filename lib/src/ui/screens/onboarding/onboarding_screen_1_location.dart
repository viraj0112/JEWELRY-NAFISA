// lib/src/ui/screens/onboarding/onboarding_screen_1_location.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:postcode_checker/postcode_checker.dart' as Postcode;
import 'package:firebase_analytics/firebase_analytics.dart';

class OnboardingScreen1Location extends StatefulWidget {
  const OnboardingScreen1Location({super.key});

  @override
  State<OnboardingScreen1Location> createState() =>
      _OnboardingScreen1LocationState();
}

class _OnboardingScreen1LocationState extends State<OnboardingScreen1Location>
    with SingleTickerProviderStateMixin {
  
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedCountryCode;   // e.g. "IN"
  String? _selectedDialCode;      // e.g. "+91"

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logTutorialBegin();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    
    // Initialize the default dial code and country (India)
    _selectedDialCode = '+91';
    _selectedCountryCode = 'IN';
    _countryController.text = 'India';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _countryController.dispose();
    _zipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// When the phone dial code changes, auto-update the country picker to match.
  void _onDialCodeChanged(CountryCode code) {
    final newCode = code.code;
    final newName = code.name ?? '';
    final newDial = code.dialCode ?? _selectedDialCode ?? '+91';

    // Only update country if we have a valid non-empty country code
    if (newCode != null && newCode.isNotEmpty) {
      setState(() {
        _selectedDialCode = newDial;
        _selectedCountryCode = newCode;
        _countryController.text = newName;
      });
    } else {
      setState(() {
        _selectedDialCode = newDial;
      });
    }
  }

  void _nextStage() async {
    final country = _countryController.text.trim();
    final zipCode = _zipController.text.trim();
    final phoneInput = _phoneController.text.trim();
    final fullPhoneNumber = '${_selectedDialCode ?? "+91"}$phoneInput';
    
    if (_selectedCountryCode == null || _selectedCountryCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Please select a Country.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (zipCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Please enter your ZIP / Postal Code.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Attempt to find the Postcode.CountryCode enum from the selected country code
    final Postcode.CountryCode? countryEnum = Postcode.CountryCode.values
        .cast<Postcode.CountryCode?>()
        .firstWhere(
          (e) => e?.code == _selectedCountryCode,
          orElse: () => null,
        );
    
    if (countryEnum == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Selected country is not supported for postal code validation.'),
          backgroundColor: const Color(0xFFFF5252),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Postcode validation
    final validationResult = Postcode.PostcodeChecker.validate(
      countryEnum,
      zipCode,
    );

    final isZipValid = validationResult.isValid;
    
    if (!isZipValid) {
      final errorMessage = validationResult.errorMessage ?? 
          '❌ The ZIP / Postal Code "$zipCode" is not valid for ${countryEnum.code}.';
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: const Color(0xFFFF5252),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Save data
    final provider = Provider.of<UserProfileProvider>(context, listen: false);

    await provider.saveOnboardingData(
      country: country,
      zipCode: zipCode,
      phone: fullPhoneNumber,
      isFinalSubmission: false,
    );

    if (mounted) {
      // Stage 0 done → go to combined Gender+Age screen (stage 1)
      GoRouter.of(context).go('/onboarding/gender');
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
        // Left side - Logo and branding
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
        // Right side - Form
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
            _buildProgressIndicator(),
            const SizedBox(height: 40),
            _buildFormContent(),
          ],
        ),
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

  Widget _buildProgressIndicator() {
    // 3 steps: Location (active), Gender+Age, Categories
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildProgressDot(true),
        const SizedBox(width: 8),
        _buildProgressDot(false),
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

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tell us about yourself',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This helps us find you more relevant content.\nWe won\'t show it on your profile.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        // ── Phone Number (FIRST — drives country auto-detection) ──────────────
        _buildLabel('Phone Number'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            children: [
              CountryCodePicker(
                onChanged: _onDialCodeChanged,   // ← auto-syncs country
                initialSelection: 'IN',
                favorite: const ['+91', 'IN', '+1', 'US', '+44', 'GB'],
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                alignLeft: false,
                showFlag: true,
                padding: const EdgeInsets.only(left: 12),
                textStyle: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                dialogTextStyle: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                ),
                searchStyle: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                ),
                dialogBackgroundColor: Colors.white,
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter phone number',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    hintStyle: TextStyle(color: Colors.black38),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Country (auto-filled from phone dial code, but still editable) ───
        _buildLabel('Country'),
        const SizedBox(height: 8),
        // Show a read-only text field displaying the auto-detected country name.
        // The user can tap the phone dial code picker above to change it.
        // We avoid rebuilding CountryCodePicker with a ValueKey to prevent
        // the DropdownButton assertion error.
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.flag_outlined, size: 20, color: Colors.black54),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _countryController.text.isNotEmpty
                      ? _countryController.text
                      : 'India',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Text(
                'Auto-detected',
                style: TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Pin Code ──────────────────────────────────────────────────────────
        _buildLabel('Pin Code / ZIP Code'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _zipController,
          hintText: 'Enter your postal / ZIP code',
          keyboardType: TextInputType.text,
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF006435), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
