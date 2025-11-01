import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessSignUpScreen extends StatefulWidget {
  const BusinessSignUpScreen({super.key});

  @override
  State<BusinessSignUpScreen> createState() => _BusinessSignUpScreenState();
}

class _BusinessSignUpScreenState extends State<BusinessSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _authService = SupabaseAuthService();

  String? _selectedBusinessType;
  final List<String> _businessTypes = [
    '3D Designer',
    'Sketch Artist',
    'Manufacturer',
    'Other'
  ];
  String _fullPhoneNumber = '';
  bool _isLoading = false;

  File? _workFile;
  String _workFileName = 'Upload Work File (PDF/Doc)';
  File? _businessCardFile;
  String _businessCardFileName = 'Upload Business Card (Image)';

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(Function(File, String) onFilePicked,
      {bool isImage = false}) async {
    final picker = ImagePicker();
    final XFile? pickedFile = isImage
        ? await picker.pickImage(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        onFilePicked(File(pickedFile.path), pickedFile.name);
      });
    }
  }

  Future<void> _enroll() async {
    // 1. Validate form and file uploads
    if (!_formKey.currentState!.validate()) return;
    if (_workFile == null || _businessCardFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both your work file and business card.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Create the user with all metadata
      final user = await _authService.signUpBusiness(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        businessName: _fullNameController.text.trim(),
        businessType: _selectedBusinessType!,
        phone: _fullPhoneNumber,
        address: _addressController.text.trim(),
        gstNumber: _gstController.text.trim(),
      );

      if (user == null || !mounted) {
        throw Exception('Sign up failed. The email may already be in use.');
      }

      final supabase = Supabase.instance.client;
      final userId = user.id;

      // 3. Upload files to Supabase Storage
      final workFileExt = _workFile!.path.split('.').last;
      final workFilePath = '$userId/work_file.$workFileExt';
      await supabase.storage.from('designer-files').uploadBinary(
            workFilePath,
            await _workFile!.readAsBytes(),
            fileOptions: FileOptions(
              contentType: lookupMimeType(_workFile!.path),
              upsert: true,
            ),
          );

      final cardFileExt = _businessCardFile!.path.split('.').last;
      final cardFilePath = '$userId/business_card.$cardFileExt';
      await supabase.storage.from('designer-files').uploadBinary(
            cardFilePath,
            await _businessCardFile!.readAsBytes(),
            fileOptions: FileOptions(
              contentType: lookupMimeType(_businessCardFile!.path),
              upsert: true,
            ),
          );

      // 4. Get public URLs
      final workFileUrl =
          supabase.storage.from('designer-files').getPublicUrl(workFilePath);
      final cardFileUrl =
          supabase.storage.from('designer-files').getPublicUrl(cardFilePath);

      // 5. Save file URLs to the database
      await supabase.from('designer-files').insert([
        {'user_id': userId, 'file_type': 'work_file', 'file_url': workFileUrl},
        {
          'user_id': userId,
          'file_type': 'business_card',
          'file_url': cardFileUrl
        },
      ]);

      // 6. Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Enrollment successful! Please check your email for verification.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper widget for elegant section headers
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  // Helper widget for a sophisticated file upload button
  Widget _buildFileUploadTile({
    required BuildContext context,
    required String title,
    required String fileName,
    required IconData icon,
    required bool isFileSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Check if the filename is still the default placeholder
    final bool isDefaultText = fileName == 'Upload Work File (PDF/Doc)' ||
        fileName == 'Upload Business Card (Image)';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFileSelected
                ? colorScheme.primary // Highlight if selected
                : theme.dividerColor,
          ),
          color: isFileSelected
              ? colorScheme.primary
                  .withOpacity(0.05) // Soft background if selected
              : theme.inputDecorationTheme.fillColor ?? theme.cardColor,
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: isFileSelected ? colorScheme.primary : Colors.grey[500],
          ),
          title: Text(
            isDefaultText ? title : fileName, // Show placeholder or real name
            style: TextStyle(
              color: isDefaultText ? Colors.grey[600] : colorScheme.onSurface,
              fontWeight: isDefaultText ? FontWeight.normal : FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isFileSelected
              ? const Icon(Icons.check_circle, color: Colors.green) // Success
              : const Icon(Icons.add, color: Colors.grey), // Prompt to add
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // Use standard InputDecorationTheme for all fields
    final inputDecorationTheme = theme.inputDecorationTheme.copyWith(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: theme.cardColor.withOpacity(0.5),
    );

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Become a Designer'),
          elevation: 0, // Cleaner look
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              // 1. Centers the form horizontally
              child: ConstrainedBox(
                // 2. Sets a maximum width
                constraints: const BoxConstraints(
                    maxWidth: 600), // A good width for forms
                child: Padding(
                  // 3. Your original padding
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Theme(
                      // Apply consistent decoration to all fields in form
                      data: theme.copyWith(
                        inputDecorationTheme: inputDecorationTheme,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- Header ---
                          Text(
                            'Create Your Business Profile',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "We're excited to have you join our creator community.",
                            style: textTheme.titleMedium
                                ?.copyWith(color: theme.hintColor),
                          ),
                          const SizedBox(height: 32),

                          // --- Section 1: Account Details ---
                          _buildSectionHeader(context, 'Account Details'),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) =>
                                (value!.isEmpty || !value.contains('@'))
                                    ? 'Please enter a valid email'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                            validator: (value) => value!.length < 6
                                ? 'Password must be at least 6 characters'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: Icon(Icons.lock_clock_outlined),
                            ),
                            obscureText: true,
                            validator: (value) =>
                                value != _passwordController.text
                                    ? 'Passwords do not match'
                                    : null,
                          ),
                          const SizedBox(height: 32),

                          // --- Section 2: Business Details ---
                          _buildSectionHeader(context, 'Business Details'),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _fullNameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name / Business Name',
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                            validator: (value) => value!.trim().isEmpty
                                ? 'Please enter your name'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedBusinessType,
                            hint: const Text('Select Business Type'),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: _businessTypes.map((String type) {
                              return DropdownMenuItem<String>(
                                  value: type, child: Text(type));
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedBusinessType = newValue;
                              });
                            },
                            validator: (value) =>
                                value == null ? 'This field is required' : null,
                          ),
                          const SizedBox(height: 16),
                          IntlPhoneField(
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                            ),
                            initialCountryCode: 'IN', // Default to India
                            onChanged: (phone) {
                              _fullPhoneNumber = phone.completeNumber;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Address',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            validator: (value) => value!.trim().isEmpty
                                ? 'Please enter your address'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _gstController,
                            decoration: const InputDecoration(
                              labelText: 'GST Number (Optional)',
                              prefixIcon: Icon(Icons.receipt_long_outlined),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // --- Section 3: Document Uploads ---
                          _buildSectionHeader(context, 'Required Documents'),
                          const SizedBox(height: 16),
                          _buildFileUploadTile(
                            context: context,
                            title: 'Work File (PDF/Doc)',
                            fileName: _workFileName,
                            icon: Icons.upload_file_outlined,
                            isFileSelected: _workFile != null,
                            onTap: () => _pickFile((file, name) {
                              _workFile = file;
                              _workFileName = name;
                            }),
                          ),
                          const SizedBox(height: 16),
                          _buildFileUploadTile(
                            context: context,
                            title: 'Business Card (Image)',
                            fileName: _businessCardFileName,
                            icon: Icons.contact_mail_outlined,
                            isFileSelected: _businessCardFile != null,
                            onTap: () => _pickFile((file, name) {
                              _businessCardFile = file;
                              _businessCardFileName = name;
                            }, isImage: true),
                          ),
                          const SizedBox(height: 32),

                          // --- The main action button ---
                          ElevatedButton(
                            onPressed: _isLoading ? null : _enroll,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text(
                                    'Enroll',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
