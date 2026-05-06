import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';

class StorageService {
  static const String _tag = 'StorageService';
  static const _mediaChannel = MethodChannel('com.example.quicklify/media_scanner');

  StorageService._();

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
          // Don't block the app — we'll use app-specific directory as fallback
        }
      }

      return true; // Don't block — we'll fall back to app-specific dir if needed
    }
    return true;
  }

  static Future<String> getDownloadDirectory() async {
    dev.log('Getting download directory...', name: _tag);

    if (Platform.isAndroid) {
      // Try public Downloads directory first
      final publicDir = Directory('/storage/emulated/0/Download/${AppConstants.downloadFolder}');
      dev.log('Trying public directory: ${publicDir.path}', name: _tag);

      try {
        if (!await publicDir.exists()) {
          await publicDir.create(recursive: true);
        }
        // Test write access
        final testFile = File('${publicDir.path}/.quicklify_test');
        await testFile.writeAsString('test');
        await testFile.delete();
        dev.log('Public directory writable: ${publicDir.path}', name: _tag);
        return publicDir.path;
      } catch (e) {
        dev.log('Public directory not writable: $e', name: _tag);
      }

      // Fallback: app-specific external directory
      try {
        final appExtDir = await getExternalStorageDirectory();
        if (appExtDir != null) {
          final fallbackDir = Directory('${appExtDir.path}/${AppConstants.downloadFolder}');
          if (!await fallbackDir.exists()) {
            await fallbackDir.create(recursive: true);
          }
          dev.log('Using app-external directory: ${fallbackDir.path}', name: _tag);
          return fallbackDir.path;
        }
      } catch (e) {
        dev.log('App-external directory failed: $e', name: _tag);
      }

      // Last fallback: app documents directory
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
