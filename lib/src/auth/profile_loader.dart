import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/admin_shell.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/designer/designer_shell.dart';
import 'package:jewelry_nafisa/src/designer/screens/pending_approval_screen.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/main_shell.dart';
import 'package:provider/provider.dart';

class ProfileLoader extends StatefulWidget {
  const ProfileLoader({super.key});

  @override
  State<ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<ProfileLoader> {
  late Future<void> _loadProfileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfileFuture =
        Provider.of<UserProfileProvider>(context, listen: false)
            .loadUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadProfileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error loading profile: ${snapshot.error}'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => SupabaseAuthService().signOut(),
                    child: const Text('Sign Out'),
                  )
                ],
              ),
            ),
          );
        }

        return Consumer<UserProfileProvider>(
          builder: (context, profileProvider, child) {
            final UserProfile? userProfile = profileProvider.userProfile;

            if (userProfile == null) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Could not find user profile. Please sign out.'),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => SupabaseAuthService().signOut(),
                        child: const Text('Sign Out'),
                      )
                    ],
                  ),
                ),
              );
            }

            switch (userProfile.role) {
              case 'admin':
                return const AdminShell();
              case 'designer':
                if (userProfile.isApproved == true) {
                  return const DesignerShell();
                } else {
                  return const PendingApprovalScreen();
                }
              case 'member':
              default:
                return const MainShell();
            }
          },
        );
      },
    );
  }
}