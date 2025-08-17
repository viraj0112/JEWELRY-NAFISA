import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? const String.fromEnvironment('GOOGLE_SIGN_IN_WEB_CLIENT_ID')
        : null,
  );

  final sp.SupabaseClient _supabase = sp.Supabase.instance.client;

  // NEW HELPER FUNCTION: This is the key change.
  // It takes the user details from Firebase and creates a corresponding
  // profile row in your public.Users table.
  Future<void> _syncUserProfileToSupabase({
    required String uid,
    String? email,
    String? username,
    String? birthdate,
  }) async {
    try {
      debugPrint('Syncing user profile to Supabase for UID: $uid');
      // 'upsert' is used to either INSERT a new profile or UPDATE an existing one.
      // This prevents errors if a user signs in who already has a profile.
      await _supabase.from('Users').upsert({
        'id': uid,
        if (email != null) 'email': email,
        if (username != null && username.isNotEmpty) 'username': username,
        if (birthdate != null && birthdate.isNotEmpty) 'birthdate': birthdate,
        'membership_status': 'free',
        'credits_remaining': 0,
      });

      debugPrint("User profile synced successfully.");
    } catch (e) {
      // This error usually means your RLS policy is blocking the upsert.
      debugPrint(
        "Supabase Error: Failed to sync user profile. Check RLS policies on the 'Users' table. Error: $e",
      );
      // Rethrowing the error so the calling function can handle it.
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
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(username);
        final idToken = await firebaseUser.getIdToken();

        await _supabase.auth.signInWithIdToken(
          provider: sp.OAuthProvider.google,
          idToken: idToken!,
        );

        debugPrint(
          'Supabase auth session created: ${_supabase.auth.currentUser?.id}',
        );

        await _syncUserProfileToSupabase(
          uid: firebaseUser.uid,
          email: email,
          username: username,
          birthdate: birthdate,
        );

        return firebaseUser;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Exception (Sign Up): ${e.message}");
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Sign-up failed: ${e.message}")));
      }
      return null;
    } catch (e) {
      debugPrint('Supabase/Other Exception (Sign Up): $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not sync profile. Please try again."),
          ),
        );
      }
      return null;
    }
    return null;
  }

  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      // 1. Sign into Firebase
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser != null) {
        final idToken = await firebaseUser.getIdToken();

        // 2. Sign into Supabase to create a session
        await _supabase.auth.signInWithIdToken(
          provider: sp.OAuthProvider.google,
          idToken: idToken!,
        );

        debugPrint(
          'Supabase auth session created: ${_supabase.auth.currentUser?.id}',
        );

        // Note: We don't need to sync the profile here because it was already
        // synced during their initial sign-up.

        return firebaseUser;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Exception (Sign In): ${e.message}");
      return null;
    } catch (e) {
      debugPrint('Supabase Exception (Sign In): $e');
      return null;
    }
    return null;
  }

  Future<User?> signInWithGoogle() async {
    try {
      // 1. Authenticate with Google & Firebase
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser != null && idToken != null) {
        // 2. Sign into Supabase
        await _supabase.auth.signInWithIdToken(
          provider: sp.OAuthProvider.google,
          idToken: idToken,
          accessToken: googleAuth.accessToken,
        );

        debugPrint(
          'Supabase session created: ${_supabase.auth.currentUser?.id}',
        );

        // 3. CRITICAL STEP: Sync profile data. The 'upsert' handles both
        // new and returning Google users perfectly.
        await _syncUserProfileToSupabase(
          uid: firebaseUser.uid,
          email: firebaseUser.email,
          username: firebaseUser.displayName,
        );

        return firebaseUser;
      }
    } catch (e) {
      debugPrint("An error occurred during Google Sign In: $e");
      return null;
    }
    return null;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await _supabase.auth.signOut();
  }
}

