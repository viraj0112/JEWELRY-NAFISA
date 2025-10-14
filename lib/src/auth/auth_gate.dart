
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jewelry_nafisa/src/admin/admin_shell.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/designer/designer_shell.dart';
import 'package:jewelry_nafisa/src/designer/screens/pending_approval_screen.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/main_shell.dart';
import 'package:jewelry_nafisa/src/ui/screens/welcome/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {

        if (!snapshot.hasData || snapshot.data?.session == null) {
          return const WelcomeScreen();
        }

        return Consumer<UserProfileProvider>(
          builder: (context, profileProvider, child) {
            if (profileProvider.userProfile == null && !profileProvider.isLoading) {
              profileProvider.fetchProfile();
            }
            if (profileProvider.isLoading || !profileProvider.isProfileLoaded) {
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
            
            final currentLocation = GoRouterState.of(context).uri.toString();
            // --- END OF FIX ---

            if (userRole == 'admin') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (currentLocation != '/admin') {
                  context.go('/admin');
                }
              });
              return const AdminShell();
            }

            if (userRole == 'designer') {
              if (approvalStatus == 'approved') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (currentLocation != '/b2b') {
                    context.go('/b2b');
                  }
                });
                return const DesignerShell();
              } else {
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (currentLocation != '/pending-approval') {
                    context.go('/pending-approval');
                  }
                });
                return const PendingApprovalScreen();
              }
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (currentLocation != '/home') {
                context.go('/home');
              }
            });
            return const MainShell();
          },
        );
      },
    );
  }
}