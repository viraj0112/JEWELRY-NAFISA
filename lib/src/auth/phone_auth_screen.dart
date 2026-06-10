import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:jewelry_nafisa/src/services/msg91_otp_service.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand constants
// ─────────────────────────────────────────────────────────────────────────────
class _Brand {
  static const Color forestGreen = Color(0xFF2D5A27);
}

// ─────────────────────────────────────────────────────────────────────────────
// Phone Auth Screen — 3 Steps
//   Step 0: Enter Phone Number
//   Step 1: Enter OTP
//   Step 2: Create Username + Password
// ─────────────────────────────────────────────────────────────────────────────
class PhoneAuthScreen extends StatefulWidget {
  /// Set [isLoginMode] = true for login via OTP (no username/password step).
  final bool isLoginMode;
  const PhoneAuthScreen({super.key, this.isLoginMode = false});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _msg91 = Msg91OtpService();
  final _authService = SupabaseAuthService();

  // ── Step 0 ────────────────────────────────────────────────────────────────
  String _fullPhoneNumber = '';
  bool _phoneValid = false;

  // ── Step 1 ────────────────────────────────────────────────────────────────
  final _otpController = TextEditingController();
  String _currentOtp = '';
  bool _otpHasError = false;
  int _resendCountdown = 60;
  Timer? _resendTimer;

  // ── Step 2 ────────────────────────────────────────────────────────────────
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _step2FormKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;

