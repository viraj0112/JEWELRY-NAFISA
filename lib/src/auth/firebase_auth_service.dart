// lib/src/auth/firebase_auth_service.dart

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

  Future<void> _syncUserProfileToSupabase({
    required String uid,
    String? email,
    String? username,
    String? birthdate,
  }) async {
    try {
      // Use the Supabase user ID, which is now a valid UUID
      await _supabase.from('Users').upsert({
        'id': uid,
        if (email != null) 'email': email,
        if (username != null && username.isNotEmpty) 'username': username,
        if (birthdate != null && birthdate.isNotEmpty) 'birthdate': birthdate,
      });
      debugPrint('User profile synced successfully.');
    } catch (e) {
      debugPrint("Supabase Error: Failed to sync user profile: $e");
      rethrow;
    }
  }

  // --- SIGN UP WITH EMAIL & PASSWORD (CORRECTED) ---
  Future<User?> signUpWithEmailPassword(
    String email,
    String password,
    String username,
    String birthdate,
    BuildContext context,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final firebaseUser = credential.user;

      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(username);
        final idToken = await firebaseUser.getIdToken();

        // Use signInWithIdToken with the 'google' provider.
        // This requires a configuration change in your Supabase dashboard (see Step 2).
        final authResponse = await _supabase.auth.signInWithIdToken(
          provider: sp.OAuthProvider.google,
          idToken: idToken!,
        );

        // **CRITICAL:** Use the UID from the Supabase response from now on.
        final supabaseUser = authResponse.user;
        if (supabaseUser != null) {
            await _syncUserProfileToSupabase(
                uid: supabaseUser.id, // Use the new Supabase UID
                email: email,
                username: username,
                birthdate: birthdate,
            );
        }
        return firebaseUser;
      }
    } catch (e) {
      debugPrint('Exception during sign up: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sign-up failed: ${e.toString()}")));
      }
    }
    return null;
  }

  // --- SIGN IN WITH EMAIL & PASSWORD (CORRECTED) ---
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final firebaseUser = credential.user;
      if (firebaseUser != null) {
        final idToken = await firebaseUser.getIdToken();
        
        await _supabase.auth.signInWithIdToken(
          provider: sp.OAuthProvider.google,
          idToken: idToken!,
        );
        return firebaseUser;
      }
    } catch (e) {
      debugPrint('Exception during sign in: $e');
    }
    return null;
  }
  
  // --- SIGN IN WITH GOOGLE (Unchanged, already correct) ---
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: idToken);
      
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      
      if (firebaseUser != null && idToken != null) {
        final authResponse = await _supabase.auth.signInWithIdToken(
          provider: sp.OAuthProvider.google,
          idToken: idToken,
          accessToken: googleAuth.accessToken,
        );
        
        final supabaseUser = authResponse.user;
        if (supabaseUser != null) {
            await _syncUserProfileToSupabase(
                uid: supabaseUser.id,
                email: firebaseUser.email,
                username: firebaseUser.displayName,
            );
        }
        return firebaseUser;
      }
    } catch (e) {
      debugPrint("Error during Google Sign In: $e");
    }
    return null;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await _supabase.auth.signOut();
  }
}