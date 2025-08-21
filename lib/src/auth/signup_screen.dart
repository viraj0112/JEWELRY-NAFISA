import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

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

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signUp() async {
    // Make sure all validators pass
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final user = await _authService.signUpWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _usernameController.text.trim(),
        _birthdateController.text.trim(),
        context,
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (user == null) {
        _showErrorSnackbar(
            'Sign up failed. The email might already be in use.');
      } else {
        await _authService.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Account created! Please log in.')),
          );
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    await _authService.signInWithGoogle();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
      backgroundColor: theme.scaffoldBackgroundColor, // Theme-aware background
      body: Stack(
        children: [
          _buildBackgroundGrid(),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double formWidth =
                    constraints.maxWidth > 500 ? 480.0 : constraints.maxWidth * 0.95;
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Container(
                      width: formWidth,
                      // **MODIFIED: Unified form background color from theme**
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: _buildForm(theme),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGrid() {
    return MasonryGridView.count(
      crossAxisCount: 4,
      itemCount: 20,
      itemBuilder: (BuildContext context, int index) => Opacity(
        opacity: 0.5,
        // **MODIFIED: Using a more reliable image provider**
        child: Image.network(
          'https://picsum.photos/200/300?random=$index',
          fit: BoxFit.cover,
        ),
      ),
      mainAxisSpacing: 4.0,
      crossAxisSpacing: 4.0,
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(34, 16, 34, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'AKD',
              style: GoogleFonts.ptSerif(
                color: theme.colorScheme.primary,
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Welcome to AKD Designs",
              style: GoogleFonts.ptSerif(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Find new ideas to try",
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildTextField(
                label: "Username",
                controller: _usernameController,
                hint: "Choose a username",
                validator: (val) =>
                    val!.isEmpty ? "Username is required" : null),
            const SizedBox(height: 16),
            _buildTextField(
                label: "Email",
                controller: _emailController,
                hint: "Your email address",
                validator: (val) {
                  if (val == null || val.isEmpty) return "Email is required";
                  if (!val.contains('@') || !val.contains('.')) {
                    return "Enter a valid email";
                  }
                  return null;
                }),
            const SizedBox(height: 16),
            _buildPasswordField(),
            const SizedBox(height: 16),
            _buildDateField(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Continue'),
              ),
            ),
            const SizedBox(height: 16),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('OR')),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _signUpWithGoogle,
                icon: Icon(BrandIcons.google, color: Colors.blue, size: 24),
                label: const Text('Continue with Google'),
              ),
            ),
            const SizedBox(height: 24),
            _buildTermsText(),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Text(
                'Already a member? Log in',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      {required String label,
      required TextEditingController controller,
      required String hint,
      String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Password", style: TextStyle(fontWeight: FontWeight.normal, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          // **MODIFIED: New stricter password validation**
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters long';
            }
            if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
              return 'Must contain at least one uppercase letter';
            }
            if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
              return 'Must contain at least one lowercase letter';
            }
            if (!RegExp(r'(?=.*[0-9])').hasMatch(value)) {
              return 'Must contain at least one number';
            }
            if (!RegExp(r'(?=.*[!@#$%^&*(),.?":{}|<>])').hasMatch(value)) {
              return 'Must contain at least one special character';
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

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Birthdate", style: TextStyle(fontWeight: FontWeight.normal, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _birthdateController,
          readOnly: true,
          onTap: () => _selectDate(context),
          // **MODIFIED: Added validator to make it required**
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Your birthdate is required';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: "dd-mm-yyyy",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
          children: [
            const TextSpan(text: "By continuing, you agree to our "),
            TextSpan(
              text: "Terms of Service",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              recognizer: TapGestureRecognizer()..onTap = () {},
            ),
            const TextSpan(text: " and acknowledge you've read our "),
            TextSpan(
              text: "Privacy Policy.",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              recognizer: TapGestureRecognizer()..onTap = () {},
            ),
          ],
        ),
      ),
    );
  }
}