import 'package:cloud_firestore/cloud_firestore.dart';

/// Remote-controlled app gate. Sourced from Firestore `config/app` and
/// fetched on every cold start + foreground resume. The values here decide
/// whether the app renders normally, shows a "blackout" screen, or shows a
/// blocking "update required" screen.
///
/// All version fields are dotted semver-ish strings like `1.4.0`. Comparison
/// is left-to-right numeric; missing components are treated as 0.
class AppConfig {
  /// Below this the user MUST update — full-screen, no dismiss.
  final String minRequiredVersion;

  /// Latest released version. Used for the soft "update available" banner
  /// (not yet wired, but stored so we don't migrate the doc later).
  final String latestVersion;

  /// HTTPS URL the "Download" button on the force-update screen opens.
  final String apkUrl;

  /// Soft kill-switch. When true, every user sees [blackoutMessage] and
  /// cannot interact with the app.
  final bool blackoutEnabled;

  /// Message shown on the blackout screen.
  final String blackoutMessage;

  /// Message shown on the force-update screen (above the Download button).
  final String updateMessage;

  const AppConfig({
    required this.minRequiredVersion,
    required this.latestVersion,
    required this.apkUrl,
    required this.blackoutEnabled,
    required this.blackoutMessage,
    required this.updateMessage,
  });

  /// Safe defaults — used when Firestore is unreachable on first launch.
  /// `minRequiredVersion: '0.0.0'` means nothing is forced; blackout off.
  static const fallback = AppConfig(
    minRequiredVersion: '0.0.0',
    latestVersion: '0.0.0',
    apkUrl: 'https://quicklify-murex.vercel.app/downloads/quicklify-latest.apk',
    blackoutEnabled: false,
    blackoutMessage: 'Quicklify is temporarily unavailable.',
    updateMessage: 'A new version of Quicklify is required. '
        'Please download the latest APK to continue.',
  );

  factory AppConfig.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final d = snap.data() ?? const {};
    return AppConfig(
      minRequiredVersion:
          (d['minRequiredVersion'] as String?) ?? fallback.minRequiredVersion,
      latestVersion: (d['latestVersion'] as String?) ?? fallback.latestVersion,
      apkUrl: (d['apkUrl'] as String?) ?? fallback.apkUrl,
      blackoutEnabled: (d['blackoutEnabled'] as bool?) ?? false,
      blackoutMessage:
          (d['blackoutMessage'] as String?) ?? fallback.blackoutMessage,
      updateMessage:
          (d['updateMessage'] as String?) ?? fallback.updateMessage,
    );
  }

  Map<String, dynamic> toCacheMap() => {
        'minRequiredVersion': minRequiredVersion,
        'latestVersion': latestVersion,
        'apkUrl': apkUrl,
        'blackoutEnabled': blackoutEnabled,
        'blackoutMessage': blackoutMessage,
        'updateMessage': updateMessage,
      };

  factory AppConfig.fromCacheMap(Map<String, dynamic> d) => AppConfig(
        minRequiredVersion:
            (d['minRequiredVersion'] as String?) ?? fallback.minRequiredVersion,
        latestVersion:
            (d['latestVersion'] as String?) ?? fallback.latestVersion,
        apkUrl: (d['apkUrl'] as String?) ?? fallback.apkUrl,
        blackoutEnabled: (d['blackoutEnabled'] as bool?) ?? false,
        blackoutMessage:
            (d['blackoutMessage'] as String?) ?? fallback.blackoutMessage,
        updateMessage:
            (d['updateMessage'] as String?) ?? fallback.updateMessage,
      );

  /// True when [current] is strictly less than [minRequiredVersion].
  /// Treats missing version components as 0 so `1.5` < `1.5.1`.
  bool requiresUpdate(String current) =>
      _compareVersions(current, minRequiredVersion) < 0;

  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final bParts = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final len = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = 0; i < len; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}
