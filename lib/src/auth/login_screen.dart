import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/auth/firebase_auth_service.dart';
import 'package:jewelry_nafisa/src/ui/widgets/social_auth_button.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = FirebaseAuthService();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final user = await _authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      setState(() => _isLoading = false);

      if (user == null) {
        _showErrorSnackbar('Login failed. Please check your credentials.');
      } else {
        // TODO: Navigate to Home Screen on successful login
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final user = await _authService.signInWithGoogle();
    setState(() => _isLoading = false);

    if (user == null) {
      _showErrorSnackbar('Google sign-in was cancelled or failed.');
    } else {
      // TODO: Navigate to Home Screen on successful login
    }
  }

  @override
  Widget build(BuildContext context) {
    // The rest of your build method remains the same...
    // The changes are in the onPressed callbacks of the buttons.
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            return _buildWideLayout();
          } else {
            return _buildNarrowLayout();
          }
        },
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        _buildImageSide(),
        _buildFormSide(),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 200, child: _buildImageSide(isNarrow: true)),
          _buildFormSide(),
        ],
      ),
    );
  }

  Widget _buildImageSide({bool isNarrow = false}) {
    return Expanded(
      flex: isNarrow ? 0 : 2,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage('#'), // Example image
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Text(
            'Login to Explore Designs by AKD',
            textAlign: TextAlign.center,
            style: GoogleFonts.ptSerifCaption(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade600,
              shadows: const [
                Shadow(blurRadius: 12.0, color: Color.fromARGB(137, 39, 33, 33), offset: Offset(2.0, 2.0)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormSide() {
    return Expanded(
      flex: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
        color: Colors.white,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to AKD',
                style: GoogleFonts.ptSerifCaption(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade600,
                  shadows: const [
                    Shadow(blurRadius: 12.0, color: Color.fromARGB(137, 39, 33, 33), offset: Offset(2.0, 2.0)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (value) => (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
                validator: (value) => (value == null || value.length < 6) ? 'Password must be at least 6 characters' : null,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () {}, child: const Text('Forgot your password?')),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Log In',
                        style: GoogleFonts.gideonRoman(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('OR')),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              SocialAuthButton(
                text: 'Continue with Google',
                backgroundColor: Colors.white,
                textColor: Colors.black,
                icon: Icons.g_mobiledata_rounded,
                onPressed: _isLoading ? () {} : _signInWithGoogle,
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
                child: const Text("Not on the app yet? Sign up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}