/// Thin wrapper around Firebase Auth + Google Sign-In.
///
/// Only handles the auth handshake; downstream services (PremiumService) react
/// to `authStateChanges` to bootstrap their state.
library;

import 'dart:developer' as dev;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static const _tag = 'AuthService';
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  /// Listen for sign-in/out events. Reflects the underlying Firebase Auth user.
  static Stream<User?> authChanges() => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;
  static bool get isSignedIn => _auth.currentUser != null;

  /// One-tap Google Sign-In returning the signed-in [User], or null if the
  /// user cancelled the account picker.
  static Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        dev.log('User cancelled Google Sign-In', name: _tag);
        return null;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      dev.log('Signed in: ${result.user?.email}', name: _tag);
      return result.user;
    } on FirebaseAuthException catch (e) {
      dev.log('FirebaseAuth error: ${e.code} ${e.message}', name: _tag);
      rethrow;
    } catch (e) {
      dev.log('Google Sign-In error: $e', name: _tag);
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      dev.log('Signed out', name: _tag);
    } catch (e) {
      dev.log('Sign-out error (continuing): $e', name: _tag);
    }
  }
}
