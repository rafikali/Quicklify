/// Premium state orchestrator (Firestore-only, no Cloud Functions).
///
/// Listens to `profiles/{uid}/subscriptions` and exposes:
///   - `isPremium()`  async getter that re-reads the cache
///   - `isPremiumSync()` synchronous cached value (cheap, safe in build())
///   - `changes` stream the UI rebuilds on
///
/// On sign-in, also ensures the user's `profiles/{uid}` doc exists and
/// registers the current device (best-effort, soft 3-device cap enforced
/// client-side).
///
/// Security model (Option C):
///   - Firestore Rules prevent users from writing their own subscriptions.
///   - Reads go to Google over TLS, hard to MITM; cert pinning helps further.
///   - Multi-site inline check in ads_service.dart raises the bar for static
///     APK patching.
///   - No cryptographic signature on the premium flag — a tampered APK with
///     overridden cache *can* fake premium locally. Acceptable trade-off for
///     no-Functions / no-Blaze. See PREMIUM_RUNBOOK.md.
library;

import 'dart:async';
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_service.dart';
import 'device_fingerprint_service.dart';

class PremiumService {
  PremiumService._();
  static final instance = PremiumService._();

  static const _tag = 'PremiumService';
  static const _deviceIdKey = 'qlf_device_id';

  static final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final _db = FirebaseFirestore.instance;

  bool _isPremiumCache = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subSub;
  StreamSubscription<User?>? _authSub;

  final _changeController = StreamController<void>.broadcast();
  Stream<void> get changes => _changeController.stream;

  /// Soft cap; enforced client-side.
  static const int maxActiveDevices = 3;

  // -----------------------------------------------------------------------

  Future<void> initialize() async {
    dev.log('initializing', name: _tag);
    _authSub = AuthService.authChanges().listen(_onAuthChanged);
    // If already signed in (relaunch), kick off the listener now.
    if (AuthService.isSignedIn) {
      _startSubscriptionListener(AuthService.currentUser!.uid);
      // Don't await — registerDevice is best-effort.
      unawaited(_ensureProfileAndDevice());
    }
  }

  Future<void> dispose() async {
    await _subSub?.cancel();
    await _authSub?.cancel();
    await _changeController.close();
  }

  // -----------------------------------------------------------------------

  /// Cached premium flag — safe to call from build methods.
  bool isPremiumSync() => _isPremiumCache;

  /// Async variant. Equivalent to [isPremiumSync] for Option C since the
  /// Firestore listener keeps the cache up to date.
  Future<bool> isPremium() async => _isPremiumCache;

  /// Force-refresh: just bumps lastSeenAt and re-reads. The snapshot listener
  /// stays live, so this is mostly user-affordance ("Refresh status" button).
  Future<void> refresh() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('profiles').doc(uid).update({
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      dev.log('refresh: lastSeenAt update failed: $e', name: _tag);
    }
  }

  // -----------------------------------------------------------------------

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      await _onSignedOut();
    } else {
      _startSubscriptionListener(user.uid);
      await _ensureProfileAndDevice();
    }
  }

  void _startSubscriptionListener(String uid) {
    _subSub?.cancel();
    _subSub = _db
        .collection('profiles')
        .doc(uid)
        .collection('subscriptions')
        .where('active', isEqualTo: true)
        .snapshots()
        .listen(
      (snap) {
        final now = DateTime.now();
        final hasActive = snap.docs.any((d) {
          final data = d.data();
          if (data['tier'] != 'premium') return false;
          final endsAt = data['endsAt'];
          if (endsAt == null) return true; // lifetime
          if (endsAt is Timestamp) return endsAt.toDate().isAfter(now);
          return false;
        });
        _updateCache(hasActive);
      },
      onError: (e) {
        dev.log('subscription listener error: $e', name: _tag);
      },
    );
  }

  Future<void> _onSignedOut() async {
    await _subSub?.cancel();
    _subSub = null;
    await _storage.delete(key: _deviceIdKey);
    _updateCache(false);
  }

  void _updateCache(bool premium) {
    if (_isPremiumCache != premium) {
      _isPremiumCache = premium;
      _changeController.add(null);
    }
  }

  // -----------------------------------------------------------------------
  // Profile + device bootstrap (no Cloud Functions).

  Future<void> _ensureProfileAndDevice() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final uid = user.uid;

    try {
      final profileRef = _db.collection('profiles').doc(uid);
      final snap = await profileRef.get();
      if (!snap.exists) {
        await profileRef.set({
          'email': user.email ?? '',
          'displayName': user.displayName,
          'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
          'banned': false,
        });
      } else {
        await profileRef.update({
          'lastSeenAt': FieldValue.serverTimestamp(),
          // Refresh photo/name in case the user changed them on Google.
          if (user.displayName != null) 'displayName': user.displayName,
          if (user.photoURL != null) 'photoUrl': user.photoURL,
        });
      }

      await _ensureDeviceRow(uid);
    } catch (e) {
      dev.log('ensureProfileAndDevice failed: $e', name: _tag);
    }
  }

  Future<void> _ensureDeviceRow(String uid) async {
    final fingerprint = await DeviceFingerprintService.compute();
    final deviceName = await DeviceFingerprintService.deviceLabel();
    final devicesCol =
        _db.collection('profiles').doc(uid).collection('devices');

    // Reuse existing doc if same fingerprint already registered.
    final existing = await devicesCol
        .where('fingerprint', isEqualTo: fingerprint)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      await doc.reference.update({
        'lastSeenAt': FieldValue.serverTimestamp(),
        if (doc.data()['revokedAt'] != null) 'revokedAt': null,
      });
      await _storage.write(key: _deviceIdKey, value: doc.id);
      return;
    }

    // Client-side soft cap. A determined attacker can bypass via direct
    // Firestore write — admin sees + revokes via the panel.
    final activeCount = (await devicesCol
            .where('revokedAt', isNull: true)
            .count()
            .get())
        .count ?? 0;
    if (activeCount >= maxActiveDevices) {
      throw _DeviceLimitException(maxActiveDevices);
    }

    final newRef = await devicesCol.add({
      'fingerprint': fingerprint,
      'deviceName': deviceName,
      'registeredAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'revokedAt': null,
    });
    await _storage.write(key: _deviceIdKey, value: newRef.id);
  }

  /// User-initiated removal of a device row.
  Future<void> revokeOwnDevice(String deviceId) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('profiles')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .update({'revokedAt': FieldValue.serverTimestamp()});
  }
}

class _DeviceLimitException implements Exception {
  final int max;
  _DeviceLimitException(this.max);
  @override
  String toString() =>
      'Device limit reached ($max). Remove one in Settings → Premium → Devices.';
}
