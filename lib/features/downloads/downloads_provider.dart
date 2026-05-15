import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/download_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/local/download_dao.dart';
import 'models/download_item.dart';

const String _tag = 'DownloadsProvider';

class DownloadsProvider extends ChangeNotifier {
  List<DownloadItem> _downloads = [];
  final _uuid = const Uuid();

  List<DownloadItem> get allDownloads => _downloads;

  List<DownloadItem> get activeDownloads =>
      _downloads.where((d) => d.isActive).toList();

  List<DownloadItem> get completedDownloads =>
      _downloads.where((d) => d.isCompleted).toList();

  List<DownloadItem> get failedDownloads =>
      _downloads.where((d) => d.isFailed).toList();

  Future<void> initialize() async {
    dev.log('Initializing DownloadsProvider...', name: _tag);
    await StorageService.requestPermissions();
    dev.log('Permissions requested', name: _tag);
    _downloads = await DownloadDao.getAll();
    dev.log('Loaded ${_downloads.length} downloads from DB', name: _tag);

    // Listen to download progress from flutter_downloader
    DownloadService.onProgressUpdate = _onDownloadProgress;

    notifyListeners();
    dev.log('DownloadsProvider initialized', name: _tag);
  }

  void _onDownloadProgress(String taskId, int status, int progress) {
    dev.log('Progress update: taskId=$taskId, status=$status, progress=$progress%', name: _tag);
    final index = _downloads.indexWhere((d) => d.taskId == taskId);
    if (index == -1) {
      dev.log('WARNING: No download found for taskId=$taskId', name: _tag);
      return;
    }

    final item = _downloads[index];
    item.status = status;
    // progress == -1 means "keep current progress" (used when pausing)
    if (progress >= 0) {
      item.progress = progress;
    }

    DownloadDao.updateStatus(item.id, status, item.progress);

    notifyListeners();
  }

  Future<void> enqueueDownload({
    required String sourceUrl,
    required String downloadUrl,
    required String filename,
    required String platform,
    required String quality,
  }) async {
    dev.log('--- ENQUEUE START ---', name: _tag);
    dev.log('sourceUrl: $sourceUrl', name: _tag);
    dev.log('downloadUrl: $downloadUrl', name: _tag);
    dev.log('filename: $filename', name: _tag);
    dev.log('platform: $platform, quality: $quality', name: _tag);

    final id = _uuid.v4();

    // Ensure filename has an extension
    if (!filename.contains('.')) {
      filename = '$filename.mp4';
      dev.log('Added .mp4 extension: $filename', name: _tag);
    }

    final item = DownloadItem(
      id: id,
      sourceUrl: sourceUrl,
      downloadUrl: downloadUrl,
      filename: filename,
      platform: platform,
      quality: quality,
    );

    // Save to database first
    try {
      await DownloadDao.insert(item);
      dev.log('Saved to database with id: $id', name: _tag);
    } catch (e) {
      dev.log('ERROR saving to database: $e', name: _tag);
    }

    _downloads.insert(0, item);
    notifyListeners();

    // Start the actual download
    try {
      dev.log('Calling DownloadService.enqueueDownload...', name: _tag);
      final taskId = await DownloadService.enqueueDownload(
        url: downloadUrl,
        filename: filename,
      );
      dev.log('DownloadService returned taskId: $taskId', name: _tag);

      if (taskId != null) {
        // Update in-memory list BEFORE any async work so progress
        // callbacks can find this item by taskId immediately.
        final index = _downloads.indexWhere((d) => d.id == id);
        if (index != -1) {
          _downloads[index] = item.copyWith(taskId: taskId, status: 1);
        }
        notifyListeners();
        dev.log('Download running with taskId: $taskId', name: _tag);

        // Persist to DB (progress callbacks are safe now)
        await DownloadDao.updateTaskId(id, taskId);
      } else {
        dev.log('WARNING: taskId is null - download may have failed to enqueue', name: _tag);
      }
    } catch (e, stackTrace) {
      dev.log('ERROR enqueuing download: $e', name: _tag);
      dev.log('Stack trace: $stackTrace', name: _tag);
    }
    dev.log('--- ENQUEUE END ---', name: _tag);
  }

