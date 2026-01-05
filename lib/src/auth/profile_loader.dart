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
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_1_location.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_2_occasions.dart';
import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_3_categories.dart';

class ProfileLoader extends StatefulWidget {
  const ProfileLoader({super.key});

  @override
  State<ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<ProfileLoader> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final provider = Provider.of<UserProfileProvider>(context, listen: false);
      

      
      // Always reload the profile to ensure fresh data
      await provider.loadUserProfile();
      

      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {

      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Widget _getDestinationWidget(UserProfile userProfile) {
    // 1. Check Onboarding Status (Priority 1)
    if (userProfile.isSetupComplete == false) {
      return switch (userProfile.onboardingStage) {
        0 => const OnboardingScreen1Location(),
        1 => const OnboardingScreen2Gender(),
        2 => const OnboardingScreen3Age(),
        3 => const OnboardingScreen2Occasions(),
        4 => const OnboardingScreen3Categories(),
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
      _ => const RedirectToHome(),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show error state
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading profile: $_error'),
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

    // Show profile-based navigation
    return Consumer<UserProfileProvider>(
      builder: (context, profileProvider, child) {
        final userProfile = profileProvider.userProfile;

        // Null profile state
        if (userProfile == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not find user profile.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const Text(
                    'Please sign out and try again.',
                    style: TextStyle(color: Colors.grey),
                  ),
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

        return _getDestinationWidget(userProfile);
      },
    );
  }
}

class RedirectToHome extends StatefulWidget {
  const RedirectToHome({super.key});

  @override
  State<RedirectToHome> createState() => _RedirectToHomeState();
}

class _RedirectToHomeState extends State<RedirectToHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}