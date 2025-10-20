import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/models/designer_profile.dart';
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

  // ... (signUpAdmin, signUpWithEmailPassword, signInWithEmailOrUsername, signInWithGoogle, signOut, signUpBusiness, resetPassword functions are unchanged)
  Future<User?> signUpAdmin({
    required String email,
    required String password,
    required String fullName,
    required String businessType,
    required String phone,
    required String address,
    String? gstNumber,
    required File? workFile,
    required File? businessCardFile,
  }) async {
    try {
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': fullName, 'role': 'designer'},
      );

      final user = authResponse.user;

      if (user == null) throw Exception("User creation failed.");

      String? workFileUrl;
      if (workFile != null) {
        final fileName = workFile.path.split('/').last;
        final uploadPath = 'designer-uploads/${user.id}/$fileName';

        await _supabase.storage
            .from('designer-files')
            .upload(uploadPath, workFile);
        workFileUrl =
            _supabase.storage.from('designer-files').getPublicUrl(uploadPath);
      }

      String? businessCardUrl;
      if (businessCardFile != null) {
        final fileName = businessCardFile.path.split('/').last;
        final uploadPath = 'designer-uploads/${user.id}/$fileName';

        await _supabase.storage
            .from('designer-files')
            .upload(uploadPath, businessCardFile);
        businessCardUrl =
            _supabase.storage.from('designer-files').getPublicUrl(uploadPath);
      }

      final designerProfile = DesignerProfile(
          userId: user.id,
          businessName: fullName,
          businessType: businessType,
          phone: phone,
          address: address,
          gstNumber: gstNumber,
          workFileUrl: workFileUrl,
          businessCardUrl: businessCardUrl);

      await _supabase.from("designer_profiles").insert(designerProfile.toMap());

      return user;
    } on AuthException catch (e) {
      debugPrint('Auth Error during designer sign-up: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('An unexpected error occurred during designer sign-up: $e');
      return null;
    }
  }

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
        data: {
          'username': username,
          'birthdate': birthdate,
          'referral_code_used': referralCode
        },
      );
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
        final response = await _supabase.rpc(
          'get_email_by_username',
          params: {'p_username': emailOrUsername},
        ).maybeSingle();

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
    required String address,
    required String gstNumber,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'business_name': businessName,
          'business_type': businessType,
          'phone': phone,
          'role': 'designer',
          'address': address,
          'gst_number': gstNumber,
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
        redirectTo:
            kIsWeb ? null : 'com.example.jewelryNafisa://reset-password',
      );
    } catch (e) {
      debugPrint("Error during password reset: $e");
      rethrow;
    }
  }

  // --- ADD THIS NEW FUNCTION ---
  /// Prompts Supabase to send a confirmation email to change the user's email.
  Future<void> updateUserEmail(String newEmail) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(email: newEmail),
        // You might want to specify a redirect URL for the confirmation email
        // emailRedirectTo: kIsWeb ? '${Uri.base.origin}/auth-callback' : 'com.example.jewelryNafisa://email-confirmed',
      );
    } catch (e) {
      debugPrint("Error updating email: $e");
      rethrow;
    }
  }
  // -----------------------------

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