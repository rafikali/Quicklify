import 'dart:developer' as dev;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import '../../core/utils/file_utils.dart';

class DownloadService {
  static const String _tag = 'DownloadService';

  /// Callback: 1=running, 2=complete, 3=failed, 4=paused, 5=cancelled
  static Function(String id, int status, int progress)? onProgressUpdate;

  static final Map<String, CancelToken> _cancelTokens = {};
  static final Set<String> _pausedTasks = {};

  /// Stores context needed to resume a paused download.
  static final Map<String, _DownloadInfo> _downloadInfos = {};

  static const _uuid = Uuid();
  static const _muxerChannel = MethodChannel('com.example.quicklify/media_muxer');

  static Future<void> initialize() async {
    await NotificationService.initialize();
    dev.log('DownloadService initialized (dio-based)', name: _tag);
  }

  // ── Enqueue methods ───────────────────────────────────────────────

  static Future<String?> enqueueDownload({
    required String url,
    required String filename,
  }) async {
    dev.log('--- ENQUEUE DOWNLOAD ---', name: _tag);
    dev.log('Download URL: $url', name: _tag);
    dev.log('Filename: $filename', name: _tag);

    try {
      final saveDir = await StorageService.getDownloadDirectory();
      final sanitizedName = FileUtils.sanitizeFilename(filename);
      final savePath = '$saveDir/$sanitizedName';
      final taskId = _uuid.v4();
      final cancelToken = CancelToken();
      _cancelTokens[taskId] = cancelToken;

      // Store info for resume
      _downloadInfos[taskId] = _DownloadInfo(
        url: url,
        savePath: savePath,
        displayName: sanitizedName,
      );

      _downloadFile(taskId, url, savePath, sanitizedName, cancelToken);

      dev.log('Enqueued with taskId: $taskId', name: _tag);
      return taskId;
    } catch (e, stackTrace) {
      dev.log('ERROR enqueuing download: $e', name: _tag);
      dev.log('Stack trace: $stackTrace', name: _tag);
      return null;
    }
  }

  static Future<String?> enqueueMergeDownload({
    required String videoUrl,
    required String audioUrl,
    required String filename,
  }) async {
    dev.log('--- ENQUEUE MERGE DOWNLOAD ---', name: _tag);

    try {
      final saveDir = await StorageService.getDownloadDirectory();
      final sanitizedName = FileUtils.sanitizeFilename(filename);
      final savePath = '$saveDir/$sanitizedName';
      final taskId = _uuid.v4();
      final cancelToken = CancelToken();
      _cancelTokens[taskId] = cancelToken;

      _downloadInfos[taskId] = _DownloadInfo(
        url: videoUrl,
        audioUrl: audioUrl,
        savePath: savePath,
        displayName: sanitizedName,
        isMerge: true,
      );

      _downloadAndMerge(taskId, videoUrl, audioUrl, savePath, sanitizedName, cancelToken);

      dev.log('Enqueued merge download with taskId: $taskId', name: _tag);
      return taskId;
    } catch (e, stackTrace) {
      dev.log('ERROR enqueuing merge download: $e', name: _tag);
      dev.log('Stack trace: $stackTrace', name: _tag);
      return null;
    }
  }

  // ── Single-file download ──────────────────────────────────────────

