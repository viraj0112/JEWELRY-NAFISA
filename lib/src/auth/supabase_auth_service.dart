import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SupabaseAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? const String.fromEnvironment('GOOGLE_SIGN_IN_WEB_CLIENT_ID')
        : null,
  );

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

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
      return response.user;
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

  // **NEW: Handles login with either email or username**
  Future<User?> signInWithEmailOrUsername(
      String emailOrUsername, String password) async {
    try {
      String email = emailOrUsername;
      // 1. Check if the input is a username (doesn't contain '@')
      if (!emailOrUsername.contains('@')) {
        // 2. If it's a username, call the RPC function to get the email
        final response = await _supabase
            .rpc('get_email_by_username', params: {'p_username': emailOrUsername})
            .maybeSingle();

        if (response != null && response['email'] != null) {
          email = response['email'];
        } else {
          // No user found with that username
          debugPrint('No user found with username: $emailOrUsername');
          return null;
        }
      }

      // 3. Proceed to sign in with the resolved email
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user;
    } catch (e) {
      debugPrint('Exception during sign in: $e');
      return null;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? '${Uri.base.origin}/auth-callback' : null,
      );
    } catch (e) {
      debugPrint("Error during Google Sign In: $e");
    }
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