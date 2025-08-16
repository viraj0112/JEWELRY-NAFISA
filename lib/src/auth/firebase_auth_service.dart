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

  // MODIFIED HELPER: This is now the single source of truth for syncing profile data.
  Future<void> _syncUserProfileToSupabase({
    required String uid,
    String? email,
    String? username,
    String? birthdate,
  }) async {
    try {
      debugPrint('Syncing user profile for UID: $uid');
      
      // 'upsert' creates a new row if 'id' doesn't exist, or updates it if it does.
      await _supabase.from('Users').upsert({
        'id': uid, // The Firebase UID now matches the Supabase auth UID
        if (email != null) 'email': email,
        if (username != null && username.isNotEmpty) 'username': username,
        if (birthdate != null && birthdate.isNotEmpty) 'birthdate': birthdate,
        'membership_status': 'free',
        'credits_remaining': 0,
      });
      
      debugPrint('User profile synced successfully');
    } catch (e) {
      debugPrint("Supabase Error: Failed to sync user profile. Check RLS policies. Error: $e");
      rethrow;
    }
  }

  // MODIFIED SIGN UP
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
        
        // 1. Sign into Supabase using the Firebase token with 'google' provider
        // Note: We use google provider because Firebase ID tokens are compatible with Google OAuth
        await _supabase.auth.signInWithIdToken(
          provider: sp.OAuthProvider.google, // Use OAuthProvider enum
          idToken: idToken!,
        );
        
        debugPrint('Supabase session created: ${_supabase.auth.currentUser?.id}');
        
        // 2. **CRITICAL STEP**: Sync the new user's profile to your public table
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sign-up failed: ${e.message}"))
        );
      }
      return null;
    } catch (e) {
      debugPrint('Supabase/Other Exception (Sign Up): $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not sync profile. Please try again.")),
        );
      }
      return null;
    }
    return null;
  }

  // EMAIL & PASSWORD SIGN IN
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final firebaseUser = credential.user;
      if (firebaseUser != null) {
        final idToken = await firebaseUser.getIdToken();
        
        // Sign into Supabase using the Firebase token
        await _supabase.auth.signInWithIdToken(
          provider: sp.OAuthProvider.google, // Use OAuthProvider enum
          idToken: idToken!,
        );
        
        debugPrint('Supabase session created: ${_supabase.auth.currentUser?.id}');
        
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

  // MODIFIED GOOGLE SIGN IN
  Future<User?> signInWithGoogle() async {
    try {
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
        // 1. Sign into Supabase
        await _supabase.auth.signInWithIdToken(
          provider: sp.OAuthProvider.google, // Keep google for actual Google sign-ins
          idToken: idToken,
          accessToken: googleAuth.accessToken,
        );
        
        debugPrint('Supabase session created: ${_supabase.auth.currentUser?.id}');
        
        // 2. **CRITICAL STEP**: Sync profile data. `upsert` handles both new and returning users.
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

  // SIGN OUT
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await _supabase.auth.signOut();
  }
}
