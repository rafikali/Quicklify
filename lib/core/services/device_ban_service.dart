/// Per-device ban gate — works for users who never sign in.
///
/// Flow on launch:
///   1. Compute the stable device fingerprint (DeviceFingerprintService).
///   2. Read cached ban state from SharedPreferences → expose immediately.
///   3. Fetch `device_registry/{deviceId}` from Firestore; create the doc
///      if missing (heartbeat fields only — rules block ban fields from
///      the client). Subscribe to changes.
///   4. If `banned == true`, AppGate renders BlackoutScreen.
///
/// Re-fetched on AppLifecycleState.resumed so a fresh admin-side ban takes
/// effect the moment the user comes back.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'device_fingerprint_service.dart';

class DeviceBanService {
  DeviceBanService._();
  static final instance = DeviceBanService._();

  static const _tag = 'DeviceBanService';
  static const _cacheKey = 'device_ban_cache_v1';
  static const _defaultReason =
      'This device has been blocked from using Quicklify.';

  final _db = FirebaseFirestore.instance;

  String? _deviceId;
  bool _isBanned = false;
  String? _reason;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;
  bool get isBanned => _isBanned;
  String get banReason => _reason ?? _defaultReason;
  String? get deviceId => _deviceId;

  Future<void> initialize() async {
    await _loadFromCache();
    try {
      _deviceId = await DeviceFingerprintService.compute();
    } catch (e) {
      dev.log('fingerprint failed: $e', name: _tag);
      return;
    }
    await _bootstrapDoc(_deviceId!);
    _listen(_deviceId!);
  }

  /// Used by AppGate on AppLifecycleState.resumed. Also re-writes the
  /// heartbeat so admin sees a fresh `lastSeenAt`.
  Future<void> fetchOnce() async {
    final id = _deviceId;
    if (id == null) return;
    try {
      final snap = await _db.collection('device_registry').doc(id).get();
      _apply(snap.data());
      unawaited(_writeHeartbeat(id));
    } catch (e) {
      dev.log('fetchOnce failed: $e', name: _tag);
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> _bootstrapDoc(String id) async {
    final ref = _db.collection('device_registry').doc(id);
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'firstSeenAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
          'lastVersion': await _appVersion(),
          'platform': _platform(),
          'deviceLabel': await DeviceFingerprintService.deviceLabel(),
          'lastUserUid': AuthService.currentUser?.uid,
          'banned': false,
        });
      } else {
        _apply(snap.data());
        unawaited(_writeHeartbeat(id));
      }
    } catch (e) {
      dev.log('bootstrap failed: $e', name: _tag);
    }
  }

  Future<void> _writeHeartbeat(String id) async {
    final ref = _db.collection('device_registry').doc(id);
    try {
      await ref.update({
        'lastSeenAt': FieldValue.serverTimestamp(),
        'lastVersion': await _appVersion(),
        'lastUserUid': AuthService.currentUser?.uid,
      });
    } catch (e) {
      // Update of non-existent doc, or rules rejection — fine to ignore.
      dev.log('heartbeat failed: $e', name: _tag);
    }
  }

  void _listen(String id) {
    _sub?.cancel();
    _sub = _db.collection('device_registry').doc(id).snapshots().listen(
      (snap) => _apply(snap.data()),
      onError: (e) {
        dev.log('listener error: $e', name: _tag);
      },
    );
  }

  void _apply(Map<String, dynamic>? data) {
    final nextBanned = (data?['banned'] as bool?) ?? false;
    final nextReason = data?['banReason'] as String?;
    if (nextBanned != _isBanned || nextReason != _reason) {
      _isBanned = nextBanned;
      _reason = nextReason;
      _changes.add(null);
      unawaited(_persist());
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _isBanned = (json['banned'] as bool?) ?? false;
      _reason = json['reason'] as String?;
    } catch (e) {
      dev.log('cache load failed: $e', name: _tag);
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({'banned': _isBanned, 'reason': _reason}),
      );
    } catch (e) {
      dev.log('cache persist failed: $e', name: _tag);
    }
  }

  static Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }

  static String _platform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _changes.close();
  }
}
