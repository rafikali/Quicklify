/// Thin wrapper around Firebase Auth + Google Sign-In.
///
/// Only handles the auth handshake; downstream services (PremiumService) react
/// to `authStateChanges` to bootstrap their state.
library;

import 'dart:async';
import 'dart:developer' as dev;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../analytics/analytics_events.dart';
import '../analytics/analytics_service.dart';

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
      AnalyticsService.instance.logEvent(AnalyticsEvent.signInSuccess);
      final uid = result.user?.uid;
      unawaited(AnalyticsService.instance.setUserId(uid));
      // Bridge pre-login activity into the user's profile log so the
      // admin timeline is continuous across sign-in.
      if (uid != null) {
        unawaited(AnalyticsService.instance.mergeAnonymousActivity(uid));
      }
      return result.user;
    } on FirebaseAuthException catch (e) {
      dev.log('FirebaseAuth error: ${e.code} ${e.message}', name: _tag);
      AnalyticsService.instance.logEvent(
        AnalyticsEvent.signInFailed,
        params: {AnalyticsParam.error: e.code},
      );
      rethrow;
    } catch (e) {
      dev.log('Google Sign-In error: $e', name: _tag);
      AnalyticsService.instance.logEvent(
        AnalyticsEvent.signInFailed,
        params: {AnalyticsParam.error: e.toString()},
      );
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
      AnalyticsService.instance.logEvent(AnalyticsEvent.signOut);
      unawaited(AnalyticsService.instance.setUserId(null));
    } catch (e) {
      dev.log('Sign-out error (continuing): $e', name: _tag);
    }
  }
}
