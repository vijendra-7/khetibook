import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';


class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Get user stream
  Stream<User?> get user => _auth.authStateChanges();

  // Get current user synchronously
  User? get currentUser => _auth.currentUser;

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) return null;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        await updateUserProfile(userCredential.user!);
      }
      
      return userCredential;
    } catch (e) {
      debugPrint('Error in Google Sign-In: $e');
      return null;
    }
  }

  // Sign in with Apple (iOS only)
  Future<UserCredential?> signInWithApple() async {
    if (!Platform.isIOS) return null;
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Apple only sends displayName on the very first sign-in.
      // If we have a name from Apple, update Firebase profile and Firestore.
      if (userCredential.user != null) {
        final appleFullName = appleCredential.givenName != null
            ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim()
            : null;
        if (appleFullName != null && appleFullName.isNotEmpty &&
            userCredential.user!.displayName == null) {
          await userCredential.user!.updateDisplayName(appleFullName);
        }
        await updateUserProfile(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Error in Apple Sign-In: $e');
      return null;
    }
  }

  // Anonymous sign-in (no account required)
  Future<UserCredential?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential;
    } catch (e) {
      debugPrint('Error in Anonymous Sign-In: $e');
      return null;
    }
  }

  /// Attempts to sign in silently using existing Google account on the device.
  /// This is useful for restoring Firebase session if it's lost but Google session is active.
  Future<User?> signInSilently() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint('Error in silent sign-in: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(User user) async {
    try {
      await _firestore.collection('users_profiles').doc(user.uid).set({
        'uid': user.uid,
        'displayName': user.displayName,
        'email': user.email,
        'lastActive': FieldValue.serverTimestamp(),
        'photoURL': user.photoURL,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user profile: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
}
