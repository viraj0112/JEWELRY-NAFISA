import 'dart:typed_data';
import 'dart:ui';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';

// ─────────────────────────────────────────────
//  Brand Colors
// ─────────────────────────────────────────────
const _kGold = Color(0xFFB8860B);
const _kDeepGreen = Color(0xFF1A3C2A);
const _kLightGold = Color(0xFFF5E6B0);
const _kAccentGreen = Color(0xFF2E7D52);

class BusinessSignUpScreen extends StatefulWidget {
  const BusinessSignUpScreen({super.key});

  @override
  State<BusinessSignUpScreen> createState() => _BusinessSignUpScreenState();
}

class _BusinessSignUpScreenState extends State<BusinessSignUpScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _authService = SupabaseAuthService();

  // ── State ─────────────────────────────────────
  int _currentStep = 0;
  String? _selectedBusinessType;
  final List<String> _businessTypes = [
    '3D Designer',
    'Sketch Artist',
    'Manufacturer',
    'Other'
  ];
  String _fullPhoneNumber = '';
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  XFile? _workFile;
  String _workFileName = '';
  XFile? _businessCardFile;
  String _businessCardFileName = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  // ── Step navigation ──────────────────────────
  void _goToStep(int step) {
    _animController.reverse().then((_) {
      setState(() => _currentStep = step);
      _animController.forward();
    });
  }

  bool _validateStep1() {
    if (_emailController.text.trim().isEmpty ||
        !_emailController.text.contains('@')) {
      _showSnack('Please enter a valid email address.');
      return false;
    }
    if (_passwordController.text.length < 6) {
      _showSnack('Password must be at least 6 characters.');
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnack('Passwords do not match.');
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_fullNameController.text.trim().isEmpty) {
      _showSnack('Please enter your business name.');
      return false;
    }
    if (_selectedBusinessType == null) {
      _showSnack('Please select a business type.');
      return false;
    }
    if (_fullPhoneNumber.isEmpty) {
      _showSnack('Please enter a phone number.');
      return false;
    }
    if (_addressController.text.trim().isEmpty) {
      _showSnack('Please enter your address.');
      return false;
    }
    return true;
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : _kAccentGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _pickFile(Function(XFile, String) onPicked,
      {bool isImage = false}) async {
    final picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => onPicked(pickedFile, pickedFile.name));
    }
  }

  Future<void> _enroll() async {
    if (_workFile == null || _businessCardFile == null) {
      _showSnack('Please upload both your work file and business card.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signUpBusiness(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        businessName: _fullNameController.text.trim(),
        businessType: _selectedBusinessType!,
        phone: _fullPhoneNumber,
        address: _addressController.text.trim(),
        gstNumber: _gstController.text.trim(),
      );
      if (user == null)
        throw Exception('Sign up failed. Email may already be in use.');

      final supabase = Supabase.instance.client;
      final userId = user.id;

      final workFileExt = _workFile!.name.split('.').last;
      final workFilePath = '$userId/work_file.$workFileExt';
      final Uint8List workBytes = await _workFile!.readAsBytes();
      await supabase.storage.from('designer-files').uploadBinary(
          workFilePath, workBytes,
          fileOptions: FileOptions(
              contentType: lookupMimeType(_workFile!.name), upsert: true));

      final cardFileExt = _businessCardFile!.name.split('.').last;
      final cardFilePath = '$userId/business_card.$cardFileExt';
      final Uint8List cardBytes = await _businessCardFile!.readAsBytes();
      await supabase.storage.from('designer-files').uploadBinary(
          cardFilePath, cardBytes,
          fileOptions: FileOptions(
              contentType: lookupMimeType(_businessCardFile!.name),
              upsert: true));

      final workFileUrl =
          supabase.storage.from('designer-files').getPublicUrl(workFilePath);
      final cardFileUrl =
          supabase.storage.from('designer-files').getPublicUrl(cardFilePath);

      await supabase.from('designer-files').insert([
        {'user_id': userId, 'file_type': 'work_file', 'file_url': workFileUrl},
        {
          'user_id': userId,
          'file_type': 'business_card',
          'file_url': cardFileUrl
        },
      ]);

      if (mounted) {
        _showSnack('Application submitted! We\'ll review and notify you.',
            isError: false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showSnack('An error occurred: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      body: Stack(
        children: [
          // ── Subtle background pattern ───────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _DiamondPatternPainter()),
          ),
          // ── Main layout ─────────────────────────────────────
          isWide ? _buildWideLayout() : _buildNarrowLayout(),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left: Hero panel
        Expanded(
          flex: 4,
          child: _buildHeroPanel(),
        ),
        // Right: Form
        Expanded(
          flex: 6,
          child: _buildFormPanel(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroBanner(),
          _buildFormPanel(),
        ],
      ),
    );
  }

  // ── Hero Panel (left side on desktop) ───────────────────────
  Widget _buildHeroPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kDeepGreen, Color(0xFF0D2218)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Overlay texture
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: Image.asset(
                'assets/icons/loginscreen.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/icons/dagina2.png', height: 80),
                const Spacer(),
                Text(
                  'Join the\nCreator\nNetwork',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 3,
                  width: 60,
                  decoration: BoxDecoration(
                    color: _kGold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Apply to list your jewelry designs, sketches, or manufacturing services on Dagina\'s curated platform.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 48),
                // Step tracker
                ..._buildSideStepTracker(),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSideStepTracker() {
    final steps = ['Account', 'Business', 'Documents'];
    return List.generate(steps.length, (i) {
      final isActive = i == _currentStep;
      final isDone = i < _currentStep;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? _kGold
                    : isActive
                        ? Colors.white
                        : Colors.white24,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: _kDeepGreen, size: 18)
                    : Text('${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive ? _kDeepGreen : Colors.white54,
                        )),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              steps[i],
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildHeroBanner() {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kDeepGreen, Color(0xFF0D2218)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Image.asset('assets/icons/dagina2.png', height: 60),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join the Creator Network',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Step ${_currentStep + 1} of 3',
                  style: GoogleFonts.inter(
                      color: _kGold, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ── Form Panel (right side) ──────────────────────────────────
  Widget _buildFormPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formKey,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top bar (mobile close only when narrow)
                  Row(
                    children: [
                      // Step indicator dots
                      ..._buildDotIndicators(),
                      const Spacer(),
                      if (MediaQuery.of(context).size.width > 900)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black45),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Step content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _buildCurrentStep(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDotIndicators() {
    return List.generate(3, (i) {
      final isActive = i == _currentStep;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 6),
        width: isActive ? 28 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: isActive ? _kGold : Colors.black12,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    });
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1(key: const ValueKey(0));
      case 1:
        return _buildStep2(key: const ValueKey(1));
      case 2:
        return _buildStep3(key: const ValueKey(2));
      default:
        return const SizedBox();
    }
  }

  // ── STEP 1: Account Details ──────────────────────────────────
  Widget _buildStep1({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepTitle(
            'Create your account', 'Set up your login credentials.'),
        const SizedBox(height: 28),
        _buildField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'you@business.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Minimum 6 characters',
          visible: _isPasswordVisible,
          onToggle: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          hint: 'Repeat your password',
          visible: _isConfirmPasswordVisible,
          onToggle: () => setState(
              () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: 'Continue',
          onTap: () {
            if (_validateStep1()) _goToStep(1);
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Already enrolled? Log in',
                style: GoogleFonts.inter(color: _kAccentGreen)),
          ),
        ),
      ],
    );
  }

  // ── STEP 2: Business Details ─────────────────────────────────
  Widget _buildStep2({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepTitle('Business information', 'Tell us about your work.'),
        const SizedBox(height: 28),
        _buildField(
          controller: _fullNameController,
          label: 'Business / Full Name',
          hint: 'e.g. Artisan Jewels Studio',
          icon: Icons.business_outlined,
        ),
        const SizedBox(height: 16),
        // Business type dropdown
        Container(
          decoration: _fieldDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBusinessType,
              hint: Row(children: [
                const Icon(Icons.category_outlined, color: _kGold, size: 20),
                const SizedBox(width: 12),
                Text('Business Type',
                    style: GoogleFonts.inter(color: Colors.black38)),
              ]),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: _kGold),
              items: _businessTypes
                  .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t,
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w500))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedBusinessType = v),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Phone field
        Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE0D5C5)),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          child: IntlPhoneField(
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              counterText: '',
            ),
            dropdownIconPosition: IconPosition.leading,
            pickerDialogStyle: PickerDialogStyle(
              width: MediaQuery.of(context).size.width * 0.4,
              searchFieldInputDecoration:
                  const InputDecoration(labelText: 'Search'),
            ),
            initialCountryCode: 'IN',
            onChanged: (phone) => _fullPhoneNumber = phone.completeNumber,
          ),
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _addressController,
          label: 'Address',
          hint: 'City, State, Country',
          icon: Icons.location_on_outlined,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _gstController,
          label: 'GST Number (Optional)',
          hint: 'e.g. 22AAAAA0000A1Z5',
          icon: Icons.receipt_long_outlined,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                label: 'Back',
                onTap: () => _goToStep(0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildPrimaryButton(
                label: 'Continue',
                onTap: () {
                  if (_validateStep2()) _goToStep(2);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── STEP 3: Documents ────────────────────────────────────────
  Widget _buildStep3({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepTitle(
            'Upload documents', 'Submit samples of your work for review.'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kLightGold.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kGold.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: _kGold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your documents will be reviewed by our team within 2–3 business days.',
                  style: GoogleFonts.inter(fontSize: 12, color: _kDeepGreen),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildUploadCard(
          label: 'Portfolio / Work File',
          subtitle: 'Images, PDF, or document of your work',
          icon: Icons.drive_folder_upload_outlined,
          fileName: _workFileName,
          isSelected: _workFile != null,
          onTap: () => _pickFile((file, name) {
            _workFile = file;
            _workFileName = name;
          }),
        ),
        const SizedBox(height: 16),
        _buildUploadCard(
          label: 'Business Card',
          subtitle: 'Clear photo of your business card',
          icon: Icons.contact_mail_outlined,
          fileName: _businessCardFileName,
          isSelected: _businessCardFile != null,
          onTap: () => _pickFile((file, name) {
            _businessCardFile = file;
            _businessCardFileName = name;
          }, isImage: true),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                  label: 'Back', onTap: () => _goToStep(1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildPrimaryButton(
                label: _isLoading ? '' : 'Submit Application',
                onTap: _isLoading ? null : _enroll,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'By submitting you agree to our Creators Terms & Privacy Policy.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.black38),
          ),
        ),
      ],
    );
  }

  // ── Shared UI helpers ────────────────────────────────────────

  Widget _buildStepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.playfairDisplay(
                fontSize: 28, fontWeight: FontWeight.bold, color: _kDeepGreen)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.black45)),
      ],
    );
  }

  BoxDecoration _fieldDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE0D5C5)),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: _fieldDecoration(),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style:
            GoogleFonts.inter(fontWeight: FontWeight.w500, color: _kDeepGreen),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _kGold, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          labelStyle: GoogleFonts.inter(color: Colors.black45, fontSize: 13),
          hintStyle: GoogleFonts.inter(color: Colors.black26, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: _fieldDecoration(),
      child: TextFormField(
        controller: controller,
        obscureText: !visible,
        style:
            GoogleFonts.inter(fontWeight: FontWeight.w500, color: _kDeepGreen),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: const Icon(Icons.lock_outline, color: _kGold, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              visible ? Icons.visibility : Icons.visibility_off,
              color: Colors.black38,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          labelStyle: GoogleFonts.inter(color: Colors.black45, fontSize: 13),
          hintStyle: GoogleFonts.inter(color: Colors.black26, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String label,
    required String subtitle,
    required IconData icon,
    required String fileName,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? _kDeepGreen.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _kGold : const Color(0xFFE0D5C5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? _kGold.withOpacity(0.15)
                    : const Color(0xFFF5F0E8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: isSelected
                    ? const Icon(Icons.check_circle, color: _kGold, size: 28)
                    : Icon(icon, color: Colors.black38, size: 26),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: _kDeepGreen,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(
                    isSelected ? fileName : subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isSelected ? _kGold : Colors.black38),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.edit_outlined : Icons.add_circle_outline,
              color: isSelected ? _kGold : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kGold, Color(0xFF8B6508)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _kGold.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0D5C5)),
        ),
        child: Center(
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kDeepGreen)),
        ),
      ),
    );
  }
}

// ── Background pattern painter ────────────────────────────────
class _DiamondPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8860B).withOpacity(0.045)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 48.0;
    const half = spacing / 2;

    for (double y = 0; y < size.height + spacing; y += spacing) {
      for (double x = 0; x < size.width + spacing; x += spacing) {
        final path = Path()
          ..moveTo(x, y - half)
          ..lineTo(x + half, y)
          ..lineTo(x, y + half)
          ..lineTo(x - half, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
