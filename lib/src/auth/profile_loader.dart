import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/admin2/screens/main_screen.dart';
import 'package:jewelry_nafisa/src/designer/designer_shell.dart';
import 'package:jewelry_nafisa/src/designer/screens/pending_approval_screen.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_2_gender.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_3_age.dart'; 
import 'package:provider/provider.dart';

// Import the new onboarding screens
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_1_location.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_2_occasions.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_3_categories.dart';

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
    // Start loading the profile immediately
    _loadProfileFuture =
        Provider.of<UserProfileProvider>(context, listen: false)
            .loadUserProfile();
  }

  // --- NEW LOGIC: Determine the destination based on profile data ---
  // Instead of returning a widget, we return a Widget that performs a redirect
  Widget _getDestinationWidget(UserProfile userProfile) {
    // 1. Check Onboarding Status (Priority 1)
    if (userProfile.isSetupComplete == false) {
      return switch (userProfile.onboardingStage) {
        0 => const OnboardingScreen1Location(),
        1 => const OnboardingScreen2Gender(),
        2 => const OnboardingScreen3Age(),
        3 => const OnboardingScreen2Occasions(),
        4 => const OnboardingScreen3Categories(),
        // If stage is 3 but isSetupComplete is false, default to the last stage
        // or a safe home screen to prevent being stuck.
        _ => const RedirectToHome(),
      };
    }

    // 2. Role-Based Routing (Priority 2 - Only if onboarding is complete)
    return switch (userProfile.role) {
      UserRole.admin => const MainScreen(),
      UserRole.designer => userProfile.isApproved == true
          ? const DesignerShell()
          : const PendingApprovalScreen(),
      UserRole.member => const RedirectToHome(),
      // Default to MainShell for any other role/null role
      _ => const RedirectToHome(),
    };
  }
  // --- END NEW LOGIC ---

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadProfileFuture,
      builder: (context, snapshot) {
        // --- 1. Loading State ---
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // --- 2. Error State during Profile Fetch ---
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

        // --- 3. Success State: Profile Data Available (or not) ---
        return Consumer<UserProfileProvider>(
          builder: (context, profileProvider, child) {
            final UserProfile? userProfile = profileProvider.userProfile;

            // --- 4. Null Profile State (User exists but profile table is empty) ---
            if (userProfile == null) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                          'Could not find user profile. Please sign out and try again.'),
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

            // --- 5. Determine Final Destination ---
            return _getDestinationWidget(userProfile);
          },
        );
      },
    );
  }
}

// Helper widget to perform the redirect to /home
class RedirectToHome extends StatefulWidget {
  const RedirectToHome({super.key});

  @override
  State<RedirectToHome> createState() => _RedirectToHomeState();
}

class _RedirectToHomeState extends State<RedirectToHome> {
  @override
  void initState() {
    super.initState();
    // Schedule the navigation after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while redirecting
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}