import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a single, configured instance of GoogleSignIn
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? const String.fromEnvironment('GOOGLE_SIGN_IN_WEB_CLIENT_ID')
        : null,
  );

  // Helper to save user data to Supabase
  Future<void> _saveUserToSupabase(
    User user, {
    String? username,
    String? birthdate, // Added birthdate
  }) async {
    final supabase = sp.Supabase.instance.client;
    try {
      // Use upsert to either insert a new user or update an existing one.
      await supabase.from('Users').upsert({
        'id': user.uid, // Firebase UID as the text primary key
        'email': user.email,
        'username':
            username ?? user.displayName ?? user.email?.split('@').first,
        // Only include birthdate if it's not null or empty
        if (birthdate != null && birthdate.isNotEmpty) 'birthdate': birthdate,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print("Supabase Error: Failed to save user data. $e");
    }
  }

  // EMAIL & PASSWORD SIGN UP
  Future<User?> signUpWithEmailPassword(
    String email,
    String password,
    String username,
    String birthdate, // Added birthdate
  ) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        // Update the user's display name in Firebase
        await credential.user!.updateDisplayName(username);
        // Save all data to Supabase
        await _saveUserToSupabase(
          credential.user!,
          username: username,
          birthdate: birthdate,
        );
      }
      return credential.user;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Exception (Sign Up): ${e.message}");
      return null;
    }
  }

  // EMAIL & PASSWORD SIGN IN
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Exception (Sign In): ${e.message}");
      return null;
    }
  }

  // GOOGLE SIGN IN
  Future<User?> signInWithGoogle() async {
    try {
      // Now use the pre-configured _googleSignIn instance
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print("Google sign-in was cancelled by the user.");
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      if (userCredential.user != null) {
        await _saveUserToSupabase(userCredential.user!);
      }
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Exception (Google Sign In): ${e.message}");
      return null;
    } catch (e) {
      print("An unexpected error occurred during Google Sign In: $e");
      return null;
    }
  }

  // SIGN OUT
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
