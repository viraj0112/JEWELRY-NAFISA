import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/home/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _fetchedForUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // User is not signed in
        final session = snapshot.data?.session;
        if (session == null) {
          // reset fetched id when user signs out
          _fetchedForUserId = null;
          return const LoginScreen();
        }

        // User is signed in
        final profileProvider = Provider.of<UserProfileProvider>(
          context,
          listen: false,
        );

        final userId = session.user.id;

        // If we haven't fetched for this user yet, schedule a post-frame fetch
        if (_fetchedForUserId != userId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            profileProvider.fetchProfile();
          });
          _fetchedForUserId = userId;
        }

        // Show loading while profile is being fetched
        return Consumer<UserProfileProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}
