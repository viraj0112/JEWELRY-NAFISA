import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/models/designer_profile.dart';
import 'package:jewelry_nafisa/src/models/manufacturer_profile.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Thrown when a sign-up is attempted with an address that already has an
/// account. Distinct from a generic failure so the forms can say something
/// actionable ("log in instead") rather than "something went wrong".
class EmailAlreadyRegisteredException implements Exception {
  const EmailAlreadyRegisteredException({this.isConfirmed = true});

  /// False when the account exists but was never email-verified — that user
  /// needs the confirmation mail resent, not a new account.
  final bool isConfirmed;

  String get message => isConfirmed
      ? 'This email is already registered. Please log in instead.'
      : 'This email is already registered but not verified yet. '
          'Check your inbox for the confirmation link.';

  @override
  String toString() => message;
}

class SupabaseAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? const String.fromEnvironment('GOOGLE_SIGN_IN_WEB_CLIENT_ID')
        : null,
  );

  User? get currentUser => _supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // ───────────────────────────────────────────────────────────────────────────
  //  Duplicate-email protection
  // ───────────────────────────────────────────────────────────────────────────

  /// Pre-flight check against `auth.users` via the `email_is_registered` RPC.
  ///
  /// Call this BEFORE doing any expensive work (the business form uploads two
  /// documents before it reaches signUp). It is advisory only — two requests
  /// can still race — which is why [_assertNotDuplicate] also runs after
  /// signUp and a unique index backs both up in the database.
  Future<void> ensureEmailAvailable(String email) async {
    final Map<String, dynamic> result;
    try {
      final res = await _supabase
          .rpc('email_is_registered', params: {'p_email': email.trim()});
      result = Map<String, dynamic>.from(res as Map);
    } catch (e) {
      // A failing pre-check must not block sign-up: the post-signUp check and
      // the DB constraint still catch a real duplicate.
      debugPrint('email_is_registered check unavailable: $e');
      return;
    }
    if (result['exists'] == true) {
      throw EmailAlreadyRegisteredException(
        isConfirmed: result['confirmed'] == true,
      );
    }
  }

  /// Post-signUp check.
  ///
  /// With "Confirm email" + enumeration protection enabled, Supabase does not
  /// error on a duplicate — it returns a decoy user whose `identities` list is
  /// empty. That empty list is the only signal that the address was taken.
  void _assertNotDuplicate(AuthResponse response) {
    final identities = response.user?.identities;
    if (response.user != null && identities != null && identities.isEmpty) {
      throw const EmailAlreadyRegisteredException();
    }
  }

  /// Maps Supabase's own duplicate-email errors (raised when enumeration
  /// protection is off) onto our typed exception.
  bool _isDuplicateAuthError(Object e) {
    if (e is EmailAlreadyRegisteredException) return true;
    final text = e.toString().toLowerCase();
    return text.contains('already registered') ||
        text.contains('already been registered') ||
        text.contains('user already exists') ||
        text.contains('duplicate key') && text.contains('email');
  }

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
    await ensureEmailAvailable(email);
    try {
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': fullName, 'role': 'designer'},
      );
      _assertNotDuplicate(authResponse);

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
    } on EmailAlreadyRegisteredException {
      rethrow;
    } on AuthException catch (e) {
      debugPrint('Auth Error during designer sign-up: ${e.message}');
      if (_isDuplicateAuthError(e)) {
        throw const EmailAlreadyRegisteredException();
      }
      return null;
    } catch (e) {
      debugPrint('An unexpected error occurred during designer sign-up: $e');
      if (_isDuplicateAuthError(e)) {
        throw const EmailAlreadyRegisteredException();
      }
      return null;
    }
  }

  Future<User?> signUpWithEmailPassword(
    String email,
    String password,
    String username,
    String phone,
    String birthdate,
    String? referralCode,
  ) async {
    await ensureEmailAvailable(email);
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'phone': phone,
          'birthdate': birthdate,
          'referral_code_used': referralCode
        },
      );
      _assertNotDuplicate(response);
      return response.user;
    } catch (e) {
      debugPrint('Exception during sign up: $e');
      // A duplicate email is a user-fixable problem, so it must surface as
      // itself instead of collapsing into a null "sign up failed".
      if (_isDuplicateAuthError(e)) {
        throw e is EmailAlreadyRegisteredException
            ? e
            : const EmailAlreadyRegisteredException();
      }
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
    await ensureEmailAvailable(email);
    try {
      final String username =
          '${businessName.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
      final String role = businessType.toLowerCase() == 'manufacturer'
          ? 'manufacturer'
          : 'designer';

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'business_name': businessName,
          'business_type': businessType,
          'phone': phone,
          'role': role,
          'address': address,
          'gst_number': gstNumber,
        },
      );

      _assertNotDuplicate(response);

      return response.user;
    } catch (e) {
      debugPrint('Exception during business sign up: $e');
      if (_isDuplicateAuthError(e)) {
        throw e is EmailAlreadyRegisteredException
            ? e
            : const EmailAlreadyRegisteredException();
      }
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
