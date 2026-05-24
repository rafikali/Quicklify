/// Computes a stable device fingerprint used in PET device binding.
///
/// Combines three inputs:
///   1. `android_id`             — OS-assigned, stable across reboots, per
///                                 signing-key on Android 8+.
///   2. APK signing cert hash    — same for any install of the same APK; here
///                                 to bind the fingerprint to "this particular
///                                 build" so a different signed APK can't reuse
///                                 the fingerprint.
///   3. install_uuid             — generated once on first run and stored in
///                                 secure storage; required to differentiate
///                                 the same device + same APK across reinstalls.
///
/// The three inputs are concatenated with '|' separators and SHA-256 hashed
/// before being sent to the server. The raw android_id never leaves the
/// device.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

class DeviceFingerprintService {
  DeviceFingerprintService._();

  static final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _installUuidKey = 'qlf_install_uuid';

  static String? _cached;

  /// Returns the sha256 hex of (android_id || cert_hash || install_uuid).
  /// Cached for the lifetime of the process.
  static Future<String> compute() async {
    if (_cached != null) return _cached!;

    final androidId = await _androidId();
    final certHash = await _appSigningCertHash();
    final installUuid = await _ensureInstallUuid();

    final concat = utf8.encode('$androidId|$certHash|$installUuid');
    _cached = sha256.convert(concat).toString();
    return _cached!;
  }

  /// Human-readable label used in admin panel / device list. Best-effort.
  static Future<String> deviceLabel() async {
    if (!Platform.isAndroid) return Platform.operatingSystem;
    final info = await DeviceInfoPlugin().androidInfo;
    return '${info.manufacturer} ${info.model} (Android ${info.version.release})';
  }

  // -------------------------------------------------------------------------

  static Future<String> _androidId() async {
    if (!Platform.isAndroid) return 'non-android';
    final info = await DeviceInfoPlugin().androidInfo;
    return info.id; // ANDROID_ID since Android 8 is per-app-signing-key.
  }

  static Future<String> _appSigningCertHash() async {
    final info = await PackageInfo.fromPlatform();
    // PackageInfo doesn't expose the signing cert; we use buildSignature as
    // a proxy. On Android this is the SHA-1 of the signing cert.
    return info.buildSignature;
  }

  static Future<String> _ensureInstallUuid() async {
    var existing = await _storage.read(key: _installUuidKey);
    if (existing != null && existing.isNotEmpty) return existing;
    existing = const Uuid().v4();
    await _storage.write(key: _installUuidKey, value: existing);
    return existing;
  }
}
