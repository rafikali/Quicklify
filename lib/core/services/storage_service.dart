import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';

class StorageService {
  static const String _tag = 'StorageService';
  static const _mediaChannel = MethodChannel('com.example.quicklify/media_scanner');
  static const _galleryChannel = MethodChannel('com.example.quicklify/gallery');

  StorageService._();

  /// Copy a `content://` URI to a local cache file using Android's
  /// ContentResolver. Returns the destination path on success, or null on
  /// failure. No-op on non-Android.
  static Future<String?> copyUriToFile(String uri, String destPath) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _galleryChannel.invokeMethod<String>(
        'copyUriToFile',
        {'uri': uri, 'destPath': destPath},
      );
      return result;
    } catch (e) {
      dev.log('copyUriToFile failed: $e', name: _tag);
      return null;
    }
  }

  /// Register a file with Android's MediaStore so it shows in file managers
  static Future<void> scanFile(String path) async {
    if (!Platform.isAndroid) return;
    try {
      await _mediaChannel.invokeMethod('scanFile', {'path': path});
      dev.log('Media scan complete: $path', name: _tag);
    } catch (e) {
      dev.log('Media scan failed: $e', name: _tag);
    }
  }

  /// Save a downloaded file to the phone's gallery (Videos/Music).
  /// On Android 10+, uses MediaStore API (scoped storage).
  /// On Android 9 and below, copies to public Movies/Music folder and scans.
  /// Returns the URI/path and the actual filename used (may differ from the
  /// requested one if a name collision was resolved with "(1)", "(2)", ...).
  static Future<GallerySaveResult?> saveToGallery(
      String filePath, String filename) async {
    if (!Platform.isAndroid) return null;

    try {
      final mimeType = _getMimeType(filename);
      dev.log('Saving to gallery: $filename (mime: $mimeType)', name: _tag);

      final result = await _galleryChannel.invokeMethod('saveToGallery', {
        'filePath': filePath,
        'filename': filename,
        'mimeType': mimeType,
      });

      if (result is Map) {
        final uri = result['uri'] as String?;
        final resolved = result['filename'] as String? ?? filename;
        dev.log('Saved to gallery: uri=$uri, filename=$resolved', name: _tag);
        return GallerySaveResult(uri: uri, filename: resolved);
      }
      dev.log('Saved to gallery (legacy): $result', name: _tag);
      return GallerySaveResult(uri: result as String?, filename: filename);
    } catch (e) {
      dev.log('Gallery save failed: $e — falling back to scan', name: _tag);
      // Fallback: just scan the file so it at least shows in file manager
      await scanFile(filePath);
      return null;
    }
  }

  /// Determine MIME type from filename extension.
  static String _getMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'ogg':
      case 'opus':
        return 'audio/ogg';
      case 'wav':
        return 'audio/wav';
      case 'flac':
        return 'audio/flac';
      case 'aac':
        return 'audio/aac';
      default:
        return 'video/mp4';
    }
  }

  static Future<bool> requestPermissions() async {
    dev.log('Requesting permissions... Platform: ${Platform.operatingSystem}', name: _tag);

    if (Platform.isAndroid) {
      // Request notification permission (needed for download notifications)
      final notification = await Permission.notification.request();
      dev.log('Notification permission: ${notification.name}', name: _tag);

      // Request storage permission — permission_handler handles
      // the OS version differences internally. On Android 13+
      // storage permission is auto-granted for app-specific dirs.
      final storage = await Permission.storage.request();
      dev.log('Storage permission: ${storage.name}', name: _tag);

      // If storage denied, try manageExternalStorage for Android 11+
      if (!storage.isGranted) {
        dev.log('Storage not granted, trying manageExternalStorage', name: _tag);
        final manage = await Permission.manageExternalStorage.request();
        dev.log('ManageExternalStorage permission: ${manage.name}', name: _tag);

        if (manage.isPermanentlyDenied) {
          dev.log('All storage permissions permanently denied', name: _tag);
        }
      }

      return true;
    }
    return true;
  }

  static Future<String> getDownloadDirectory() async {
    dev.log('Getting download directory...', name: _tag);

    if (Platform.isAndroid) {
      // Use app-specific directory as temp download location.
      // Files are moved to gallery via MediaStore after download completes.
      try {
        final appExtDir = await getExternalStorageDirectory();
        if (appExtDir != null) {
          final dir = Directory('${appExtDir.path}/${AppConstants.downloadFolder}');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          dev.log('Using temp download directory: ${dir.path}', name: _tag);
          return dir.path;
        }
      } catch (e) {
        dev.log('App-external directory failed: $e', name: _tag);
      }

      // Fallback: app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final lastResort = Directory('${appDir.path}/${AppConstants.downloadFolder}');
      if (!await lastResort.exists()) {
        await lastResort.create(recursive: true);
      }
      dev.log('Using app documents directory: ${lastResort.path}', name: _tag);
      return lastResort.path;
    }

    // Non-Android platforms
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${appDir.path}/${AppConstants.downloadFolder}');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    dev.log('Download directory: ${downloadDir.path}', name: _tag);
    return downloadDir.path;
  }
}

class GallerySaveResult {
  final String? uri;
  final String filename;

  const GallerySaveResult({required this.uri, required this.filename});
}
