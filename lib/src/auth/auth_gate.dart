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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || snapshot.data?.session == null) {
          context.read<UserProfileProvider>().reset();
          return const WelcomeScreen();
        }

        return FutureBuilder(
          future: Provider.of<UserProfileProvider>(context, listen: false)
              .fetchProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            final userProfile =
                Provider.of<UserProfileProvider>(context, listen: false)
                    .userProfile;

            if (userProfile == null) {
              // Instead of signing out, show a loading indicator while the profile is created.
              // This is a common scenario for new users.
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Setting up your account...'),
                    ],
                  ),
                ),
              );
            }

            final userRole = userProfile['role'];
            final approvalStatus = userProfile['approval_status'];

            if (userRole == 'admin') {
              return const AdminShell();
            }

            if (userRole == 'designer') {
              return approvalStatus == 'approved'
                  ? const DesignerShell()
                  : const PendingApprovalScreen();
            }
            return const MainShell();
          },
        );
      },
    );
  }
}
