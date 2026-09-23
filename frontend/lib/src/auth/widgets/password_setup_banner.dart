import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../password_service.dart';
import 'password_form.dart';

/// Optional nudge for accounts created with "Continue with Google" that have
/// no password for this site yet. Dismissing it is remembered per user on
/// this device; adding a password hides it for good.
class PasswordSetupBanner extends StatefulWidget {
  const PasswordSetupBanner({super.key});

  @override
  State<PasswordSetupBanner> createState() => _PasswordSetupBannerState();
}

class _PasswordSetupBannerState extends State<PasswordSetupBanner> {
  static const _green = Color(0xFF006435);

  bool _visible = false;

  User? get _user => Supabase.instance.client.auth.currentUser;

  String _dismissKey(String userId) => 'password_banner_dismissed_$userId';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _user;
    if (!PasswordService.needsPasswordSetup(user)) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || prefs.getBool(_dismissKey(user!.id)) == true) return;
    setState(() => _visible = true);
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    final user = _user;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissKey(user.id), true);
  }

  Future<void> _addPassword() async {
    final saved = await showChangePasswordDialog(context);
    if (saved && mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: _green.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 20, color: _green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add a local password to log in without Google anytime.',
                style: textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: _addPassword,
              style: TextButton.styleFrom(foregroundColor: _green),
              child: const Text('Add password'),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close, size: 18),
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}
