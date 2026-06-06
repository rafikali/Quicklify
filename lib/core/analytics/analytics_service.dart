/// App-wide analytics. Hybrid backend:
///   - Firebase Analytics (GA4) — every event. Truly free, unlimited.
///   - Firestore activity log — only events flagged `important`. Lives at
///     `profiles/{uid}/activity/` for signed-in users so admins can pull
///     up a per-user timeline. For signed-out users, mirrored to
///     `anonymous_activity/{deviceFingerprint}/events/` so we still get
///     visibility on pre-login behavior.
///
/// All sends are fire-and-forget. Failures (network, Firestore unavailable)
/// log to dev.log and never throw to call sites.
library;

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../services/auth_service.dart';
import '../services/device_fingerprint_service.dart';
import 'analytics_events.dart';

class AnalyticsService with WidgetsBindingObserver {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  static const _tag = 'AnalyticsService';

  final _ga = FirebaseAnalytics.instance;
  final _db = FirebaseFirestore.instance;

  /// Generated on each app launch — lets you scope a single session in GA4
  /// and reconstruct it in the Firestore activity log.
  final String sessionId = const Uuid().v4();

  String? _appVersion;
  String? _deviceFingerprint;
  bool _ready = false;

  Future<void> initialize() async {
    try {
      // Disable in debug mode so test runs don't pollute prod analytics.
      // Set to true on a per-build basis if you want to verify wiring.
      await _ga.setAnalyticsCollectionEnabled(!kDebugMode);

      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;

      // Lazy: device fingerprint fetch is sometimes slow; don't block init.
      unawaited(_loadFingerprint());

      WidgetsBinding.instance.addObserver(this);
      _ready = true;
      logEvent(AnalyticsEvent.appOpen);
    } catch (e, st) {
      dev.log('init failed: $e\n$st', name: _tag);
    }
  }

  Future<void> _loadFingerprint() async {
    try {
      _deviceFingerprint = await DeviceFingerprintService.compute();
    } catch (e) {
      dev.log('fingerprint load failed: $e', name: _tag);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        logEvent(AnalyticsEvent.appResume);
        break;
      case AppLifecycleState.paused:
        logEvent(AnalyticsEvent.appBackground);
        break;
      default:
        break;
    }
  }

  // ── Public surface ──────────────────────────────────────────────────

  void logScreen(String screenName, {String? previousRoute}) {
    if (!_ready) return;
    final params = <String, Object>{
      AnalyticsParam.screen: screenName,
      AnalyticsParam.sessionId: sessionId,
      // ignore: use_null_aware_elements
      if (previousRoute != null) AnalyticsParam.previousRoute: previousRoute,
    };
    // GA4 has a first-class screen-view API.
    unawaited(_ga.logScreenView(screenName: screenName).catchError(
        (e) => dev.log('logScreenView failed: $e', name: _tag)));
    // Also log as a plain event so it shows up in custom funnel reports.
    unawaited(_ga
        .logEvent(name: 'screen_view_custom', parameters: params)
        .catchError((e) => dev.log('logEvent failed: $e', name: _tag)));
  }

  void logEvent(AnalyticsEvent event, {Map<String, Object>? params}) {
    if (!_ready) return;
    final merged = <String, Object>{
      AnalyticsParam.sessionId: sessionId,
      // ignore: use_null_aware_elements
      if (_appVersion != null) 'app_version': _appVersion!,
      'platform_os': Platform.operatingSystem,
      ...?params,
    };

    unawaited(_ga
        .logEvent(name: event.name, parameters: merged)
        .catchError((e) => dev.log('logEvent failed: $e', name: _tag)));

    if (event.important) {
      unawaited(_writeActivityLog(event, merged));
    }
  }

  /// Convenience for "this thing went wrong" — flagged as important so it
  /// always lands in the Firestore activity log too.
  void logError(String label,
      {String? error, Map<String, Object>? extra}) {
    final params = <String, Object>{
      AnalyticsParam.reason: label,
      // ignore: use_null_aware_elements
      if (error != null) AnalyticsParam.error: error,
      ...?extra,
    };
    logEvent(AnalyticsEvent.errorCaught, params: params);
  }

  /// Called by AuthService on sign-in/out so GA4 can correlate sessions
  /// to a user id (without sending PII).
  Future<void> setUserId(String? uid) async {
    if (!_ready) return;
    try {
      await _ga.setUserId(id: uid);
    } catch (e) {
      dev.log('setUserId failed: $e', name: _tag);
    }
  }

  /// Called by [AuthService] on successful sign-in. Copies the events
  /// recorded for this device's fingerprint under `anonymous_activity/`
  /// into the user's `profiles/{uid}/activity/` so their timeline is
  /// continuous across the sign-in boundary. Anonymous source events are
  /// preserved (not deleted) so the device-level log stays intact for
  /// future signed-out sessions on the same device.
  ///
  /// Capped at 500 events (Firestore batch limit). For typical install
  /// histories this is more than enough; very old events older than the
  /// cap simply don't merge — they remain visible in the admin's
  /// `/devices/{fp}` view.
  Future<void> mergeAnonymousActivity(String uid) async {
    try {
      final fp = _deviceFingerprint ??
          await DeviceFingerprintService.compute();
      if (fp.isEmpty) return;

      final snap = await _db
          .collection('anonymous_activity')
          .doc(fp)
          .collection('events')
          .orderBy('timestamp')
          .limit(500)
          .get();
      if (snap.docs.isEmpty) return;

      final dest =
          _db.collection('profiles').doc(uid).collection('activity');
      final batch = _db.batch();
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['mergedFromDevice'] = fp;
        data['mergedAt'] = FieldValue.serverTimestamp();
        batch.set(dest.doc(), data);
      }
      await batch.commit();
      dev.log('Merged ${snap.docs.length} anonymous events → profile $uid',
          name: _tag);
    } catch (e) {
      dev.log('merge failed: $e', name: _tag);
    }
  }

  // ── Firestore activity log ─────────────────────────────────────────

  Future<void> _writeActivityLog(
      AnalyticsEvent event, Map<String, Object> params) async {
    try {
      final uid = AuthService.currentUser?.uid;
      final doc = <String, dynamic>{
        'name': event.name,
        'params': params,
        'sessionId': sessionId,
        'appVersion': _appVersion,
        'platformOs': Platform.operatingSystem,
        'timestamp': FieldValue.serverTimestamp(),
      };
      if (uid != null) {
        await _db
            .collection('profiles')
            .doc(uid)
            .collection('activity')
            .add(doc);
      } else {
        final fp = _deviceFingerprint;
        if (fp == null) return; // skip — no identity yet
        await _db
            .collection('anonymous_activity')
            .doc(fp)
            .collection('events')
            .add(doc);
      }
    } catch (e) {
      dev.log('activity log write failed (${event.name}): $e', name: _tag);
    }
  }
}
