import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:provider/provider.dart';

class AccountManagementDialog extends StatefulWidget {
  const AccountManagementDialog({super.key});

  @override
  State<AccountManagementDialog> createState() =>
      _AccountManagementDialogState();
}

class _AccountManagementDialogState extends State<AccountManagementDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Account Management'),
      content: SizedBox(
        width: 400, // Constrain width for dialog
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Change Email'),
                Tab(text: 'Change Password'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              // Give the TabBarView a constrained height
              height: 200, 
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ChangeEmailForm(),
                  _ChangePasswordForm(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ChangeEmailForm extends StatefulWidget {
  @override
  _ChangeEmailFormState createState() => _ChangeEmailFormState();
}

class _ChangeEmailFormState extends State<_ChangeEmailForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await SupabaseAuthService().updateUserEmail(_emailController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Confirmation email sent! Please check your old and new email addresses.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Close the dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update email: $e'),
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
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'New Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || !value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Send Confirmation Email'),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordForm extends StatefulWidget {
  @override
  _ChangePasswordFormState createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final success = await SupabaseAuthService()
          .updateUserPassword(_newPasswordController.text);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Password updated successfully! Please log in again.'),
            backgroundColor: Colors.green,
          ),
        );
        // The service already signs the user out, so we just pop the dialog.
        Navigator.of(context).pop(); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update password: $e'),
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
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextFormField(
            controller: _newPasswordController,
            decoration: const InputDecoration(labelText: 'New Password'),
            obscureText: true,
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            decoration: const InputDecoration(labelText: 'Confirm New Password'),
            obscureText: true,
            validator: (value) {
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Change Password'),
          ),
        ],
      ),
    );
  }
}