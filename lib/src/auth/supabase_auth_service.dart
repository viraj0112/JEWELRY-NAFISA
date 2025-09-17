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
    String? referralCode, 
  ) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username, 'birthdate': birthdate},
      );
      if (response.user != null &&
          referralCode != null &&
          referralCode.isNotEmpty) {
        await _supabase.functions.invoke(
          'handle-referral',
          body: {
            'referral_code': referralCode,
            'new_user_id': response.user!.id,
          },
        );
      }

      return response.user;
    } catch (e) {
      debugPrint('Exception during sign up: $e');
      return null;
    }
  }

  Future<User?> signInWithEmailOrUsername(
    String emailOrUsername,
    String password,
  ) async {
    try {
      String email = emailOrUsername;
      // 1. Check if the input is a username (doesn't contain '@')
      if (!emailOrUsername.contains('@')) {
        // 2. If it's a username, call the RPC function to get the email
        final response = await _supabase
            .rpc(
              'get_email_by_username',
              params: {'p_username': emailOrUsername},
            )
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

  Future<User?> signUpBusiness({
    required String email,
    required String password,
    required String businessName,
    required String businessType,
    required String phone,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        // This 'data' object passes the extra business info to Supabase.
        data: {
          'business_name': businessName,
          'business_type': businessType,
          'phone': phone,
          'role': 'designer', // This sets their role to 'designer' [cite: 1790]
        },
      );
      return response.user;
    } catch (e) {
      debugPrint('Exception during business sign up: $e');
      return null;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      // Use a consistent deep link for mobile that you will configure natively.
      // For web, Supabase will use your project's Site URL by default.
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb
            ? null
            : 'com.example.jewelryNafisa://reset-password',
      );
    } catch (e) {
      debugPrint("Error during password reset: $e");
      rethrow;
    }
  }

  Future<bool> updateUserPassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      // It's good practice to sign out after a password change.
      await _supabase.auth.signOut();
      return true;
    } catch (e) {
      debugPrint("Error updating password: $e");
      return false;
    }
  }

  bool get isSignedIn => _supabase.auth.currentUser != null;
}
