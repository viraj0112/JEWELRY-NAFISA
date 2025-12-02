// lib/src/ui/screens/onboarding/onboarding_screen_1_location.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:postcode_checker/postcode_checker.dart' as Postcode;

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
  String? _selectedCountryCode; 

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _countryController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  void _nextStage() async {
    final country = _countryController.text.trim();
    final zipCode = _zipController.text.trim();
    
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

    final Postcode.CountryCode? countryEnum = Postcode.CountryCode.values.cast<Postcode.CountryCode?>().firstWhere(
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

    final provider = Provider.of<UserProfileProvider>(context, listen: false);

    await provider.saveOnboardingData(
      country: country,
      zipCode: zipCode,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(isTablet),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
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
                colors: isDark
                    ? [
                        const Color(0xFF1E3A2E),
                        const Color(0xFF2D5A47),
                        const Color(0xFF3C7A60),
                      ]
                    : [
                        const Color(0xFFE8F5E9),
                        const Color(0xFFC8E6C9),
                        const Color(0xFFA5D6A7),
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
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Where are you from?',
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Help us personalize your jewelry experience',
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
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
            color: theme.scaffoldBackgroundColor,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 40 : 24),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1E3A2E),
                        const Color(0xFF2D5A47),
                        const Color(0xFF3C7A60),
                      ]
                    : [
                        const Color(0xFFE8F5E9),
                        const Color(0xFFC8E6C9),
                        const Color(0xFFA5D6A7),
                      ],
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: isTablet ? 60 : 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
                SizedBox(height: isTablet ? 24 : 16),
                Text(
                  'Where are you from?',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: isTablet ? 32 : 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Help us personalize your jewelry experience',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: isTablet ? 16 : 14,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Country Input
          _buildSectionTitle('Country'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            decoration: BoxDecoration(
              color: isDark 
                  ? theme.colorScheme.surface.withOpacity(0.5)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedCountryCode != null
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: CountryCodePicker(
              onChanged: (CountryCode code) {
                _countryController.text = code.name ?? '';
                _selectedCountryCode = code.code;
                setState(() {});
              },
              favorite: const ['+91', 'IN', '+1', 'US', '+44', 'GB'],
              showCountryOnly: true,
              showOnlyCountryWhenClosed: true,
              alignLeft: false,
              flagWidth: 30,
              padding: EdgeInsets.zero,
              dialogSize: const Size(400, 500),
              dialogBackgroundColor: theme.colorScheme.surface,
              searchDecoration: InputDecoration(
                hintText: 'Search Country',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                labelStyle: TextStyle(
                  color: theme.colorScheme.onSurface,
                ),
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              textStyle: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
              searchStyle: TextStyle(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ZIP/Postal Code Input
          _buildSectionTitle('ZIP / Postal Code'),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _zipController,
            icon: Icons.numbers,
            keyboardType: TextInputType.text,
          ),

          const SizedBox(height: 40),

          // Continue Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: ElevatedButton(
              onPressed: _nextStage,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
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
    final theme = Theme.of(context);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive 
            ? theme.colorScheme.primary 
            : theme.colorScheme.onSurface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontSize: 16,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark 
            ? theme.colorScheme.surface.withOpacity(0.5)
            : Colors.grey.shade100,
        prefixIcon: Icon(
          icon, 
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.colorScheme.primary, 
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}