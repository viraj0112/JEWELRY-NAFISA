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
        // If the stream has emitted data, use it
        if (snapshot.hasData) {
          final session = snapshot.data?.session;
          if (session != null) {
            return ProfileLoader(key: ValueKey(session.user.id));
          } else {
            return const WelcomeScreen();
          }
        }

        // Fallback: Check current session directly if stream hasn't emitted yet
        final currentSession = Supabase.instance.client.auth.currentSession;
        if (currentSession != null) {
          return ProfileLoader(key: ValueKey(currentSession.user.id));
        }

        return const WelcomeScreen();
      },
    );
  }
}
