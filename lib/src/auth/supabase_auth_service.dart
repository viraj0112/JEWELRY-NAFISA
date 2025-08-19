// lib/src/auth/supabase_auth_service.dart

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SupabaseAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // This instance is still needed for the signOut method to work correctly.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? const String.fromEnvironment('GOOGLE_SIGN_IN_WEB_CLIENT_ID')
        : null,
  );

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<void> _syncUserProfileToSupabase({
    required String uid,
    String? email,
    String? username,
    String? birthdate,
  }) async {
    try {
      debugPrint('Attempting to sync user profile with ID: $uid');
      await _supabase.from('Users').upsert({
        'id': uid,
        if (email != null) 'email': email,
        if (username != null && username.isNotEmpty) 'username': username,
        if (birthdate != null && birthdate.isNotEmpty) 'birthdate': birthdate,
        'membership_status': 'free',
        'credits_remaining': 0,
      });
      debugPrint('User profile synced successfully.');
    } catch (e) {
      debugPrint("Supabase Error: Failed to sync user profile: $e");
      rethrow;
    }
  }

  Future<User?> signUpWithEmailPassword(
    String email,
    String password,
    String username,
    String birthdate,
    BuildContext context,
  ) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username, 'birthdate': birthdate},
      );
      final user = response.user;
      if (user != null) {
        await _syncUserProfileToSupabase(
          uid: user.id,
          email: email,
          username: username,
          birthdate: birthdate,
        );
        return user;
      }
    } catch (e) {
      debugPrint('Exception during sign up: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sign-up failed: ${e.toString()}")),
        );
      }
    }
    return null;
  }

  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user;
    } catch (e) {
      debugPrint('Exception during sign in: $e');
    }
    return null;
  }

  // **CORRECTED** Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      // Use OAuthProvider.google instead of Provider.google
      final redirectUrl = kIsWeb
          ? 'https://nafisa-jewellery-akd.netlify.app'
          : null;

      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
    } catch (e) {
      debugPrint("Error during Google Sign In: $e");
    }
    // This method is now void because it only triggers the redirect.
    // The actual sign-in is detected by the AuthGate's stream listener.
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint("Error during sign out: $e");
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint("Error during password reset: $e");
      rethrow;
    }
  }

  bool get isSignedIn => _supabase.auth.currentUser != null;
}