  static Future<void> _downloadFile(
    String taskId,
    String url,
    String savePath,
    String displayName,
    CancelToken cancelToken, {
    int startByte = 0,
  }) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 30),
    ));

    try {
      await Future.delayed(Duration.zero);

      onProgressUpdate?.call(taskId, 1, 0);
      NotificationService.showProgress(taskId: taskId, filename: displayName, progress: 0);

      final headers = <String, dynamic>{
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      };

      // Support resuming from a byte offset
      if (startByte > 0) {
        headers['Range'] = 'bytes=$startByte-';
        dev.log('Resuming from byte $startByte', name: _tag);
      }

      await dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        deleteOnError: false, // Keep partial file for resume
        onReceiveProgress: (received, total) {
          final totalWithOffset = total > 0 ? total + startByte : -1;
          final receivedWithOffset = received + startByte;
          final progress = totalWithOffset > 0
              ? ((receivedWithOffset / totalWithOffset) * 100).toInt()
              : 0;
          onProgressUpdate?.call(taskId, 1, progress);
          NotificationService.showProgress(
            taskId: taskId,
            filename: displayName,
            progress: progress,
          );
        },
        options: Options(
          headers: headers,
          // Append when resuming, overwrite when starting fresh
          extra: startByte > 0 ? {'receiveDataWhenStatusError': true} : null,
        ),
      );

      _cancelTokens.remove(taskId);
      _downloadInfos.remove(taskId);

      // Verify file
      final file = File(savePath);
      final fileSize = await file.length();
      dev.log('Downloaded file size: $fileSize bytes', name: _tag);

      if (fileSize < 1024) {
        dev.log('ERROR: File too small ($fileSize bytes)', name: _tag);
        try {
          final content = await file.readAsString();
          dev.log('File content: $content', name: _tag);
        } catch (_) {}
        await file.delete();
        onProgressUpdate?.call(taskId, 3, 0);
        NotificationService.showFailed(taskId: taskId, filename: displayName);
        return;
      }

      onProgressUpdate?.call(taskId, 2, 100);
      await StorageService.scanFile(savePath);
      NotificationService.showComplete(taskId: taskId, filename: displayName);
      dev.log('Download complete: $savePath ($fileSize bytes)', name: _tag);
    } on DioException catch (e) {
      _cancelTokens.remove(taskId);
      if (CancelToken.isCancel(e)) {
        if (_pausedTasks.contains(taskId)) {
          // Paused — keep partial file, report paused status
          _pausedTasks.remove(taskId);
          final partialSize = await _getFileSize(savePath);
          final info = _downloadInfos[taskId];
          if (info != null) {
            info.resumeFromByte = partialSize;
          }
          dev.log('Download paused: $taskId (${partialSize} bytes downloaded)', name: _tag);
          // Don't reset progress — keep current progress value
          onProgressUpdate?.call(taskId, 4, -1); // -1 = keep current progress
          NotificationService.cancel(taskId);
        } else {
          // Cancelled — clean up
          dev.log('Download cancelled: $taskId', name: _tag);
          _downloadInfos.remove(taskId);
          _deleteFile(savePath);
          onProgressUpdate?.call(taskId, 5, 0);
          NotificationService.cancel(taskId);
        }
      } else {
        dev.log('Download error: ${e.message}', name: _tag);
        _downloadInfos.remove(taskId);
        _deleteFile(savePath);
        onProgressUpdate?.call(taskId, 3, 0);
        NotificationService.showFailed(taskId: taskId, filename: displayName);
      }
    } catch (e) {
      _cancelTokens.remove(taskId);
      _downloadInfos.remove(taskId);
      dev.log('Download error: $e', name: _tag);
      _deleteFile(savePath);
      onProgressUpdate?.call(taskId, 3, 0);
      NotificationService.showFailed(taskId: taskId, filename: displayName);
    }
  }

  // ── Video + Audio merge download ──────────────────────────────────

  static Future<void> _downloadAndMerge(
    String taskId,
    String videoUrl,
    String audioUrl,
    String savePath,
    String displayName,
    CancelToken cancelToken,
  ) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 30),
    ));
    final downloadHeaders = Options(
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
    );

    final tempDir = await getTemporaryDirectory();
    final videoTmp = '${tempDir.path}/ql_video_$taskId.mp4';
    final audioTmp = '${tempDir.path}/ql_audio_$taskId.m4a';

    try {
      await Future.delayed(Duration.zero);
      onProgressUpdate?.call(taskId, 1, 0);
      NotificationService.showProgress(taskId: taskId, filename: displayName, progress: 0);

      dev.log('Downloading video stream...', name: _tag);
      await dio.download(
        videoUrl,
        videoTmp,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          final pct = total > 0 ? ((received / total) * 60).toInt() : 0;
          onProgressUpdate?.call(taskId, 1, pct);
          NotificationService.showProgress(taskId: taskId, filename: displayName, progress: pct);
        },
        options: downloadHeaders,
      );
      dev.log('Video stream downloaded: ${await File(videoTmp).length()} bytes', name: _tag);

      dev.log('Downloading audio stream...', name: _tag);
      await dio.download(
        audioUrl,
        audioTmp,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          final pct = total > 0 ? (60 + (received / total) * 20).toInt() : 60;
          onProgressUpdate?.call(taskId, 1, pct);
          NotificationService.showProgress(taskId: taskId, filename: displayName, progress: pct);
        },
        options: downloadHeaders,
      );
      dev.log('Audio stream downloaded: ${await File(audioTmp).length()} bytes', name: _tag);

      final videoSize = await File(videoTmp).length();
      final audioSize = await File(audioTmp).length();
      if (videoSize < 1024 || audioSize < 512) {
        dev.log('ERROR: Streams too small (video=$videoSize, audio=$audioSize)', name: _tag);
        _cleanupTempFiles([videoTmp, audioTmp]);
        onProgressUpdate?.call(taskId, 3, 0);
        NotificationService.showFailed(taskId: taskId, filename: displayName);
        return;
      }

      dev.log('Merging video + audio with MediaMuxer...', name: _tag);
      onProgressUpdate?.call(taskId, 1, 85);
      NotificationService.showProgress(taskId: taskId, filename: displayName, progress: 85);

      try {
        await _muxerChannel.invokeMethod('merge', {
          'videoPath': videoTmp,
          'audioPath': audioTmp,
          'outputPath': savePath,
        });
      } catch (e) {
        dev.log('MediaMuxer merge FAILED: $e', name: _tag);
        _cleanupTempFiles([videoTmp, audioTmp, savePath]);
        onProgressUpdate?.call(taskId, 3, 0);
        NotificationService.showFailed(taskId: taskId, filename: displayName);
        return;
      }

      dev.log('Merge succeeded', name: _tag);
      _cleanupTempFiles([videoTmp, audioTmp]);

      final mergedSize = await File(savePath).length();
      if (mergedSize < 1024) {
        dev.log('ERROR: Merged file too small ($mergedSize bytes)', name: _tag);
        await File(savePath).delete();
        onProgressUpdate?.call(taskId, 3, 0);
        NotificationService.showFailed(taskId: taskId, filename: displayName);
        return;
      }

      _cancelTokens.remove(taskId);
      _downloadInfos.remove(taskId);
      onProgressUpdate?.call(taskId, 2, 100);
      await StorageService.scanFile(savePath);
      NotificationService.showComplete(taskId: taskId, filename: displayName);
      dev.log('Merge download complete: $savePath ($mergedSize bytes)', name: _tag);
    } on DioException catch (e) {
      _cancelTokens.remove(taskId);
      _cleanupTempFiles([videoTmp, audioTmp]);
      if (CancelToken.isCancel(e)) {
        if (_pausedTasks.contains(taskId)) {
          _pausedTasks.remove(taskId);
          dev.log('Merge download paused: $taskId', name: _tag);
          onProgressUpdate?.call(taskId, 4, -1);
          NotificationService.cancel(taskId);
        } else {
          _downloadInfos.remove(taskId);
          dev.log('Merge download cancelled: $taskId', name: _tag);
          onProgressUpdate?.call(taskId, 5, 0);
          NotificationService.cancel(taskId);
        }
      } else {
        _downloadInfos.remove(taskId);
        dev.log('Download error: ${e.message}', name: _tag);
        onProgressUpdate?.call(taskId, 3, 0);
        NotificationService.showFailed(taskId: taskId, filename: displayName);
      }
    } catch (e) {
      _cancelTokens.remove(taskId);
      _downloadInfos.remove(taskId);
      _cleanupTempFiles([videoTmp, audioTmp]);
      dev.log('Merge download error: $e', name: _tag);
      onProgressUpdate?.call(taskId, 3, 0);
      NotificationService.showFailed(taskId: taskId, filename: displayName);
    }
  }

  // ── Control methods ───────────────────────────────────────────────

  static Future<void> pause(String taskId) async {
    dev.log('Pausing download: $taskId', name: _tag);
    _pausedTasks.add(taskId);
    _cancelTokens[taskId]?.cancel('User paused');
    _cancelTokens.remove(taskId);
  }

  static Future<String?> resumeDownload(String taskId) async {
    dev.log('Resuming download: $taskId', name: _tag);
    final info = _downloadInfos[taskId];
    if (info == null) {
      dev.log('No download info found for taskId=$taskId, cannot resume', name: _tag);
      return null;
    }

    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    if (info.isMerge && info.audioUrl != null) {
      // For merge downloads, restart from scratch (can't partially resume merge)
      _downloadAndMerge(taskId, info.url, info.audioUrl!, info.savePath, info.displayName, cancelToken);
    } else {
      // For single-file downloads, resume from where we left off
      _downloadFile(taskId, info.url, info.savePath, info.displayName, cancelToken,
          startByte: info.resumeFromByte);
    }

    return taskId;
  }

  static Future<void> cancel(String taskId) async {
    dev.log('Cancelling download: $taskId', name: _tag);
    _pausedTasks.remove(taskId);
    _cancelTokens[taskId]?.cancel('User cancelled');
    _cancelTokens.remove(taskId);

    // If download was paused (no active cancel token), handle cleanup manually
    final info = _downloadInfos[taskId];
    if (info != null) {
      _deleteFile(info.savePath);
      _downloadInfos.remove(taskId);
      onProgressUpdate?.call(taskId, 5, 0);
      NotificationService.cancel(taskId);
    }
  }

  static Future<void> remove(String taskId) async {
    await cancel(taskId);
  }

  // ── Helpers ───────────────────────────────────────────────────────

  static void _cleanupTempFiles(List<String> paths) {
    for (final path in paths) {
      _deleteFile(path);
    }
  }

  static void _deleteFile(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  static Future<int> _getFileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) return await file.length();
    } catch (_) {}
    return 0;
  }
}

/// Internal context for a running/paused download, needed for resume.
class _DownloadInfo {
  final String url;
  final String? audioUrl;
  final String savePath;
  final String displayName;
  final bool isMerge;
  int resumeFromByte;

  _DownloadInfo({
    required this.url,
    this.audioUrl,
    required this.savePath,
    required this.displayName,
    this.isMerge = false,
    this.resumeFromByte = 0,
  });
}
