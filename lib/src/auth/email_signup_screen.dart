
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand constants (shared)
// ─────────────────────────────────────────────────────────────────────────────
class _Brand {
  static const Color forestGreen = Color(0xFF2D5A27);
  static const Color creamWhite = Color(0xFFFAF8F5);
}

// ─────────────────────────────────────────────────────────────────────────────
// Email Sign Up Screen
// ─────────────────────────────────────────────────────────────────────────────
class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({super.key});

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _authService = SupabaseAuthService();

  String _fullPhoneNumber = '';
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _birthdateController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = await _authService.signUpWithEmailPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _usernameController.text.trim(),
      _fullPhoneNumber,
      _birthdateController.text.trim(),
      _referralCodeController.text.trim(),
    );

    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackbar('Sign up failed. The email might already be in use.');
      }
    } else {
      FirebaseAnalytics.instance.logEvent(
        name: 'sign_up',
        parameters: {
          'method': 'email',
          'username': _usernameController.text.trim(),
        },
      );
      await _authService.signOut();
      if (mounted) {
        _showSnackbar(
          'Account created! Please check your email to verify and then log in.',
          isError: false,
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1920, 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _Brand.forestGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthdateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _launchLegalUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
      if (mounted) _showSnackbar('Could not open $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Background ────────────────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/icons/loginscreen.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),

          // ── Scrollable form ───────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 0 : 0,
                  vertical: 24,
                ),
                child: Center(
                  child: Container(
                    width: isWide ? 520 : double.infinity,
                    margin: isWide
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(horizontal: 0),
                    decoration: BoxDecoration(
                      color: _Brand.creamWhite,
                      borderRadius: BorderRadius.circular(isWide ? 32 : 0),
                    ),
                    child: _buildForm(isWide),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(bool isWide) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, isWide ? 36 : 28, 28, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Back + Logo
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                const Spacer(),
                Image.asset(
                  'assets/icons/dagina2.png',
                  height: 44,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                const SizedBox(width: 40), // balance
              ],
            ),

            const SizedBox(height: 28),

            Text(
              'Create your account',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideX(begin: -0.1, end: 0),

            const SizedBox(height: 4),
            Text(
              'Join Dagina.Designs and explore personalised jewellery',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

            const SizedBox(height: 28),

            _buildLabel('Username'),
            const SizedBox(height: 6),
            _buildTextFormField(
              controller: _usernameController,
              hint: 'Choose a unique username',
              icon: Icons.person_outline_rounded,
              validator: (val) =>
                  (val == null || val.isEmpty) ? 'Username is required' : null,
            ),

            const SizedBox(height: 16),
            _buildLabel('Email'),
            const SizedBox(height: 6),
            _buildTextFormField(
              controller: _emailController,
              hint: 'your.email@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Email is required';
                if (!val.contains('@')) return 'Please enter a valid email';
                return null;
              },
            ),

            const SizedBox(height: 16),
            _buildLabel('Password'),
            const SizedBox(height: 6),
            _buildPasswordField(),

            const SizedBox(height: 16),
            _buildLabel('Phone Number'),
            const SizedBox(height: 6),
            IntlPhoneField(
              decoration: _inputDecoration(
                hint: 'Enter phone number',
                prefixIcon: null,
              ),
              dropdownIconPosition: IconPosition.leading,
              pickerDialogStyle: PickerDialogStyle(
                width: MediaQuery.of(context).size.width * 0.85,
                searchFieldInputDecoration: InputDecoration(
                  labelText: 'Search country',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              initialCountryCode: 'IN',
              onChanged: (phone) {
                _fullPhoneNumber = phone.completeNumber;
              },
              validator: (phone) {
                if (phone == null || phone.number.isEmpty) {
                  return 'Phone number is required';
                }
                if (!phone.isValidNumber()) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),
            _buildLabel('Date of Birth'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _birthdateController,
              readOnly: true,
              onTap: () => _selectDate(context),
              decoration: _inputDecoration(
                hint: 'YYYY-MM-DD',
                prefixIcon: Icons.cake_outlined,
              ).copyWith(
                suffixIcon: const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Color(0xFF888888),
                ),
              ),
              validator: (val) => (val == null || val.isEmpty)
                  ? 'Date of birth is required'
                  : null,
            ),

            const SizedBox(height: 16),
            _buildLabel('Referral Code (Optional)'),
            const SizedBox(height: 6),
            _buildTextFormField(
              controller: _referralCodeController,
              hint: 'Enter referral code',
              icon: Icons.card_giftcard_outlined,
            ),

            const SizedBox(height: 32),

            // ── Sign Up Button ──────────────────────────────────────────────
            GestureDetector(
              onTap: _isLoading ? null : _signUp,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2D5A27), Color(0xFF1A3A18)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2D5A27).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Create Account',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF666666),
                  ),
                  children: [
                    const TextSpan(text: 'Already a member? '),
                    TextSpan(
                      text: 'Log in',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: _Brand.forestGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            _buildTermsText(),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF333333),
        letterSpacing: 0.2,
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: Colors.grey.shade400,
        fontSize: 14,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 18, color: const Color(0xFF888888))
          : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _Brand.forestGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1A1A1A)),
      decoration: _inputDecoration(hint: hint, prefixIcon: icon),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1A1A1A)),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Password is required';
        if (value.length < 8) return 'Must be at least 8 characters';
        if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
          return 'Must contain an uppercase letter';
        }
        if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
          return 'Must contain a lowercase letter';
        }
        if (!RegExp(r'(?=.*[0-9])').hasMatch(value)) {
          return 'Must contain a number';
        }
        if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
          return 'Must contain a special character';
        }
        return null;
      },
      decoration: _inputDecoration(hint: 'Create a strong password', prefixIcon: Icons.lock_outline_rounded).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
            color: const Color(0xFF888888),
          ),
          onPressed: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
      ),
    );
  }

  Widget _buildTermsText() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.inter(
          color: const Color(0xFFAAAAAA),
          fontSize: 10.5,
          height: 1.5,
        ),
        children: [
          const TextSpan(text: 'By continuing, you agree to Dagina.Designs '),
          TextSpan(
            text: 'Terms of Service',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF555555),
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () =>
                  _launchLegalUrl('https://www.dagina.design/terms.html'),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF555555),
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () =>
                  _launchLegalUrl('https://www.dagina.design/privacy.html'),
          ),
        ],
      ),
    );
  }
}
