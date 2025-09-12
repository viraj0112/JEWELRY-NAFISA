import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/admin_shell.dart';
import 'package:jewelry_nafisa/src/auth/reset_password_screen.dart';
import 'package:jewelry_nafisa/src/designer/designer_shell.dart';
import 'package:jewelry_nafisa/src/designer/screens/pending_approval_screen.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/main_shell.dart';
import 'package:jewelry_nafisa/src/ui/screens/welcome/welcome_screen.dart';
import 'package:jewelry_nafisa/src/utils/user_profile_utils.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {

        if (snapshot.hasData &&
            snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
              (route) => false,
            );
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || snapshot.data?.session == null) {
          return const WelcomeScreen();
        }

        final userId = snapshot.data!.session!.user.id;
        return FutureBuilder<UserProfileProvider>(
          future: _fetchProfileAndGetProvider(context, userId),
          builder: (context, providerSnapshot) {
            if (providerSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            if (providerSnapshot.hasError || !providerSnapshot.hasData) {
              return const WelcomeScreen();
            }

            final userProfile = providerSnapshot.data!;

            switch (userProfile.role) {
              case 'admin':
                return const AdminShell();
              case 'designer':
                return userProfile.isApproved
                    ? const DesignerShell()
                    : const PendingApprovalScreen();
              default: 
                return const MainShell();
            }
          },
        );
      },
    );
  }
  Future<UserProfileProvider> _fetchProfileAndGetProvider(
    BuildContext context,
    String userId,
  ) async {
    final provider = Provider.of<UserProfileProvider>(context, listen: false);
    await UserProfileUtils.ensureUserProfile(userId);
    await provider.fetchProfile();
    return provider;
  }
}