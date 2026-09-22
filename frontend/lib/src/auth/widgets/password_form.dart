import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/validators.dart';
import '../password_service.dart';

/// New-password + confirm form shared by the set-password screen and the
/// change-password dialogs.
///
/// Applies the same strength rules as sign-up, and handles Supabase's
/// "secure password change": when a verification code is required it emails
/// one and shows a code field, then retries with it.
class PasswordForm extends StatefulWidget {
  const PasswordForm({
    super.key,
    required this.onSuccess,
    this.submitLabel = 'Save password',
    this.service,
  });

  final VoidCallback onSuccess;
  final String submitLabel;
  final PasswordService? service;

  @override
  State<PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<PasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  late final PasswordService _service = widget.service ?? PasswordService();

  bool _obscure = true;
  bool _saving = false;
  bool _needsCode = false;
  bool _sendingCode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _code.dispose();
    super.dispose();
  }

  String? get _email => Supabase.instance.client.auth.currentUser?.email;

  Future<void> _sendCode() async {
    setState(() => _sendingCode = true);
    try {
      await _service.sendVerificationCode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Verification code sent to ${_email ?? 'your email'}'),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _error = _readable(e));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.setPassword(_password.text,
          nonce: _needsCode ? _code.text : null);
      if (mounted) widget.onSuccess();
    } on VerificationRequired {
      // First attempt without a code: ask Supabase to email one.
      if (!_needsCode) {
        setState(() => _needsCode = true);
        await _sendCode();
      } else {
        setState(() => _error = 'Please enter the verification code.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = _readable(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _readable(Object e) => e is AuthException
      ? e.message
      : '$e'.replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final text = _password.text;
    final rules = <(String, bool)>[
      ('At least 8 characters', text.length >= 8),
      ('An uppercase letter', text.contains(RegExp(r'[A-Z]'))),
      ('A lowercase letter', text.contains(RegExp(r'[a-z]'))),
      ('A number', text.contains(RegExp(r'[0-9]'))),
    ];

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: Validators.validatePassword,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final (label, ok) in rules)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(ok ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size: 14,
                      color: ok ? theme.colorScheme.primary : muted),
                  const SizedBox(width: 4),
                  Text(label,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: ok ? theme.colorScheme.primary : muted)),
                ]),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirm,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: Icon(Icons.lock_reset_rounded, size: 20),
            ),
            validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null,
            onFieldSubmitted: (_) => _saving ? null : _submit(),
          ),
          if (_needsCode) ...[
            const SizedBox(height: 18),
            Text(
              'For your security, enter the verification code we emailed to '
              '${_email ?? 'you'}.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: InputDecoration(
                labelText: 'Verification code',
                prefixIcon: const Icon(Icons.mark_email_read_outlined, size: 20),
                suffixIcon: TextButton(
                  onPressed: _sendingCode ? null : _sendCode,
                  child: Text(_sendingCode ? 'Sending…' : 'Resend'),
                ),
              ),
              validator: (v) => _needsCode && (v ?? '').trim().isEmpty
                  ? 'Enter the code from your email'
                  : null,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 22),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(widget.submitLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the change/set-password dialog from settings. Returns true when the
/// password was saved.
Future<bool> showChangePasswordDialog(BuildContext context) async {
  final user = Supabase.instance.client.auth.currentUser;
  final hasPassword = PasswordService.hasPassword(user);
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(hasPassword ? 'Reset password' : 'Set a password'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasPassword
                    ? 'Choose a new password for ${user?.email ?? 'your account'}. '
                        'You will stay signed in.'
                    : 'Add a password so you can also sign in with '
                        '${user?.email ?? 'your email'} and a password.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              PasswordForm(
                submitLabel: hasPassword ? 'Update password' : 'Set password',
                onSuccess: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel')),
      ],
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password saved')),
    );
  }
  return saved == true;
}
