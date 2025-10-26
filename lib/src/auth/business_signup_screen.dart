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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Designer'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- All the form fields ---
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                        labelText: 'Full Name / Business Name'),
                    validator: (value) =>
                        value!.trim().isEmpty ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration:
                        const InputDecoration(labelText: 'Email Address'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        (value!.isEmpty || !value.contains('@'))
                            ? 'Please enter a valid email'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  IntlPhoneField(
                    decoration:
                        const InputDecoration(labelText: 'Phone Number'),
                    initialCountryCode: 'IN', // Default to India
                    onChanged: (phone) {
                      _fullPhoneNumber = phone.completeNumber;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedBusinessType,
                    hint: const Text('Select Business Type'),
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
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    validator: (value) => value!.trim().isEmpty
                        ? 'Please enter your address'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _gstController,
                    decoration: const InputDecoration(
                        labelText: 'GST Number (Optional)'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => value!.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration:
                        const InputDecoration(labelText: 'Confirm Password'),
                    obscureText: true,
                    validator: (value) => value != _passwordController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  // --- File Upload Buttons ---
                  OutlinedButton.icon(
                    onPressed: () => _pickFile((file, name) {
                      _workFile = file;
                      _workFileName = name;
                    }),
                    icon: const Icon(Icons.upload_file),
                    label: Text(_workFileName, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _pickFile((file, name) {
                      _businessCardFile = file;
                      _businessCardFileName = name;
                    }, isImage: true),
                    icon: const Icon(Icons.contact_mail),
                    label: Text(_businessCardFileName,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 24),
                  // The main action button
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : _enroll, // Disable button when loading
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Enroll'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
