import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:jewelry_nafisa/src/auth/business_signup_screen.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';

// A utility class for brand-specific icons
class BrandIcons {
  static const IconData google = Icons.g_mobiledata_rounded;
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _authService = SupabaseAuthService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  // Shows a consistent error message at the bottom of the screen
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // Handles the user registration process
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = await _authService.signUpWithEmailPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _usernameController.text.trim(),
      _birthdateController.text.trim(),
      _referralCodeController.text
          .trim(), // Corrected: Pass the referral code here instead of context
    );
    if (mounted) setState(() => _isLoading = false);

    if (user == null) {
      _showErrorSnackbar('Sign up failed. The email might already be in use.');
    } else {
      // Sign out immediately after signup to force the user to log in
      await _authService.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created! Please check your email to verify and then log in.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  // Initiates the Google sign-in flow
  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    await _authService.signInWithGoogle();
    if (mounted) setState(() => _isLoading = false);
  }

  // Shows a date picker dialog to select the user's birthdate
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 18),
      ), // Default to 18 years ago
      firstDate: DateTime(1920, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthdateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          _buildBackgroundGrid(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 48.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((255 * 0.1).round()),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _buildForm(theme),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Creates the decorative background grid of images
  Widget _buildBackgroundGrid() {
    return MasonryGridView.count(
      crossAxisCount: 4,
      itemCount: 20,
      itemBuilder: (BuildContext context, int index) => Opacity(
        opacity: 0.5,
        child: Image.network(
          'https://picsum.photos/200/300?random=$index',
          fit: BoxFit.cover,
        ),
      ),
      mainAxisSpacing: 4.0,
      crossAxisSpacing: 4.0,
    );
  }

  // Builds the main registration form
  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(34, 24, 34, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'AKD',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text(
              "Welcome to AKD Designs",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              "Find new ideas to try",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _buildTextField(
              label: "Username",
              controller: _usernameController,
              hint: "Choose a unique username",
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: "Email",
              controller: _emailController,
              hint: "your.email@example.com",
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(),
            const SizedBox(height: 16),
            _buildDateField(),
            TextFormField(
              controller: _referralCodeController,
              decoration: InputDecoration(
                labelText: 'Referral Code (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
            const SizedBox(height: 16),
            _buildDivider(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _signUpWithGoogle,
              icon: Icon(BrandIcons.google, color: Colors.blue, size: 24),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 24),
            _buildTermsText(context),
            const SizedBox(height: 16),
            _buildLoginLink(context),
            const SizedBox(height: 16),
            _buildBusinessAccountLink(context, theme),
          ],
        ),
      ),
    );
  }

  // A generic text field widget for the form
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: (val) =>
              (val == null || val.isEmpty) ? '$label is required' : null,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  // Password field with visibility toggle and stricter validation
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Password", style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Password is required';
            if (value.length < 8) {
              return 'Password must be at least 8 characters long';
            }
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
          decoration: InputDecoration(
            hintText: "Create a password",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
        ),
      ],
    );
  }

  // A read-only text field that opens the date picker
  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Birthdate", style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _birthdateController,
          readOnly: true,
          onTap: () => _selectDate(context),
          validator: (value) => (value == null || value.isEmpty)
              ? 'Your birthdate is required'
              : null,
          decoration: InputDecoration(
            hintText: "YYYY-MM-DD",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
          ),
        ),
      ],
    );
  }

  // A simple divider with "OR" text in the middle
  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('OR'),
        ),
        Expanded(child: Divider()),
      ],
    );
  }

  // The text for terms of service and privacy policy
  Widget _buildTermsText(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
        children: [
          const TextSpan(text: "By continuing, you agree to our "),
          TextSpan(
            text: "Terms of Service",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                /* TODO: Navigate to Terms URL */
              },
          ),
          const TextSpan(text: " and acknowledge you've read our "),
          TextSpan(
            text: "Privacy Policy.",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                /* TODO: Navigate to Privacy URL */
              },
          ),
        ],
      ),
    );
  }

  // A link to navigate back to the login screen
  Widget _buildLoginLink(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Already a member? Log in'),
    );
  }

  // A link to the business account creation screen
  Widget _buildBusinessAccountLink(BuildContext context, ThemeData theme) {
    return TextButton(
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const BusinessSignUpScreen()));
      },
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            color: theme.textTheme.bodySmall?.color ?? Colors.grey,
          ),
          children: [
            const TextSpan(text: 'Are you a designer? '),
            TextSpan(
              text: 'Create a business account',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
