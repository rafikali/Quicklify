/// Streams the remote app gate from Firestore `config/app`.
///
/// On cold start: the last cached config (from SharedPreferences) is exposed
/// immediately so the gate can decide without waiting for the network. The
/// first Firestore snapshot then replaces it.
///
/// The actual blackout / force-update UI lives in [AppGate]; this service
/// only owns the data + caching.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/app_config.dart';

class AppConfigService {
  AppConfigService._();
  static final instance = AppConfigService._();

  static const _tag = 'AppConfigService';
  static const _docId = 'app';
  static const _cacheKey = 'app_config_cache_v1';

  final _db = FirebaseFirestore.instance;

  AppConfig _cached = AppConfig.fallback;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  final _changes = StreamController<AppConfig>.broadcast();

  Stream<AppConfig> get changes => _changes.stream;
  AppConfig get current => _cached;

  /// Hydrate the cache from disk and start listening to Firestore. Safe to
  /// call multiple times.
  Future<void> initialize() async {
    await _loadFromCache();
    _sub?.cancel();
    _sub = _db.collection('config').doc(_docId).snapshots().listen(
      (snap) {
        if (!snap.exists) {
          dev.log('config/app missing — keeping cached/fallback', name: _tag);
          return;
        }
        final cfg = AppConfig.fromFirestore(snap);
        _cached = cfg;
        _changes.add(cfg);
        unawaited(_persist(cfg));
      },
      onError: (e) {
        dev.log('config listener error: $e', name: _tag);
      },
    );
  }

  /// Force a one-shot fetch (used by [AppGate] on resume so the kill-switch
  /// takes effect immediately when the user comes back from background even
  /// if the realtime listener was paused).
  Future<AppConfig> fetchOnce() async {
    try {
      final snap = await _db.collection('config').doc(_docId).get();
      if (snap.exists) {
        final cfg = AppConfig.fromFirestore(snap);
        _cached = cfg;
        _changes.add(cfg);
        unawaited(_persist(cfg));
        return cfg;
      }
    } catch (e) {
      dev.log('fetchOnce failed: $e', name: _tag);
    }
    return _cached;
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _cached = AppConfig.fromCacheMap(json);
    } catch (e) {
      dev.log('cache load failed: $e', name: _tag);
    }
  }

  Future<void> _persist(AppConfig cfg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(cfg.toCacheMap()));
    } catch (e) {
      dev.log('cache persist failed: $e', name: _tag);
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _changes.close();
  }
}
