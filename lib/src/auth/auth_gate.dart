import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/home/home_screen.dart';
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
      final Session? session = data.session;
      if (session == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      } else {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
           _ensureAndFetchProfile(context, session.user.id).then((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
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
    await Future.delayed(Duration.zero);
    
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      await _ensureAndFetchProfile(context, session.user.id);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
    }
  }

  Future<void> _ensureAndFetchProfile(BuildContext context, String userId) async {
    final provider = Provider.of<UserProfileProvider>(context, listen: false);
    await UserProfileUtils.ensureUserProfile(userId);
    if (mounted) {
      await provider.fetchProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}