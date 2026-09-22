import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/auth/password_service.dart';
import 'package:jewelry_nafisa/src/auth/widgets/password_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
                Tab(text: 'Reset Password'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              // Give the TabBarView a constrained height (the password tab
              // scrolls inside it).
              height: 400,
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

/// Password tab: the shared form (same strength rules as sign-up, and it
/// handles Supabase's verification-code step). The user stays signed in.
class _ChangePasswordForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: PasswordForm(
        submitLabel: PasswordService.hasPassword(
                Supabase.instance.client.auth.currentUser)
            ? 'Update password'
            : 'Set password',
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password saved'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
