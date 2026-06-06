/// Watches the signed-in user's `profiles/{uid}.banned` flag.
///
/// When a user is banned via the admin panel, the change propagates in real
/// time through Firestore — the gate then renders the blackout screen.
///
/// Signed-out users are never banned (there's no profile to read), so the
/// gate falls through to the app normally.
library;

import 'dart:async';
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

class UserBanService {
  UserBanService._();
  static final instance = UserBanService._();

  static const _tag = 'UserBanService';
  static const _defaultReason =
      'Your account has been suspended by an administrator.';

  final _db = FirebaseFirestore.instance;

  bool _isBanned = false;
  String? _reason;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<User?>? _authSub;
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;
  bool get isBanned => _isBanned;
  String get banReason => _reason ?? _defaultReason;

  Future<void> initialize() async {
    _authSub = AuthService.authChanges().listen(_onAuthChanged);
    if (AuthService.isSignedIn) {
      _watchProfile(AuthService.currentUser!.uid);
    }
  }

  void _onAuthChanged(User? user) {
    _profileSub?.cancel();
    _profileSub = null;
    if (user == null) {
      // Signed out — clear any banned state.
      if (_isBanned) {
        _isBanned = false;
        _reason = null;
        _changes.add(null);
      }
      return;
    }
    _watchProfile(user.uid);
  }

  void _watchProfile(String uid) {
    _profileSub = _db.collection('profiles').doc(uid).snapshots().listen(
      (snap) {
        final data = snap.data();
        final nextBanned = (data?['banned'] as bool?) ?? false;
        final nextReason = data?['banReason'] as String?;
        if (nextBanned != _isBanned || nextReason != _reason) {
          _isBanned = nextBanned;
          _reason = nextReason;
          _changes.add(null);
        }
      },
      onError: (e) {
        dev.log('profile listener error: $e', name: _tag);
      },
    );
  }

  /// Force a one-shot fetch (used by AppGate on resume so a ban applied
  /// while the app was backgrounded takes effect immediately).
  Future<void> fetchOnce() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await _db.collection('profiles').doc(uid).get();
      final data = snap.data();
      final nextBanned = (data?['banned'] as bool?) ?? false;
      final nextReason = data?['banReason'] as String?;
      if (nextBanned != _isBanned || nextReason != _reason) {
        _isBanned = nextBanned;
        _reason = nextReason;
        _changes.add(null);
      }
    } catch (e) {
      dev.log('fetchOnce failed: $e', name: _tag);
    }
  }

  Future<void> dispose() async {
    await _profileSub?.cancel();
    await _authSub?.cancel();
    await _changes.close();
  }
}
