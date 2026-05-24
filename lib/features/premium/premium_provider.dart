/// Provider exposing premium state to the widget tree.
///
/// Wraps [PremiumService]: re-emits its `changes` stream as ChangeNotifier
/// notifications and proxies its sync getter so widgets can rebuild on
/// premium state transitions.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/premium_service.dart';

class PremiumProvider extends ChangeNotifier {
  StreamSubscription<void>? _premiumSub;
  StreamSubscription<User?>? _authSub;

  PremiumProvider() {
    _premiumSub = PremiumService.instance.changes.listen((_) => notifyListeners());
    _authSub = AuthService.authChanges().listen((_) => notifyListeners());
  }

  /// Cached premium flag. Use this in widget build methods.
  bool get isPremium => PremiumService.instance.isPremiumSync();

  /// Currently signed-in Firebase user (null when signed out).
  User? get user => AuthService.currentUser;
  bool get isSignedIn => user != null;

  /// Trigger a Google Sign-In flow. On success, bootstraps device + PET.
  Future<User?> signIn() async {
    final user = await AuthService.signInWithGoogle();
    // PremiumService listens to auth changes and bootstraps automatically.
    return user;
  }

  Future<void> signOut() async {
    await AuthService.signOut();
  }

  /// Force-refresh from the server (e.g. pull-to-refresh on the premium screen).
  Future<void> refresh() => PremiumService.instance.refresh();

  @override
  void dispose() {
    _premiumSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