  /// Enqueue a YouTube merge download (video-only + audio → merged MP4).
  Future<void> enqueueMergeDownload({
    required String sourceUrl,
    required String videoUrl,
    required String audioUrl,
    required String filename,
    required String platform,
    required String quality,
  }) async {
    dev.log('--- ENQUEUE MERGE START ---', name: _tag);
    dev.log('sourceUrl: $sourceUrl', name: _tag);
    dev.log('videoUrl: $videoUrl', name: _tag);
    dev.log('audioUrl: $audioUrl', name: _tag);
    dev.log('filename: $filename', name: _tag);

    final id = _uuid.v4();

    if (!filename.contains('.')) {
      filename = '$filename.mp4';
    }

    final item = DownloadItem(
      id: id,
      sourceUrl: sourceUrl,
      downloadUrl: videoUrl, // store video URL as primary
      filename: filename,
      platform: platform,
      quality: quality,
    );

    try {
      await DownloadDao.insert(item);
      dev.log('Saved to database with id: $id', name: _tag);
    } catch (e) {
      dev.log('ERROR saving to database: $e', name: _tag);
    }

    _downloads.insert(0, item);
    notifyListeners();

    try {
      final taskId = await DownloadService.enqueueMergeDownload(
        videoUrl: videoUrl,
        audioUrl: audioUrl,
        filename: filename,
      );
      dev.log('DownloadService returned taskId: $taskId', name: _tag);

      if (taskId != null) {
        final index = _downloads.indexWhere((d) => d.id == id);
        if (index != -1) {
          _downloads[index] = item.copyWith(taskId: taskId, status: 1);
        }
        notifyListeners();
        dev.log('Merge download running with taskId: $taskId', name: _tag);

        await DownloadDao.updateTaskId(id, taskId);
      }
    } catch (e, stackTrace) {
      dev.log('ERROR enqueuing merge download: $e', name: _tag);
      dev.log('Stack trace: $stackTrace', name: _tag);
    }
    dev.log('--- ENQUEUE MERGE END ---', name: _tag);
  }

  Future<void> pauseDownload(DownloadItem item) async {
    if (item.taskId != null) {
      await DownloadService.pause(item.taskId!);
    }
  }

  Future<void> resumeDownload(DownloadItem item) async {
    // Re-enqueue from the stored download URL
    final newTaskId = await DownloadService.enqueueDownload(
      url: item.downloadUrl,
      filename: item.filename,
    );
    if (newTaskId != null) {
      final index = _downloads.indexWhere((d) => d.id == item.id);
      if (index != -1) {
        _downloads[index] = item.copyWith(taskId: newTaskId, status: 1);
        await DownloadDao.updateTaskId(item.id, newTaskId);
        notifyListeners();
      }
    }
  }

  Future<void> retryDownload(DownloadItem item) async {
    // Re-enqueue from the stored download URL
    final newTaskId = await DownloadService.enqueueDownload(
      url: item.downloadUrl,
      filename: item.filename,
    );
    if (newTaskId != null) {
      final index = _downloads.indexWhere((d) => d.id == item.id);
      if (index != -1) {
        _downloads[index] = item.copyWith(taskId: newTaskId, status: 1, progress: 0);
        await DownloadDao.updateTaskId(item.id, newTaskId);
        notifyListeners();
      }
    }
  }

  Future<void> cancelDownload(DownloadItem item) async {
    if (item.taskId != null) {
      await DownloadService.cancel(item.taskId!);
    }
  }

  Future<void> removeDownload(DownloadItem item) async {
    if (item.taskId != null) {
      await DownloadService.remove(item.taskId!);
    }
    await DownloadDao.delete(item.id);
    _downloads.removeWhere((d) => d.id == item.id);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    final completed = completedDownloads;
    for (final item in completed) {
      if (item.taskId != null) {
        await DownloadService.remove(item.taskId!);
      }
      await DownloadDao.delete(item.id);
    }
    _downloads.removeWhere((d) => d.isCompleted);
    notifyListeners();
  }
}