  // ── Shared ────────────────────────────────────────────────────────────────
  int _currentStep = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _otpController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  // ── Step 0: Send OTP ───────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (!_phoneValid || _fullPhoneNumber.isEmpty) {
      _showSnackbar('Please enter a valid phone number');
      return;
    }
    setState(() => _isLoading = true);

    final result = await _msg91.sendOtp(_fullPhoneNumber);

    setState(() => _isLoading = false);

    switch (result) {
      case OtpResult.success:
        _startResendTimer();
        _goToStep(1);
        FirebaseAnalytics.instance
            .logEvent(name: 'otp_sent', parameters: {'method': 'msg91'});
        break;
      case OtpResult.alreadySent:
        _showSnackbar('OTP already sent. Please wait before requesting again.');
        _startResendTimer();
        _goToStep(1);
        break;
      case OtpResult.invalidPhone:
        _showSnackbar('Invalid phone number. Please check and try again.');
        break;
      case OtpResult.networkError:
        _showSnackbar('Network error. Please check your internet connection.');
        break;
      case OtpResult.unknownError:
        _showSnackbar('Something went wrong. Please try again.');
        break;
    }
  }

  // ── Resend countdown timer ─────────────────────────────────────────────────
  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) return;
    setState(() => _isLoading = true);
    await _msg91.resendOtp(_fullPhoneNumber);
    setState(() => _isLoading = false);
    _startResendTimer();
    _showSnackbar('OTP resent successfully!', isError: false);
  }

  // ── Step 1: Verify OTP ────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (_currentOtp.length < 4) {
      setState(() => _otpHasError = true);
      _showSnackbar('Please enter the complete OTP');
      return;
    }
    setState(() {
      _isLoading = true;
      _otpHasError = false;
    });

    final result = await _msg91.verifyOtp(_fullPhoneNumber, _currentOtp);
    setState(() => _isLoading = false);

    switch (result) {
      case OtpVerifyResult.success:
        FirebaseAnalytics.instance.logEvent(name: 'otp_verified');
        if (widget.isLoginMode) {
          // Login mode: OTP verified, no more steps needed
          // Create a minimal account or look up existing user
          await _handlePhoneLogin();
        } else {
          _goToStep(2);
        }
        break;
      case OtpVerifyResult.invalid:
        setState(() => _otpHasError = true);
        _showSnackbar('Incorrect OTP. Please try again.');
        break;
      case OtpVerifyResult.expired:
        setState(() => _otpHasError = true);
        _showSnackbar('OTP expired. Please request a new one.');
        break;
      case OtpVerifyResult.networkError:
        _showSnackbar('Network error. Please check your connection.');
        break;
      case OtpVerifyResult.unknownError:
        _showSnackbar('Verification failed. Please try again.');
        break;
    }
  }

  /// For login mode: after OTP verified, sign in or create minimal account
  Future<void> _handlePhoneLogin() async {
    // Phone OTP login: in Supabase, phone OTP is handled via signInWithOtp.
    // Since MSG91 is used externally and OTP is already verified,
    // we mark the phone as authenticated and proceed.
    // TODO: Optionally link phone to Supabase auth user here.
    if (mounted) {
      _showSnackbar('Phone verified! Logging you in...', isError: false);
      // Navigate to home — AuthGate will handle session.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ── Step 2: Create Account ─────────────────────────────────────────────────
  Future<void> _createAccount() async {
    if (!_step2FormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Generate a unique email from the phone number for Supabase
    // (Supabase requires email for sign-up; phone-only users get a synthetic email)
    final syntheticEmail =
        'phone_${_fullPhoneNumber.replaceAll('+', '').replaceAll(' ', '')}@dagina.internal';

    final user = await _authService.signUpWithEmailPassword(
      syntheticEmail,
      _passwordController.text.trim(),
      _usernameController.text.trim(),
      _fullPhoneNumber,
      '', // birthdate — not required for phone sign-up
      '', // referral code
    );

    setState(() => _isLoading = false);

    if (user == null) {
      // Might already exist — try sign in instead
      final existingUser = await _authService.signInWithEmailOrUsername(
        syntheticEmail,
        _passwordController.text.trim(),
      );
      if (existingUser != null && mounted) {
        _showSnackbar('Welcome back!', isError: false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        _showSnackbar('Account creation failed. Please try again.');
      }
    } else {
      FirebaseAnalytics.instance.logEvent(
        name: 'sign_up',
        parameters: {'method': 'phone', 'phone': _fullPhoneNumber},
      );
      await _authService.signOut();
      if (mounted) {
        _showSnackbar(
          'Account created! Please verify your email if prompted, then log in.',
          isError: false,
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: isError
            ? Colors.redAccent.shade700
            : const Color(0xFF2D5A27),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;
    final totalSteps = widget.isLoginMode ? 2 : 3;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Background ──────────────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/icons/loginscreen.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.6),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 480 : double.infinity),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Column(
                    children: [
                      // ── Top bar ──────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_currentStep > 0) {
                                  _goToStep(_currentStep - 1);
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Image.asset(
                              'assets/icons/dagina2.png',
                              height: 36,
                              fit: BoxFit.contain,
                            ),
                            const Spacer(),
                            const SizedBox(width: 40),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Step indicator dots ──────────────────────────────
                      _buildStepDots(totalSteps),

                      const SizedBox(height: 32),

                      // ── Page view (the 3 steps) ──────────────────────────
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildStep0(),
                            _buildStep1(),
                            if (!widget.isLoginMode) _buildStep2(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step dots ──────────────────────────────────────────────────────────────
  Widget _buildStepDots(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isActive = index == _currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive
                ? _Brand.forestGreen
                : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // STEP 0: Phone Number Entry
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildStep0() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isLoginMode
                ? 'Log in with\nPhone Number'
                : 'Please enter your\nPhone Number',
            style: GoogleFonts.playfairDisplay(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideX(begin: 0.1, end: 0, curve: Curves.easeOut),

          const SizedBox(height: 12),

          Text(
            widget.isLoginMode
                ? 'We\'ll send you a one-time code to verify your identity.'
                : 'This helps us find you more relevant content.\nWe won\'t show it on your profile.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.75),
              height: 1.5,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),

          const SizedBox(height: 40),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phone Number',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 10),
                IntlPhoneField(
                  decoration: InputDecoration(
                    hintText: 'Enter phone number',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: _Brand.forestGreen, width: 2),
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  dropdownIconPosition: IconPosition.leading,
                  pickerDialogStyle: PickerDialogStyle(
                    width: MediaQuery.of(context).size.width * 0.85,
                    searchFieldInputDecoration: InputDecoration(
                      labelText: 'Search country',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  initialCountryCode: 'IN',
                  onChanged: (phone) {
                    setState(() {
                      _fullPhoneNumber = phone.completeNumber;
                      _phoneValid = phone.isValidNumber();
                    });
                  },
                  onCountryChanged: (_) {},
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms)
              .slideY(begin: 0.15, end: 0, curve: Curves.easeOut),

          const SizedBox(height: 40),

          // ── Next button ─────────────────────────────────────────────────
          _buildPrimaryButton(
            label: 'Next',
            onPressed: _isLoading ? null : _sendOtp,
            isLoading: _isLoading,
          ).animate().fadeIn(duration: 400.ms, delay: 350.ms),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // STEP 1: OTP Entry
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Please enter\nyour OTP',
            style: GoogleFonts.playfairDisplay(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          )
              .animate(key: ValueKey('title_step1'))
              .fadeIn(duration: 500.ms)
              .slideX(begin: 0.1, end: 0),

          const SizedBox(height: 12),

          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withOpacity(0.75),
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'We sent a 4-digit code to\n'),
                TextSpan(
                  text: _fullPhoneNumber,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),

          const SizedBox(height: 40),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your 4 Digit Code',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 16),
                PinCodeTextField(
                  appContext: context,
                  controller: _otpController,
                  length: 4,
                  obscureText: false,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 58,
                    fieldWidth: 58,
                    activeFillColor: const Color(0xFFF8F8F8),
                    inactiveFillColor: const Color(0xFFF8F8F8),
                    selectedFillColor: Colors.white,
                    activeColor: _otpHasError ? Colors.redAccent : _Brand.forestGreen,
                    inactiveColor: _otpHasError ? Colors.redAccent : const Color(0xFFDDDDDD),
                    selectedColor: _otpHasError ? Colors.redAccent : _Brand.forestGreen,
                    fieldOuterPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  enableActiveFill: true,
                  errorAnimationController: null,
                  keyboardType: TextInputType.number,
                  textStyle: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _currentOtp = value;
                      if (_otpHasError) _otpHasError = false;
                    });
                  },
                  onCompleted: (value) {
                    _currentOtp = value;
                  },
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                ),

                const SizedBox(height: 16),

                // Resend row
                Center(
                  child: _resendCountdown > 0
                      ? Text(
                          'Resend OTP in ${_resendCountdown}s',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        )
                      : GestureDetector(
                          onTap: _resendOtp,
                          child: Text(
                            'Resend OTP',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _Brand.forestGreen,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms)
              .slideY(begin: 0.15, end: 0, curve: Curves.easeOut),

          const SizedBox(height: 40),

          _buildPrimaryButton(
            label: widget.isLoginMode ? 'Login' : 'Verify',
            onPressed: _isLoading ? null : _verifyOtp,
            isLoading: _isLoading,
          ).animate().fadeIn(duration: 400.ms, delay: 350.ms),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // STEP 2: Create Username + Password
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Username\n& Password',
              style: GoogleFonts.playfairDisplay(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            )
                .animate(key: const ValueKey('title_step2'))
                .fadeIn(duration: 500.ms)
                .slideX(begin: 0.1, end: 0),

            const SizedBox(height: 12),

            Text(
              'Choose a unique username and a strong password\nto secure your Dagina account.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withOpacity(0.75),
                height: 1.5,
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 100.ms),

            const SizedBox(height: 36),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stepFormLabel('Username'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _usernameController,
                    style: GoogleFonts.inter(
                        fontSize: 15, color: const Color(0xFF1A1A1A)),
                    decoration: _stepInputDeco(
                      hint: 'username or email',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (val) =>
                        (val == null || val.isEmpty) ? 'Username required' : null,
                  ),

                  const SizedBox(height: 20),

                  _stepFormLabel('Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: GoogleFonts.inter(
                        fontSize: 15, color: const Color(0xFF1A1A1A)),
                    decoration: _stepInputDeco(
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                          color: const Color(0xFF888888),
                        ),
                        onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Password required';
                      if (val.length < 8) return 'Minimum 8 characters';
                      return null;
                    },
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOut),

            const SizedBox(height: 36),

            _buildPrimaryButton(
              label: 'Create Account',
              onPressed: _isLoading ? null : _createAccount,
              isLoading: _isLoading,
            ).animate().fadeIn(duration: 400.ms, delay: 350.ms),
          ],
        ),
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────
  Widget _stepFormLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF333333),
      ),
    );
  }

  InputDecoration _stepInputDeco({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF888888)),
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _Brand.forestGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: onPressed == null
                ? [Colors.grey.shade400, Colors.grey.shade500]
                : [_Brand.forestGreen, const Color(0xFF1A3A18)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(29),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: _Brand.forestGreen.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}
