import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    } else {
      // If a session exists, redirect based on that session.
      _redirect(initialSession);
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

    // Use a try-catch to handle cases where the profile might not exist yet
    try {
      // A one-time fetch to get the user's role
      // FIX: Changed .single() to .maybeSingle() to prevent errors on first login
      final profile = await Supabase.instance.client
          .from('users')
          .select('role, approval_status')
          .eq('id', session.user.id)
          .maybeSingle();

      // FIX: Handle the case where the profile isn't created yet by the database trigger
      if (profile == null) {
        // This can happen on first-time login due to a slight delay.
        // Redirect to a safe default page. The UserProfileProvider will fetch the
        // full profile once it's available.
        debugPrint(
            "AuthGate: Profile not found yet. Redirecting to /home to allow profile creation.");
        context.go('/home');
        return;
      }

      final userRole = profile['role'] as String?;
      final approvalStatus = profile['approval_status'] as String?;

      // Perform redirection based on the role and status
      if (userRole == 'designer') {
        if (approvalStatus == 'approved') {
          context.go('/b2b');
        } else {
          // Redirect pending or rejected designers to a dedicated screen
          context.go('/pending-approval');
        }
      } else if (userRole == 'admin') {
        context.go('/admin'); // Redirect admin users
      } else {
        context.go('/home'); // Redirect all other users to home
      }
    } catch (e) {
      // If any other error occurs, redirect to a safe default.
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