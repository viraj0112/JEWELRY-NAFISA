import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:jewelry_nafisa/src/auth/firebase_auth_service.dart';
import 'package:jewelry_nafisa/src/ui/widgets/social_auth_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController(); // Added for username
  final _birthdateController = TextEditingController();
  final _authService = FirebaseAuthService();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final user = await _authService.signUpWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _usernameController.text.trim(),
        _birthdateController.text.trim(), // Pass the birthdate text
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (user == null) {
        _showErrorSnackbar(
            'Sign up failed. The email might already be in use.');
      }
    }
  }

Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    final user = await _authService.signInWithGoogle();
     if (mounted) {
        setState(() => _isLoading = false);
     }
    if (user == null) {
      _showErrorSnackbar('Google sign-in was cancelled or failed.');
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
        _birthdateController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Stack(
        children: [
          Container(color: Colors.black.withOpacity(0.2)),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double formWidth = constraints.maxWidth > 520 ? 480.0 : constraints.maxWidth * 0.95;
                return SingleChildScrollView(
                  child: Center(
                    child: Container(
                      width: formWidth,
                      margin: const EdgeInsets.symmetric(vertical: 24.0),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                      child: _buildForm(),
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

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
          ),
          const SizedBox(height: 16),
          Text("Welcome to AKD Designs", style: GoogleFonts.ptSerif(fontSize: 32, fontWeight: FontWeight.bold, color: const Color.fromARGB(213, 255, 214, 64)), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text("It's time to refresh your collection", style: GoogleFonts.lato(fontSize: 16, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          // Added Username Field
          _buildTextField(label: "Username", controller: _usernameController, hint: "Choose a username", validator: (val) => val!.isEmpty ? "Username cannot be empty" : null),
          const SizedBox(height: 16),
          _buildTextField(label: "Email", controller: _emailController, hint: "Email", validator: (val) => !(val?.contains('@') ?? false) ? "Enter a valid email" : null),
          const SizedBox(height: 16),
          _buildPasswordField(),
          const SizedBox(height: 16),
          _buildDateField(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _signUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 244, 164, 53),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Continue', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('OR')), Expanded(child: Divider())]),
          const SizedBox(height: 16),
          SocialAuthButton(
            text: 'Continue with Google',
            backgroundColor: const Color(0xFFF2F2F2),
            textColor: Colors.black87,
            icon: Icons.g_mobiledata_rounded,
            onPressed: _isLoading ? () {} : _signUpWithGoogle,
          ),
          const SizedBox(height: 16),
          _buildTermsText(),
        ],
      ),
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, required String hint, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.grey)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blue, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          validator: (value) => (value == null || value.length < 8) ? 'Password must be at least 8 characters' : null,
          decoration: InputDecoration(
            hintText: "Create a password",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.grey)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blue, width: 2)),
            suffixIcon: IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text("Use 8 or more letters, numbers and symbols", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Birthdate", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _birthdateController,
          readOnly: true,
          onTap: () => _selectDate(context),
          decoration: InputDecoration(
            hintText: "dd-mm-yyyy",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.grey)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blue, width: 2)),
            suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsText() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(color: Colors.grey, fontSize: 12),
          children: [
            const TextSpan(text: "By continuing, you agree to AKD's "),
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