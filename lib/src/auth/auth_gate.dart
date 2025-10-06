import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/admin_shell.dart'; // Import the AdminShell
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/designer/designer_shell.dart';
import 'package:jewelry_nafisa/src/designer/screens/pending_approval_screen.dart';
import 'package:jewelry_nafisa/src/designer/designer_shell.dart';
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
        // If user is not logged in, show the Welcome screen
        if (!snapshot.hasData || snapshot.data?.session == null) {
          return const WelcomeScreen();
        }

        // If user is logged in, use the UserProfileProvider to determine their role
        return Consumer<UserProfileProvider>(
          builder: (context, profileProvider, child) {
            // If the profile is not loaded yet, and not currently loading, fetch it.
            if (profileProvider.userProfile == null &&
                !profileProvider.isLoading) {
              // fetchProfile will notify listeners and cause this widget to rebuild
              profileProvider.fetchProfile();
            }

            // Show a loading indicator while the profile is being fetched
            if (profileProvider.isLoading) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            final userProfile = profileProvider.userProfile;

            // If profile fetching fails or there's no profile, direct to login
            if (userProfile == null) {
              return const LoginScreen();
            }

            // === 🚀 ROLE-BASED ROUTING LOGIC ===
            final userRole = userProfile['role'];
            final approvalStatus = userProfile['approval_status'];

            // 1. Check for 'admin' role
            if (userRole == 'admin') {
              return const AdminShell();
            }

            // 2. Check for 'designer' role
            if (userRole == 'designer') {
              if (approvalStatus == 'approved') {
                // You can create and return a DesignerShell() here when ready
                return const DesignerShell();
              } else {
                return const PendingApprovalScreen();
              }
            }

            // 3. Default route for regular 'member' users
            return const MainShell();
          },
        );
      },
    );
  }
}
