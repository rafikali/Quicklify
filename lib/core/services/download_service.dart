import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import '../../core/utils/file_utils.dart';

class DownloadService {
  static const String _tag = 'DownloadService';

  /// Callback signature matches our internal status codes:
  /// 1=running, 2=complete, 3=failed, 5=cancelled
  static Function(String id, int status, int progress)? onProgressUpdate;

  static final Map<String, CancelToken> _cancelTokens = {};
  static const _uuid = Uuid();

  static Future<void> initialize() async {
    await NotificationService.initialize();
    dev.log('DownloadService initialized (dio-based)', name: _tag);
  }

  static Future<String?> enqueueDownload({
    required String url,
    required String filename,
  }) async {
    dev.log('--- ENQUEUE DOWNLOAD ---', name: _tag);
    dev.log('Download URL: $url', name: _tag);
    dev.log('Filename: $filename', name: _tag);

    try {
      final saveDir = await StorageService.getDownloadDirectory();
      dev.log('Save directory: $saveDir', name: _tag);

      final sanitizedName = FileUtils.sanitizeFilename(filename);
      dev.log('Sanitized filename: $sanitizedName', name: _tag);

      final savePath = '$saveDir/$sanitizedName';
      final taskId = _uuid.v4();
      final cancelToken = CancelToken();
      _cancelTokens[taskId] = cancelToken;

      // Start download in background (fire-and-forget)
      _downloadFile(taskId, url, savePath, sanitizedName, cancelToken);

      dev.log('Enqueued with taskId: $taskId', name: _tag);
      return taskId;
    } catch (e, stackTrace) {
      dev.log('ERROR enqueuing download: $e', name: _tag);
      dev.log('Stack trace: $stackTrace', name: _tag);
      return null;
    }
  }

  static Future<void> _downloadFile(
    String taskId,
    String url,
    String savePath,
    String displayName,
    CancelToken cancelToken,
  ) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 30),
    ));

    try {
      // Wait a tick so the caller can register the taskId before we emit events
      await Future.delayed(Duration.zero);

      onProgressUpdate?.call(taskId, 1, 0); // running
      NotificationService.showProgress(
        taskId: taskId,
        filename: displayName,
        progress: 0,
      );

      await dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          final progress = total > 0 ? ((received / total) * 100).toInt() : 0;
          onProgressUpdate?.call(taskId, 1, progress);
          NotificationService.showProgress(
            taskId: taskId,
            filename: displayName,
            progress: progress,
          );
        },
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      _cancelTokens.remove(taskId);
      onProgressUpdate?.call(taskId, 2, 100); // complete

      // Make file visible in device file manager / gallery
      await StorageService.scanFile(savePath);

      NotificationService.showComplete(
        taskId: taskId,
        filename: displayName,
      );
      dev.log('Download complete: $savePath', name: _tag);
    } on DioException catch (e) {
      _cancelTokens.remove(taskId);
      if (CancelToken.isCancel(e)) {
        dev.log('Download cancelled: $taskId', name: _tag);
        onProgressUpdate?.call(taskId, 5, 0); // cancelled
        NotificationService.cancel(taskId);
      } else {
        dev.log('Download error: ${e.message}', name: _tag);
        onProgressUpdate?.call(taskId, 3, 0); // failed
        NotificationService.showFailed(
          taskId: taskId,
          filename: displayName,
        );
      }
    } catch (e) {
      _cancelTokens.remove(taskId);
      dev.log('Download error: $e', name: _tag);
      onProgressUpdate?.call(taskId, 3, 0); // failed
      NotificationService.showFailed(
        taskId: taskId,
        filename: displayName,
      );
    }
  }

  static Future<void> pause(String taskId) async {
    await cancel(taskId);
  }

  static Future<String?> resume(String taskId) async {
    return null;
  }

  static Future<void> cancel(String taskId) async {
    _cancelTokens[taskId]?.cancel('User cancelled');
    _cancelTokens.remove(taskId);
    NotificationService.cancel(taskId);
  }

  static Future<String?> retry(String taskId) async {
    return null;
  }

  static Future<void> remove(String taskId) async {
    await cancel(taskId);
  }
}
