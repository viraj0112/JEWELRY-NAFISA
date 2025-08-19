import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/home/home_screen.dart';
import 'package:jewelry_nafisa/src/utils/user_profile_utils.dart'; 
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // bool _fetchedForUserId = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final session = snapshot.data?.session;
        if (session == null) {
          return const LoginScreen();
        }
        return FutureBuilder<void>(
          future: _ensureAndFetchProfile(context, session.user.id),
          builder: (context, futureSnapshot) {
            if (futureSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (futureSnapshot.hasError) {
              return const Scaffold(
                body: Center(child: Text("Error loading profile.")),
              );
            }
            return const HomeScreen();
          },
        );
      },
    );
  }

  // NEW HELPER FUNCTION
  Future<void> _ensureAndFetchProfile(BuildContext context, String userId) async {
    await UserProfileUtils.ensureUserProfile(userId);
    if (mounted) {
      await Provider.of<UserProfileProvider>(context, listen: false).fetchProfile();
    }
  }
}