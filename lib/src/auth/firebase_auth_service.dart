import 'package:firebase_auth/firebase_auth.dart';
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

  // Helper to save user profile data to your public 'Users' table
  Future<void> _saveUserToPublicTable({
    required String uid,
    String? email,
    String? username,
    String? birthdate,
  }) async {
    try {
      await _supabase.from('Users').upsert({
        'id': uid, // The Firebase UID
        'email': email,
        'username': username,
        if (birthdate != null && birthdate.isNotEmpty) 'birthdate': birthdate,
      });
    } catch (e) {
      print("Supabase Error: Failed to save user data to public table. $e");
    }
  }

  // EMAIL & PASSWORD SIGN UP
  Future<User?> signUpWithEmailPassword(
    String email,
    String password,
    String username,
    String birthdate,
  ) async {
    try {
      // 1. Create user in Firebase
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;

      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(username);
        final idToken = await firebaseUser.getIdToken();

        // 2. Sign into Supabase using the Firebase token
        await _supabase.auth.signInWithIdToken(
          provider: sp.OAuthProvider.google, // Use google provider for Firebase
          idToken: idToken!,
        );

        // 3. Save additional profile info to your public 'Users' table
        await _saveUserToPublicTable(
          uid: firebaseUser.uid,
          email: email,
          username: username,
          birthdate: birthdate,
        );
      }
      return firebaseUser;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Exception (Sign Up): ${e.message}");
      return null;
    }
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
          provider: sp.OAuthProvider.google,
          idToken: idToken!,
        );
      }
      return firebaseUser;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Exception (Sign In): ${e.message}");
      return null;
    }
  }

  // GOOGLE SIGN IN
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser != null && idToken != null) {
        // Sign into Supabase using the Google ID token
        await _supabase.auth.signInWithIdToken(
          provider: sp.OAuthProvider.google,
          idToken: idToken,
        );

        // Save profile info to your public 'Users' table
        await _saveUserToPublicTable(
          uid: firebaseUser.uid,
          email: firebaseUser.email,
          username: firebaseUser.displayName,
        );
      }
      return firebaseUser;
    } catch (e) {
      print("An error occurred during Google Sign In: $e");
      return null;
    }
  }

  // SIGN OUT
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await _supabase.auth.signOut();
  }
}