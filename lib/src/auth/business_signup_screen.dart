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
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _authService = SupabaseAuthService();

  String _businessType = '3D Designer';
  String _fullPhoneNumber = '';
  bool _isLoading = false;

  XFile? _workFile;
  String _workFileName = 'Upload Work File*';

  XFile? _businessCardFile;
  String _businessCardFileName = 'Upload Business Card*';

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(Function(XFile, String) onFilePicked) async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        onFilePicked(pickedFile, pickedFile.name);
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
        businessType: _businessType,
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
      appBar: AppBar(title: const Text("Create Business Account")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Join as a Designer",
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'Full Name*'),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter your full name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email*'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        (value!.isEmpty || !value.contains('@'))
                            ? 'Please enter a valid email'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  IntlPhoneField(
                    decoration: const InputDecoration(
                      labelText: 'Phone Number*',
                      border: OutlineInputBorder(),
                    ),
                    initialCountryCode: 'IN',
                    onChanged: (phone) {
                      _fullPhoneNumber = phone.completeNumber;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _businessType,
                    decoration:
                        const InputDecoration(labelText: 'Business Type*'),
                    items: ['3D Designer', 'Sketch Artist']
                        .map((type) =>
                            DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _businessType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Address*'),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter your address' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _gstController,
                    decoration:
                        const InputDecoration(labelText: 'GST (Optional)'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password*'),
                    validator: (value) => (value!.length < 8)
                        ? 'Password must be at least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 24),
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
                    }),
                    icon: const Icon(Icons.contact_mail),
                    label: Text(_businessCardFileName,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _enroll,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
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
