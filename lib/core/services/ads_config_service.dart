/// Streams the remote ads config from Firestore `config/ads`.
///
/// Same pattern as [AppConfigService]: hydrate from disk cache on cold
/// start (so the first ad decision doesn't have to wait for the network),
/// then subscribe to Firestore so live admin tweaks take effect instantly.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/ads_config.dart';

class AdsConfigService {
  AdsConfigService._();
  static final instance = AdsConfigService._();

  static const _tag = 'AdsConfigService';
  static const _docId = 'ads';
  static const _cacheKey = 'ads_config_cache_v1';

  final _db = FirebaseFirestore.instance;

  AdsConfig _cached = AdsConfig.fallback;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  final _changes = StreamController<AdsConfig>.broadcast();

  Stream<AdsConfig> get changes => _changes.stream;
  AdsConfig get current => _cached;

  Future<void> initialize() async {
    await _loadFromCache();
    _sub?.cancel();
    _sub = _db.collection('config').doc(_docId).snapshots().listen(
      (snap) {
        if (!snap.exists) {
          dev.log('config/ads missing — keeping cached/fallback', name: _tag);
          return;
        }
        final cfg = AdsConfig.fromFirestore(snap);
        _cached = cfg;
        _changes.add(cfg);
        unawaited(_persist(cfg));
      },
      onError: (e) {
        dev.log('config listener error: $e', name: _tag);
      },
    );
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _cached = AdsConfig.fromCacheMap(json);
    } catch (e) {
      dev.log('cache load failed: $e', name: _tag);
    }
  }

  Future<void> _persist(AdsConfig cfg) async {
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
