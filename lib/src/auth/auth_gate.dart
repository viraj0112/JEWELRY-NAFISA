import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/reset_password_screen.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/main_shell.dart';
import 'package:jewelry_nafisa/src/ui/screens/welcome/welcome_screen.dart';
import 'package:jewelry_nafisa/src/utils/user_profile_utils.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _recoverSessionAndRedirect();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final event = data.event;

      // ✨ ADDED: Listen for the password recovery event
      if (event == AuthChangeEvent.passwordRecovery) {
        if (mounted) {
          // Navigate to the screen where the user can enter a new password.
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
            (route) => false,
          );
        }
        return;
      }
      
      if (session == null) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
        }
      } else {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          _ensureAndFetchProfile(context, session.user.id).then((_) {
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainShell()),
              (route) => false,
            );
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _recoverSessionAndRedirect() async {
    // This prevents a brief flash of the loading screen on hot restart.
    await Future.delayed(const Duration(milliseconds: 100));

    final session = Supabase.instance.client.auth.currentSession;
    if (!mounted) return;

    if (session != null) {
      await _ensureAndFetchProfile(context, session.user.id);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  Future<void> _ensureAndFetchProfile(
    BuildContext context,
    String userId,
  ) async {
    final provider = Provider.of<UserProfileProvider>(context, listen: false);
    await UserProfileUtils.ensureUserProfile(userId);
    if (mounted) {
      await provider.fetchProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}