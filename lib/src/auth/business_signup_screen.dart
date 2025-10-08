import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessSignUpScreen extends StatefulWidget {
  const BusinessSignUpScreen({super.key});

  @override
  State<BusinessSignUpScreen> createState() => _BusinessSignUpScreenState();
}

class _BusinessSignUpScreenState extends State<BusinessSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _authService = SupabaseAuthService();
  String _businessType = '3D Designer';
  bool _isLoading = false;
  String _fullPhoneNumber = '';
  XFile? _workFile;
  XFile? _businessCardFile;

  @override
  void dispose() {
    _fullNameController.dispose();
    _businessNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _pickWorkFile() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _workFile = pickedFile;
      });
    }
  }

  Future<void> _pickBusinessCard() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _businessCardFile = pickedFile;
      });
    }
  }

  Future<void> _signUpBusiness() async {
    if (!_formKey.currentState!.validate()) return;
    if (_workFile == null || _businessCardFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both work file and business card.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    final user = await _authService.signUpBusiness(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      businessName: _businessNameController.text.trim(),
      businessType: _businessType,
      phone: _fullPhoneNumber,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (user != null) {
        // --- Start of File Upload Logic ---

        try {
          // 1. Upload Work File
          final workFileBytes = await _workFile!.readAsBytes();
          final workFileExt = _workFile!.path.split('.').last;
          final workFileName = '${user.id}/work_file.$workFileExt';
          await Supabase.instance.client.storage
              .from('designer-files')
              .uploadBinary(
                workFileName,
                workFileBytes,
                fileOptions: FileOptions(upsert: true),
              );
          final workFileUrl = Supabase.instance.client.storage
              .from('designer-files')
              .getPublicUrl(workFileName);

          // 2. Upload Business Card
          final businessCardBytes = await _businessCardFile!.readAsBytes();
          final businessCardExt = _businessCardFile!.path.split('.').last;
          final businessCardName = '${user.id}/business_card.$businessCardExt';
          await Supabase.instance.client.storage
              .from('designer-files')
              .uploadBinary(
                businessCardName,
                businessCardBytes,
                fileOptions: FileOptions(upsert: true),
              );
          final businessCardUrl = Supabase.instance.client.storage
              .from('designer-files')
              .getPublicUrl(businessCardName);

          // 3. Insert File URLs into the database
          await Supabase.instance.client.from('designer_files').insert([
            {
              'user_id': user.id,
              'file_type': 'work_file',
              'file_url': workFileUrl,
            },
            {
              'user_id': user.id,
              'file_type': 'business_card',
              'file_url': businessCardUrl,
            }
          ]);

          // 4. Update the user's profile with address and GST
          await Supabase.instance.client.from('users').update({
            'address': _addressController.text.trim(),
            'gst_number': _gstController.text.trim(),
          }).eq('id', user.id);
        } catch (e) {
          if (kDebugMode) {
            print('Error uploading files: $e');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error uploading files. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          return; // Stop execution if there was an error
        }

        // --- End of File Upload Logic ---

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Enrollment Request Received"),
            content: const Text("We will get back to you soon!"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-up failed. This email may already be in use.'),
            backgroundColor: Colors.red,
          ),
        );
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
                    validator: (phoneNumber) {
                      if (phoneNumber == null || phoneNumber.number.isEmpty) {
                        return 'Please enter a phone number';
                      }
                      return null;
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
                    onPressed: _pickWorkFile,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_workFile == null
                        ? 'Upload Work File*'
                        : 'Work File Uploaded'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickBusinessCard,
                    icon: const Icon(Icons.contact_mail),
                    label: Text(_businessCardFile == null
                        ? 'Upload Business Card*'
                        : 'Business Card Uploaded'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signUpBusiness,
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
