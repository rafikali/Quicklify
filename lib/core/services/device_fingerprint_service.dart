/// Computes a stable device fingerprint used in PET device binding.
///
/// Primary inputs:
///   1. `Settings.Secure.ANDROID_ID` — OS-assigned, stable across reboots,
///      reinstalls, and Clear-Data on Android 8+. Scoped per signing key,
///      which is exactly the property we need. Retrieved via the native
///      `device` channel (device_info_plus does NOT expose this; its
///      `info.id` is `Build.ID`, a build identifier shared across many
///      devices — DO NOT use it for device identity).
///   2. APK signing cert hash — proxy via PackageInfo.buildSignature. Binds
///      the fingerprint to this signed APK so a re-signed APK can't
///      impersonate it.
///
/// Fallback inputs (used only when ANDROID_ID is null/empty — old/jailbroken
/// devices, iOS):
///   3. `install_uuid` — generated once on first run, stored in secure
///      storage. Survives most lifecycle events but is wiped on reinstall;
///      acceptable as a *fallback* since we can't do better without
///      ANDROID_ID. Never mixed in when ANDROID_ID is available.
///
/// Inputs are concatenated with '|' and SHA-256 hashed. The raw ANDROID_ID
/// never leaves the device.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

class DeviceFingerprintService {
  DeviceFingerprintService._();

  static const _deviceChannel =
      MethodChannel('com.example.quicklify/device');

  static final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _installUuidKey = 'qlf_install_uuid';

  static String? _cached;

  /// Returns the sha256 hex of the device fingerprint inputs. Cached for
  /// the lifetime of the process.
  static Future<String> compute() async {
    if (_cached != null) return _cached!;

    final androidId = await _androidId();
    final certHash = await _appSigningCertHash();

    final String concat;
    if (androidId != null && androidId.isNotEmpty) {
      // Stable path: ANDROID_ID is sufficient identity. Including
      // install_uuid here would make every reinstall look like a new
      // device — that is the bug we're fixing.
      concat = '$androidId|$certHash';
    } else {
      // Degraded path: no ANDROID_ID (very old / heavily modified ROMs,
      // iOS). Fall back to install_uuid which at least survives runtime
      // lifecycle, even if it doesn't survive uninstall.
      final installUuid = await _ensureInstallUuid();
      concat = '|$certHash|$installUuid';
    }

    _cached = sha256.convert(utf8.encode(concat)).toString();
    return _cached!;
  }

  /// Human-readable label used in admin panel / device list. Best-effort.
  static Future<String> deviceLabel() async {
    if (!Platform.isAndroid) return Platform.operatingSystem;
    final info = await DeviceInfoPlugin().androidInfo;
    return '${info.manufacturer} ${info.model} (Android ${info.version.release})';
  }

  // -------------------------------------------------------------------------

  /// Returns Settings.Secure.ANDROID_ID, or null if unavailable.
  /// Non-Android always returns null.
  static Future<String?> _androidId() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _deviceChannel.invokeMethod<String>('getAndroidId');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      // Native code not yet rebuilt (hot-restart on an old APK). Surface
      // as null so the fallback path runs instead of throwing.
      return null;
    }
  }

  static Future<String> _appSigningCertHash() async {
    final info = await PackageInfo.fromPlatform();
    // PackageInfo doesn't expose the signing cert; we use buildSignature
    // as a proxy. On Android this is the SHA-1 of the signing cert.
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
