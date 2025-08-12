import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/auth/firebase_auth_service.dart';
import 'package:jewelry_nafisa/src/ui/widgets/social_auth_button.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final user = await _authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }

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
    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (user == null) {
      _showErrorSnackbar('Google sign-in was cancelled or failed.');
    } else {
      // TODO: Navigate to Home Screen on successful login
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The LayoutBuilder is the key to creating a responsive UI.
      // It rebuilds the UI based on the parent widget's constraints.
      body: LayoutBuilder(
        builder: (context, constraints) {
          // I've increased the breakpoint to 700 for a better tablet experience.
          if (constraints.maxWidth > 700) {
            return _buildWideLayout();
          } else {
            return _buildNarrowLayout();
          }
        },
      ),
    );
  }

  /// Layout for wide screens (web, tablets in landscape).
  Widget _buildWideLayout() {
    return Row(
      children: [
        // The image takes up 2/3 of the screen width.
        Expanded(flex: 2, child: _buildImageSide()),
        // The form takes up 1/3 of the screen width.
        Expanded(
          flex: 1,
          child: Container(
            alignment: Alignment.center,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 8,
                margin: const EdgeInsets.all(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                // By wrapping the form in a SingleChildScrollView, we prevent
                // overflow errors if the window height is too small.
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: _buildFormContents(isWide: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Layout for narrow screens (mobile phones).
  Widget _buildNarrowLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildMobileImageHeader(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildFormContents(isWide: false),
            ),
          ],
        ),
      ),
    );
  }

  /// The image collage header for the mobile view, based on your screenshot.
  Widget _buildMobileImageHeader() {
    // Helper widget to build each image card in the collage.
    Widget buildImageCard(String url) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: buildImageCard(
                    'https://assets.ajio.com/medias/sys_master/root/20240109/OcoR/659c80a474cb305fe00d378d/-473Wx593H-466964197-gold-MODEL5.jpg',
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: buildImageCard(
                    'https://m.media-amazon.com/images/I/510E9vSWUPL._UY1100_.jpg',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: buildImageCard(
              'https://assets.myntassets.com/w_412,q_30,dpr_3,fl_progressive,f_webp/assets/images/25188418/2023/9/27/4937a351-fd69-40c7-a4e8-d92c7328b8611695797787876JewelsGalaxyWomenGold-TonedWhiteAmericanDiamondGold-PlatedBa1.jpg',
            ),
          ),
        ],
      ),
    );
  }

  /// The image side for the wide layout.
  Widget _buildImageSide() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(
            'https://static.vecteezy.com/system/resources/previews/035/081/140/non_2x/women-s-jewelry-gold-chain-trendy-jewelry-on-a-silk-background-photo.JPG',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log In to Explore',
              style: GoogleFonts.ptSerif(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    blurRadius: 15.0,
                    color: Colors.black54,
                    offset: Offset(2.0, 2.0),
                  ),
                ],
              ),
            ),
            Text(
              'Designs by AKD',
              style: GoogleFonts.ptSerif(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    blurRadius: 12.0,
                    color: Colors.black54,
                    offset: Offset(2.0, 2.0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The core, reusable form widget.
  /// This contains all the fields and buttons. It's used by both layouts.
  Widget _buildFormContents({required bool isWide}) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title Section
          if (!isWide) ...[
            Text(
              'AKD',
              textAlign: TextAlign.center,
              style: GoogleFonts.ptSerif(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.brown[700],
              ),
            ),
            Text(
              'Celebrate with Daginawalas',
              textAlign: TextAlign.center,
              style: GoogleFonts.ptSerif(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            isWide ? 'Welcome to AKD' : 'Welcome Back',
            textAlign: isWide ? TextAlign.start : TextAlign.center,
            style: GoogleFonts.ptSerif(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 32),

          // Email Field
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) => (value == null || !value.contains('@'))
                ? 'Enter a valid email'
                : null,
          ),
          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
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
              onPressed: () {},
              child: const Text('Forgot your password?'),
            ),
          ),
          const SizedBox(height: 10),

          // Login Button
          ElevatedButton(
            onPressed: _isLoading ? null : _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: isWide ? Colors.orangeAccent : Colors.brown[400],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isWide ? 25 : 12),
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
                : Text(
                    isWide ? 'Log In' : 'Continue',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
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

          // Social Auth Button
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
