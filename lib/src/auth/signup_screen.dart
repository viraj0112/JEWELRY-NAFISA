import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/auth/business_signup_screen.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/auth/email_signup_screen.dart';
import 'package:jewelry_nafisa/src/auth/phone_auth_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand constants
// ─────────────────────────────────────────────────────────────────────────────
class _Brand {
  static const Color forestGreen = Color(0xFF2D5A27);
  static const Color creamWhite = Color(0xFFFAF8F5);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Sign-Up Entry Screen
// ─────────────────────────────────────────────────────────────────────────────
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _authService = SupabaseAuthService();
  bool _isGoogleLoading = false;
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
    // Delay the sheet slide-in for a dramatic reveal
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _sheetController.forward();
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    await FirebaseAnalytics.instance.logEvent(name: 'sign_up_google_attempt');
    await _authService.signInWithGoogle();
    if (mounted) setState(() => _isGoogleLoading = false);
  }

  Future<void> _launchLegalUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

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
            // ── Full-screen background ──────────────────────────────────────
            Positioned.fill(
              child: Image.asset(
                'assets/icons/loginscreen.jpg',
                fit: BoxFit.cover,
              ),
            ),

            // ── Dark gradient overlay ───────────────────────────────────────
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x55000000),
                      Color(0xCC000000),
                      Color(0xF5000000),
                    ],
                    stops: [0.0, 0.3, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            // ── Top branding (logo + tagline) ───────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/icons/dagina2.png',
                      height: 80,
                      fit: BoxFit.contain,
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 200.ms)
                        .slideY(begin: -0.2, end: 0, curve: Curves.easeOut),
                  ],
                ),
              ),
            ),

            // ── Bottom sheet card ───────────────────────────────────────────
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
          // Drag handle pill
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
                // Headline
                Text(
                  'Welcome to\nDagina.Designs',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                    height: 1.2,
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

                const SizedBox(height: 28),

                // ── Continue With Email ─────────────────────────────────────
                _PrimaryButton(
                  label: 'Continue With Email',
                  icon: Icons.email_outlined,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EmailSignUpScreen()),
                    );
                  },
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 500.ms)
                    .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),

                const SizedBox(height: 12),

                // ── Continue With Phone Number ──────────────────────────────
                _PrimaryButton(
                  label: 'Continue With Phone Number',
                  icon: Icons.phone_outlined,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PhoneAuthScreen()),
                    );
                  },
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 600.ms)
                    .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),

                const SizedBox(height: 20),

                // ── Divider ─────────────────────────────────────────────────
                _buildDivider()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 700.ms),

                const SizedBox(height: 20),

                // ── Continue with Google ────────────────────────────────────
                _GoogleButton(
                  isLoading: _isGoogleLoading,
                  onPressed: _signUpWithGoogle,
                ).animate().fadeIn(duration: 400.ms, delay: 750.ms),

                const SizedBox(height: 20),

                // ── Already a member ────────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF555555),
                      ),
                      children: [
                        const TextSpan(text: 'Already a member? '),
                        TextSpan(
                          text: 'Log in',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _Brand.forestGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 800.ms),

                const SizedBox(height: 16),

                // ── Terms text ──────────────────────────────────────────────
                _buildTermsText(),

                const SizedBox(height: 8),

                // ── Business account link ───────────────────────────────────
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const BusinessSignUpScreen()),
                    );
                  },
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF888888),
                      ),
                      children: [
                        const TextSpan(text: 'Are you a designer? '),
                        TextSpan(
                          text: 'Create a business account',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _Brand.forestGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 850.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: Colors.grey.shade300, thickness: 1),
        ),
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
        Expanded(
          child: Divider(color: Colors.grey.shade300, thickness: 1),
        ),
      ],
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
              ..onTap =
                  () => _launchLegalUrl('https://www.dagina.design/terms.html'),
          ),
          const TextSpan(text: ' and acknowledge you\'ve read our '),
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

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Primary Button (dark green gradient)
// ─────────────────────────────────────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isHovered
                  ? [const Color(0xFF4A7C59), const Color(0xFF2D5A27)]
                  : [const Color(0xFF2D5A27), const Color(0xFF1A3A18)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color:
                    const Color(0xFF2D5A27).withOpacity(_isHovered ? 0.4 : 0.2),
                blurRadius: _isHovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google Sign-In Button
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
                    // Google 'G' logo using colored text
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
