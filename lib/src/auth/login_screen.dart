import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/ui/widgets/social_auth_button.dart';
import 'package:jewelry_nafisa/src/auth/signup_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = SupabaseAuthService();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final user = await _authService.signInWithEmailOrUsername(
        _emailOrUsernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user == null) {
        _showErrorSnackbar('Login failed. Please check your credentials.');
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    await _authService.signInWithGoogle();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Reset Password"),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Enter your email'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _authService.resetPassword(
                      emailController.text.trim(),
                    );
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Password reset link sent. Please check your email.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    if (mounted) {
                      _showErrorSnackbar(
                        'Failed to send reset link. Please try again.',
                      );
                    }
                  }
                }
              },
              child: const Text("Send Link"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-screen background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://static.vecteezy.com/system/resources/previews/035/081/140/non_2x/women-s-jewelry-gold-chain-trendy-jewelry-on-a-silk-background-photo.JPG',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // 2. Centered, floating form with blur effect
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                    child: Container(
                      width: 480,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color.fromRGBO(0, 0, 0, 0.5)
                            : const Color.fromRGBO(255, 255, 255, 0.8),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: isDarkMode
                              ? const Color.fromRGBO(255, 255, 255, 0.2)
                              : const Color.fromRGBO(0, 0, 0, 0.1),
                        ),
                      ),
                      child: _buildFormContents(theme),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContents(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'AKD',
            textAlign: TextAlign.center,
            style: GoogleFonts.ptSerif(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            
            selectionColor: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome Back',
            textAlign: TextAlign.center,
            style: GoogleFonts.ptSerif(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
            
            selectionColor: theme.colorScheme.primary,
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: _emailOrUsernameController,
            decoration: InputDecoration(
              labelText: 'Email or Username',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            validator: (value) => (value == null || value.isEmpty)
                ? 'This field is required'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            validator: (value) => (value == null || value.length < 6)
                ? 'Password must be at least 6 characters'
                : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              child: const Text('Forgot your password?'),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _isLoading ? null : _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : const Text('Log In'),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('OR'),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          SocialAuthButton(
            text: 'Continue with Google',
            backgroundColor: Colors.white,
            textColor: Colors.black,
            icon: Icons.g_mobiledata_rounded,
            onPressed: _isLoading ? () {} : _signInWithGoogle,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignUpScreen()),
            ),
            child: const Text("Not on the app yet? Sign up"),
          ),
        ],
      ),
    );
  }
}
