import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/profile_loader.dart';
import 'package:jewelry_nafisa/src/ui/screens/welcome/welcome_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.session != null) {
          return ProfileLoader(key: ValueKey(snapshot.data!.session!.user.id));
        } else {
          return const WelcomeScreen();
        }
      },
    );
  }
}