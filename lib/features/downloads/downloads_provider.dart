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

  /// Throttle DB writes: track last write time per taskId so we only persist
  /// progress every [_dbWriteInterval] instead of on every chunk tick.
  static const _dbWriteInterval = Duration(seconds: 2);
  final Map<String, DateTime> _lastDbWrite = {};
  /// Track last progress value written to DB to avoid redundant writes.
  final Map<String, int> _lastDbProgress = {};

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

  void _onDownloadProgress(String taskId, int status, int progress,
      {String? galleryPath, String? resolvedFilename}) {
    final index = _downloads.indexWhere((d) => d.taskId == taskId);
    if (index == -1) return;

    final item = _downloads[index];
    item.status = status;
    if (progress >= 0) {
      item.progress = progress;
    }

    // Always update UI immediately
    notifyListeners();

    // Throttle DB writes: always persist terminal states (complete/failed/
    // cancelled/paused) immediately, but for in-progress updates only write
    // every _dbWriteInterval to avoid SQLite lock contention.
    final isTerminal = status == 2 || status == 3 || status == 4 || status == 5;
    final now = DateTime.now();

    if (isTerminal) {
      // Terminal state — write immediately, clean up tracking
      DownloadDao.updateStatus(item.id, status, item.progress);
      if (status == 2) {
        if (galleryPath != null) {
          item.galleryPath = galleryPath;
          DownloadDao.updateGalleryPath(item.id, galleryPath);
        }
        if (resolvedFilename != null && resolvedFilename != item.filename) {
          item.filename = resolvedFilename;
          DownloadDao.updateFilename(item.id, resolvedFilename);
        }
      }
      _lastDbWrite.remove(taskId);
      _lastDbProgress.remove(taskId);
    } else {
      final lastWrite = _lastDbWrite[taskId];
      final lastProgress = _lastDbProgress[taskId] ?? -1;
      final elapsed = lastWrite == null
          ? _dbWriteInterval // force first write
          : now.difference(lastWrite);

      if (elapsed >= _dbWriteInterval && item.progress != lastProgress) {
        DownloadDao.updateStatus(item.id, status, item.progress);
        _lastDbWrite[taskId] = now;
        _lastDbProgress[taskId] = item.progress;
      }
    }
  }

  Future<void> enqueueDownload({
    required String sourceUrl,
    required String downloadUrl,
    required String filename,
    required String platform,
    required String quality,
    bool isYouTube = false,
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
        isYouTube: isYouTube,
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
    bool isYouTube = false,
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
        isYouTube: isYouTube,
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

  /// Insert an already-completed [DownloadItem] (e.g. produced by the
  /// caption editor) into the in-memory list and notify listeners.
  /// Caller is responsible for persisting to the DB.
  void addCompletedItem(DownloadItem item) {
    _downloads.insert(0, item);
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
