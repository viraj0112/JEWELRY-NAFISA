import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes to redirect the user
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      _redirect(session);
    });

    // Also check the initial session when the widget first builds
    final initialSession = Supabase.instance.client.auth.currentSession;
    if (initialSession == null) {
      // If there's no session at all, go to welcome immediately.
      context.go('/welcome');
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _redirect(Session? session) async {
    // Wait for the frame to build before navigating
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    if (session == null) {
      // If the user logs out, go to the welcome screen.
      context.go('/welcome');
      return;
    }

    // When a session is active, fetch the user's profile.
    final userProfileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);

    // Use a try-catch to handle cases where the profile might not exist yet
    try {
      // A one-time fetch to get the user's role
      final profile = await Supabase.instance.client
          .from('users')
          .select('role, approval_status')
          .eq('id', session.user.id)
          .single();

      final userRole = profile['role'] as String?;
      final approvalStatus = profile['approval_status'] as String?;

      // Perform redirection based on the role and status
      if (userRole == 'designer') {
        // If the user is a designer and approved, go to /b2b
        if (approvalStatus == 'approved') {
          context.go('/b2b');
        } else {
          // If pending, you could have a dedicated pending screen
          // For now, we'll keep them on a safe route like home.
          // Or create a '/pending-approval' route.
          context.go('/home'); // Or a dedicated pending page
        }
      } else if (userRole == 'admin') {
        context.go('/admin'); // Redirect admin users
      } else {
        context.go('/home'); // Redirect all other users to home
      }
    } catch (e) {
      // If fetching the profile fails, redirect to a safe default.
      debugPrint("AuthGate redirect error: $e");
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading screen while authentication is being checked.
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
