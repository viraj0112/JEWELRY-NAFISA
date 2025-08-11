import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper to save user data to Supabase
  Future<void> _saveUserToSupabase(User user, {String? username}) async {
    final supabase = sp.Supabase.instance.client;
    try {
      // Use upsert to either insert a new user or update an existing one.
      await supabase.from('Users').upsert({
        'id': user.uid, // Firebase UID as primary key
        'email': user.email,
        'username': username ?? user.displayName,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print("Supabase Error: Failed to save user data. $e");
    }
  }

  // EMAIL & PASSWORD SIGN UP
  Future<User?> signUpWithEmailPassword(String email, String password, String username) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        // Update the user's display name in Firebase
        await credential.user!.updateDisplayName(username);
        await _saveUserToSupabase(credential.user!, username: username);
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
  // GOOGLE SIGN IN
  Future<User?> signInWithGoogle() async {
    try {
      const googleSignInWebClientId = String.fromEnvironment('GOOGLE_SIGN_IN_WEB_CLIENT_ID');
      final googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? googleSignInWebClientId : null,
      );
      // Trigger the authentication flow.
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // The user canceled the sign-in
        print("Google sign-in was cancelled by the user.");
        return null;
      }

      // Obtain the auth details from the request.
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential for Firebase.
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential.
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Save user data to Supabase.
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
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}