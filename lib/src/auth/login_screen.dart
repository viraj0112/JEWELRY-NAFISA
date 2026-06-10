
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/auth/signup_screen.dart';
import 'package:jewelry_nafisa/src/auth/phone_auth_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand constants
// ─────────────────────────────────────────────────────────────────────────────
class _Brand {
  static const Color forestGreen = Color(0xFF2D5A27);
  static const Color creamWhite = Color(0xFFFAF8F5);
}

// ─────────────────────────────────────────────────────────────────────────────
// Login Screen
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = SupabaseAuthService();

  bool _isPasswordVisible = false;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;

  // Tab: 0 = Email/Password, 1 = Phone OTP
  int _selectedTab = 0;

  late AnimationController _sheetController;
  late Animation<Offset> _sheetAnimation;

  @override
  void initState() {
    super.initState();
    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _sheetAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _sheetController,
      curve: Curves.easeOutCubic,
    ));
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _sheetController.forward();
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.redAccent.shade700 : _Brand.forestGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    await FirebaseAnalytics.instance.logLogin(loginMethod: 'email');
    setState(() => _isEmailLoading = true);

    final user = await _authService.signInWithEmailOrUsername(
      _emailOrUsernameController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;
    if (user != null) {
      await _finalizePendingSignupUploads();
      if (!mounted) return;
      GoRouter.of(context).go('/');
    } else {
      setState(() => _isEmailLoading = false);
      _showSnackbar('Login failed. Please check your credentials.');
    }
  }

  Future<void> _finalizePendingSignupUploads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signupId = prefs.getString('pending_signup_id');
      if (signupId == null || signupId.isEmpty) return;
      final supabase = Supabase.instance.client;
      final res = await supabase.functions.invoke(
        'finalize-signup-uploads',
        body: {'signup_id': signupId},
      );
      if (res.status == 200) await prefs.remove('pending_signup_id');
    } catch (_) {}
  }

  Future<void> _signInWithGoogle() async {
    await FirebaseAnalytics.instance.logLogin(loginMethod: 'google');
    setState(() => _isGoogleLoading = true);
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      _showSnackbar('Google Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset Password',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailController,
            decoration: InputDecoration(
              labelText: 'Enter your email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your email';
              if (!value.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await _authService.resetPassword(emailController.text.trim());
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  _showSnackbar(
                    'Password reset link sent. Please check your email.',
                    isError: false,
                  );
                } catch (e) {
                  if (mounted) {
                    _showSnackbar('Failed to send reset link. Please try again.');
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _Brand.forestGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Send Link', style: TextStyle(color: Colors.white)),
          ),
        ],
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

    return PopScope(
      canPop: true,
      child: Scaffold(
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x44000000),
                      Color(0xBB000000),
                      Color(0xF2000000),
                    ],
                    stops: [0.0, 0.25, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // ── Top logo ────────────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: Image.asset(
                    'assets/icons/dagina2.png',
                    height: 72,
                    fit: BoxFit.contain,
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 200.ms)
                      .slideY(begin: -0.2, end: 0, curve: Curves.easeOut),
                ),
              ),
            ),

            // ── Bottom sheet ────────────────────────────────────────────────
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: _sheetAnimation,
                child: _buildBottomCard(context, isWide),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCard(BuildContext context, bool isWide) {
    return Container(
      width: isWide ? 520 : double.infinity,
      margin: isWide ? const EdgeInsets.only(bottom: 40) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: _Brand.creamWhite,
        borderRadius: isWide
            ? BorderRadius.circular(32)
            : const BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isWide)
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(28, isWide ? 36 : 24, 28, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Welcome text ───────────────────────────────────────────
                Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 400.ms),

                const SizedBox(height: 4),
                Text(
                  'Sign in to continue to Dagina.Designs',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 500.ms),

                const SizedBox(height: 24),

                // ── Tab toggle: Email | Phone ───────────────────────────────
                _buildTabToggle()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 550.ms),

                const SizedBox(height: 24),

                // ── Tab content ─────────────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedTab == 0
                      ? _buildEmailForm()
                      : _buildPhoneOption(),
                ),

                const SizedBox(height: 20),

                // ── Divider ─────────────────────────────────────────────────
                _buildDivider()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 700.ms),

                const SizedBox(height: 20),

                // ── Google login ────────────────────────────────────────────
                _GoogleButton(
                  isLoading: _isGoogleLoading,
                  onPressed: _signInWithGoogle,
                ).animate().fadeIn(duration: 400.ms, delay: 750.ms),

                const SizedBox(height: 20),

                // ── Sign Up link ────────────────────────────────────────────
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF555555),
                      ),
                      children: [
                        const TextSpan(text: "Not on the app yet? "),
                        TextSpan(
                          text: 'Sign up',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: _Brand.forestGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Email / Password Form ─────────────────────────────────────────────────
  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('email_form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailOrUsernameController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1A1A1A)),
            decoration: _inputDeco(
              label: 'Email or Username',
              icon: Icons.person_outline_rounded,
            ),
            validator: (val) => (val == null || val.isEmpty)
                ? 'This field is required'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            autofillHints: const [AutofillHints.password],
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1A1A1A)),
            decoration: _inputDeco(
              label: 'Password',
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
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            validator: (val) =>
                (val == null || val.length < 6)
                    ? 'Password must be at least 6 characters'
                    : null,
            onEditingComplete: _signIn,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              child: Text(
                'Forgot password?',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _Brand.forestGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildLoginButton(),
        ],
      ),
    );
  }

  // ── Phone OTP option ──────────────────────────────────────────────────────
  Widget _buildPhoneOption() {
    return Column(
      key: const ValueKey('phone_option'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7EE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB8D9B0)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.phone_iphone_rounded,
                size: 36,
                color: _Brand.forestGreen,
              ),
              const SizedBox(height: 8),
              Text(
                'Log in with your phone number',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF333333),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "We'll send a one-time code to your number",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PhoneAuthScreen(isLoginMode: true),
              ),
            );
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_Brand.forestGreen, Color(0xFF1A3A18)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: _Brand.forestGreen.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Continue with Phone Number',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isEmailLoading ? null : _signIn,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_Brand.forestGreen, Color(0xFF1A3A18)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _Brand.forestGreen.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isEmailLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  'Log In',
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

  Widget _buildTabToggle() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _buildTab(label: 'Email', index: 0),
          _buildTab(label: 'Phone', index: 1),
        ],
      ),
    );
  }

  Widget _buildTab({required String label, required int index}) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? _Brand.forestGreen : Colors.grey.shade500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
      ],
    );
  }

  InputDecoration _inputDeco({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        color: Colors.grey.shade600,
      ),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF888888)),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Google Button widget
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GoogleButton({required this.isLoading, required this.onPressed});

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFF5F5F5) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFDDDDDD), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isHovered ? 0.08 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: widget.isLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF2D5A27),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'G',
                      style: GoogleFonts.roboto(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4285F4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF333333),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
