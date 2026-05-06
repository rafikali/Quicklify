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
    // status is already our internal code: 1=running, 2=complete, 3=failed, 5=cancelled
    item.status = status;
    item.progress = progress;

    DownloadDao.updateStatus(item.id, status, progress);

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
        item.status = 1; // running
        await DownloadDao.updateTaskId(id, taskId);
        final index = _downloads.indexWhere((d) => d.id == id);
        if (index != -1) {
          _downloads[index] = item.copyWith(taskId: taskId, status: 1);
        }
        notifyListeners();
        dev.log('Download running with taskId: $taskId', name: _tag);
      } else {
        dev.log('WARNING: taskId is null - download may have failed to enqueue', name: _tag);
      }
    } catch (e, stackTrace) {
      dev.log('ERROR enqueuing download: $e', name: _tag);
      dev.log('Stack trace: $stackTrace', name: _tag);
    }
    dev.log('--- ENQUEUE END ---', name: _tag);
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
