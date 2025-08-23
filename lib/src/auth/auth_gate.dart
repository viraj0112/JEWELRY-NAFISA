import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/reset_password_screen.dart';
import 'package:jewelry_nafisa/src/designer/designer_shell.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/main_shell.dart';
import 'package:jewelry_nafisa/src/ui/screens/welcome/welcome_screen.dart';
import 'package:jewelry_nafisa/src/utils/user_profile_utils.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:jewelry_nafisa/src/designer/screens/pending_approval_screen.dart';

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
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ResetPasswordScreen()), (route) => false);
        }
        return;
      }

      if (session == null) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
        }
      } else {
        if (mounted) {
          _ensureAndFetchProfile(context, session.user.id);
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
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await _ensureAndFetchProfile(context, session.user.id);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  Future<void> _ensureAndFetchProfile(BuildContext context, String userId) async {
    final provider = Provider.of<UserProfileProvider>(context, listen: false);

    await UserProfileUtils.ensureUserProfile(userId);
    if (!mounted) return;

    await provider.fetchProfile();
    if (!mounted) return;

    if (provider.isDesigner) {
      if (provider.isApproved) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DesignerShell()), (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PendingApprovalScreen()), (route) => false,
        );
      }
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()), (route) => false,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}