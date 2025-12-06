// lib/src/ui/screens/onboarding/onboarding_screen_1_location.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:country_code_picker/country_code_picker.dart';
// FIX: Use 'as Postcode' to prevent the 'CountryCode' class conflict
import 'package:postcode_checker/postcode_checker.dart' as Postcode;

class OnboardingScreen1Location extends StatefulWidget {
  const OnboardingScreen1Location({super.key});

  @override
  State<OnboardingScreen1Location> createState() =>
      _OnboardingScreen1LocationState();
}

class _OnboardingScreen1LocationState extends State<OnboardingScreen1Location>
    with SingleTickerProviderStateMixin {
  
  // Text Controllers
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  // State variable to hold the 2-letter country code for validation
  String? _selectedCountryCode; 
  String? _selectedDialCode;

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
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    
    // Initial selection is intentionally null/empty as requested.
  }

  @override
  void dispose() {
    _animationController.dispose();
    _countryController.dispose();
    _zipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _nextStage() async {
    final country = _countryController.text.trim();
    final zipCode = _zipController.text.trim();
    final phoneInput = _phoneController.text.trim();
    
    // 1. Country Selection Check (This is necessary since no country is pre-selected)
    if (_selectedCountryCode == null || _selectedCountryCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Please select a Country.'),
          backgroundColor: const Color(0xFF006435),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // 2. ZIP Code Presence Check
    if (zipCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Please enter your ZIP / Postal Code.'),
          backgroundColor: const Color(0xFF006435),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // 3. Phone Number Check
    if (phoneInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Please enter your Phone Number.'),
          backgroundColor: const Color(0xFF006435),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Combine dial code and phone number
    // Default to +91 if not selected (matching initialSelection 'IN')
    final dialCode = _selectedDialCode ?? '+91';
    final fullPhoneNumber = '$dialCode $phoneInput';

    // FIX: Manual lookup of the enum value. 
    final Postcode.CountryCode? countryEnum = Postcode.CountryCode.values.cast<Postcode.CountryCode?>().firstWhere(
      // Match the enum's code property (e.g., e.code == "IN") with the selected code string
      (e) => e?.code == _selectedCountryCode,
      // If no match is found, return null
      orElse: () => null, 
    );
    
    // Check if the country code was successfully mapped
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

    // 4. ZIP Code Validation using the detailed 'validate' method
    final validationResult = Postcode.PostcodeChecker.validate(
      countryEnum, // Pass the correctly resolved CountryCode enum type
      zipCode,
    );

    final isZipValid = validationResult.isValid;
    
    if (!isZipValid) {
      // Use the error message from the validation result if available
      final errorMessage = validationResult.errorMessage ?? 
          '❌ The ZIP / Postal Code "$zipCode" is not valid for ${countryEnum.code}.';
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: const Color(0xFFFF5252), // Red for error
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // 5. Save and Navigate
    final provider = Provider.of<UserProfileProvider>(context, listen: false);

    await provider.saveOnboardingData(
      country: country,
      zipCode: zipCode,
      phone: fullPhoneNumber,
      isFinalSubmission: false,
    );

    if (mounted) {
      // SUCCESS: Navigate to the next screen
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
        // Left side - Visual (Unchanged)
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
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
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: _buildFormContent(maxWidth: 480),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isTablet) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header (Unchanged)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 40 : 24),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
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
                    color: const Color(0xFF006435),
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
          // Progress indicator (Unchanged)
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

          // ------------------------------------
          // Country Input (CountryCodePicker)
          // ------------------------------------
          _buildSectionTitle('Country'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedCountryCode != null
                    ? const Color(0xFF006435)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: CountryCodePicker(
              onChanged: (CountryCode code) {
                // Store the selected country name and code
                _countryController.text = code.name ?? '';
                _selectedCountryCode = code.code;
                setState(() {}); // Rebuild to update border color
              },
              // ⭐ FIX: Removed initialSelection so it defaults to nothing, as requested
              // initialSelection: 'US',
              favorite: const ['+91', 'IN', '+1', 'US', '+44', 'GB'],
              showCountryOnly: true,
              showOnlyCountryWhenClosed: true,
              alignLeft: false,
              flagWidth: 30,
              padding: EdgeInsets.zero,
              dialogSize: const Size(400, 500),
              searchDecoration: InputDecoration(
                hintText: 'Search Country',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              textStyle: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
              dialogTextStyle: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 16,
              ),
              searchStyle: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 16,
              ),
              dialogBackgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          // ------------------------------------
          // ZIP/Postal Code Input
          // ------------------------------------
          _buildSectionTitle('ZIP / Postal Code'),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _zipController,
            icon: Icons.numbers,
            keyboardType: TextInputType.text,
          ),

          const SizedBox(height: 24),

          // ------------------------------------
          // Phone Number Input
          // ------------------------------------
          _buildSectionTitle('Phone Number'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                // Country Code Picker for Phone
                CountryCodePicker(
                  onChanged: (CountryCode code) {
                    _selectedDialCode = code.dialCode;
                  },
                  initialSelection: 'IN',
                  favorite: const ['+91', 'IN', '+1', 'US'],
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  alignLeft: false,
                  showFlag: true,
                  padding: const EdgeInsets.only(left: 8),
                  textStyle: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                  dialogTextStyle: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 16,
                  ),
                  searchStyle: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 16,
                  ),
                  dialogBackgroundColor: Colors.white,
                ),
                // Phone Number Text Field
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'Phone Number',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Continue Button (Unchanged)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: ElevatedButton(
              onPressed: _nextStage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006435),
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
          const SizedBox(height: 20),
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
        color: isActive ? const Color(0xFF006435) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade100,
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF006435), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}