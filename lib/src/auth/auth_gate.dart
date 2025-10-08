import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/admin_shell.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/designer/designer_shell.dart';
import 'package:jewelry_nafisa/src/designer/screens/pending_approval_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/main_shell.dart';
import 'package:jewelry_nafisa/src/ui/screens/welcome/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.session == null) {
          context.read<UserProfileProvider>().reset();
          return const WelcomeScreen();
        }

        return Consumer<UserProfileProvider>(
          builder: (context, profileProvider, child) {
            if (!profileProvider.isProfileLoaded &&
                !profileProvider.isLoading) {
              profileProvider.fetchProfile();
            }
            if (!profileProvider.isProfileLoaded || profileProvider.isLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final userProfile = profileProvider.userProfile;

            if (userProfile == null) {
              return const LoginScreen();
            }

            final userRole = userProfile['role'];
            final approvalStatus = userProfile['approval_status'];

            if (userRole == 'admin') {
              return const AdminShell();
            }

            if (userRole == 'designer') {
              if (approvalStatus == 'approved') {
                return const DesignerShell();
              } else {
                return const PendingApprovalScreen();
              }
            }
            return const MainShell();
          },
        );
      },
    );
  }
}
