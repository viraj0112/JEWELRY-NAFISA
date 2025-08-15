import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/login_screen.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/home/home_screen.dart';
import 'package:provider/provider.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // User is not signed in
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // User is signed in, fetch their profile then show the HomeScreen
        final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);

        // Use a FutureBuilder to wait for the profile to be fetched
        return FutureBuilder(
          future: profileProvider.fetchProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
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