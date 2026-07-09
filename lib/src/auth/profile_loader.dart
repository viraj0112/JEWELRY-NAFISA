import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/admin2/screens/main_screen.dart';
import 'package:jewelry_nafisa/src/designer/screens/pending_approval_screen.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
// Onboarding is handled via GoRouter routes in HomeScreen timer.
// Screens are registered in main.dart routes.
// import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_1_location.dart';
// import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_2_gender.dart';
// import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_3_categories.dart';
// import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_3_age.dart';
// import 'package:jewelry_nafisa/src/ui/screens/onboarding/onboarding_screen_2_occasions.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/B2BScreens/b2b_shell.dart';

class ProfileLoader extends StatefulWidget {
  const ProfileLoader({super.key});

  @override
  State<ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<ProfileLoader> {
  bool _isLoading = true;
  String? _error;

  Timer? _onboardingTimer;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _onboardingTimer?.cancel();
    super.dispose();
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

        // If onboarding is not complete, start the 45-second delay timer.
        // The user will see the home screen first; after 45s the onboarding
        // screens will be shown.
        final profile = provider.userProfile;
        if (profile != null &&
            profile.isSetupComplete == false &&
            profile.role != UserRole.admin &&
            profile.role != UserRole.designer &&
            profile.role != UserRole.manufacturer) {
          _startOnboardingDelay();
        }
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

  /// Starts a 45-second timer. When it fires, navigate directly to the
  /// correct onboarding screen using GoRouter.
  void _startOnboardingDelay() {
    _onboardingTimer = Timer(const Duration(seconds: 45), () {
      if (!mounted) return;
      final provider = Provider.of<UserProfileProvider>(context, listen: false);
      final profile = provider.userProfile;
      if (profile == null || profile.isSetupComplete == true) return;

      // Route to the correct onboarding screen based on current stage
      final stage = profile.onboardingStage;
      final String route;
      if (stage == 0) {
        route = '/onboarding/location';
      } else if (stage == 1) {
        route = '/onboarding/gender';
      } else {
        route = '/onboarding/categories';
      }
      GoRouter.of(context).go(route);
    });
  }

  Widget _getDestinationWidget(UserProfile userProfile) {
    debugPrint('🎯 _getDestinationWidget called');
    debugPrint('🎯 userProfile.role: ${userProfile.role}');
    debugPrint(
        '🎯 userProfile.isSetupComplete: ${userProfile.isSetupComplete}');
    debugPrint(
        '🎯 userProfile.designerProfile: ${userProfile.designerProfile}');
    debugPrint(
        '🎯 userProfile.manufacturerProfile: ${userProfile.manufacturerProfile}');

    // 0. Skip onboarding for manufacturers & designers (Priority 0)
    if (userProfile.role == UserRole.manufacturer ||
        userProfile.role == UserRole.designer) {
      debugPrint(
          '🎯 Business account detected - skipping onboarding, checking approval');
      return userProfile.isApproved == true
          ? const B2BShell()
          : const PendingApprovalScreen();
    }

    // 1. Check Onboarding Status (Priority 1 - for regular members)
    // Always redirect to home first — the 45-second timer in HomeScreen
    // will navigate to the correct onboarding screen after the delay.
    if (userProfile.isSetupComplete == false) {
      debugPrint(
          '🎯 Onboarding not complete (stage ${userProfile.onboardingStage}) — redirecting to home, timer will handle onboarding');
      return const RedirectToHome();
    }

    // 2. Role-Based Routing (Priority 2 - Only if onboarding is complete)
    debugPrint('🎯 Using role-based routing');
    return switch (userProfile.role) {
      UserRole.admin => const MainScreen(),
      UserRole.designer => userProfile.isApproved == true
          ? const B2BShell()
          : const PendingApprovalScreen(),
      UserRole.manufacturer => userProfile.isApproved == true
          ? const B2BShell()
          : const PendingApprovalScreen(),
      UserRole.member => const RedirectToHome(),
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

        debugPrint(
            'ProfileLoader - userProfile is null: ${userProfile == null}');
        debugPrint('ProfileLoader - userProfile: $userProfile');

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

class _RedirectToManufacturer extends StatefulWidget {
  const _RedirectToManufacturer({super.key});

  @override
  State<_RedirectToManufacturer> createState() =>
      _RedirectToManufacturerState();
}

class _RedirectToManufacturerState extends State<_RedirectToManufacturer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('/manufacturer');
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

class _RedirectToDesigner extends StatefulWidget {
  const _RedirectToDesigner({super.key});

  @override
  State<_RedirectToDesigner> createState() => _RedirectToDesignerState();
}

class _RedirectToDesignerState extends State<_RedirectToDesigner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('/designer');
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
