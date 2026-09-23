import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../B2BScreens/b2b_theme.dart';
import 'password_service.dart';
import 'supabase_auth_service.dart';
import 'widgets/password_form.dart';

/// New-password screen:
///  - required when the user opened a "reset password" email link (the
///    router sends them here; the only way out is signing out), or
///  - optional for accounts created with "Continue with Google" that have no
///    password for this site yet ("Maybe later" returns home).
class SetPasswordScreen extends StatelessWidget {
  const SetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recovery = PasswordService.recoveryPending;
    final email = Supabase.instance.client.auth.currentUser?.email;

    return Theme(
      data: B2BTheme.build(Theme.of(context)),
      child: Scaffold(
        backgroundColor: B2BColors.canvas,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
                  decoration: b2bCardDecoration(radius: B2BRadius.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            color: B2BColors.goldSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            recovery
                                ? Icons.lock_reset_rounded
                                : Icons.shield_outlined,
                            color: B2BColors.gold,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        recovery ? 'RESET PASSWORD' : 'OPTIONAL',
                        textAlign: TextAlign.center,
                        style: B2BText.eyebrow(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recovery
                            ? 'Choose a new password'
                            : 'Create your password',
                        textAlign: TextAlign.center,
                        style: B2BText.serif(size: 26),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        recovery
                            ? 'Enter a new password for ${email ?? 'your account'}.'
                            : 'You signed in with Google. Add a password for '
                                'Dagina.Design so you can also sign in with '
                                '${email ?? 'your email'} and a password.',
                        textAlign: TextAlign.center,
                        style: B2BText.sans(
                            size: 13.5, color: B2BColors.muted, height: 1.5),
                      ),
                      const SizedBox(height: 26),
                      PasswordForm(
                        submitLabel:
                            recovery ? 'Update password' : 'Create password',
                        onSuccess: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password saved')),
                          );
                          context.go('/');
                        },
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            if (!recovery) {
                              context.go('/home');
                              return;
                            }
                            PasswordService.recoveryPending = false;
                            await SupabaseAuthService().signOut();
                          },
                          child: Text(
                            recovery ? 'Sign out' : 'Maybe later',
                            style: B2BText.sans(
                                size: 13, color: B2BColors.muted,
                                weight: FontWeight.w500),
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
    );
  }
}
