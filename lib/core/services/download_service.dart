import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import '../../core/utils/file_utils.dart';

class DownloadService {
  static const String _tag = 'DownloadService';

  /// Number of parallel chunks for large files
  static const int _maxChunks = 8;

  /// Number of parallel chunks for YouTube — enough to beat throttle without
  /// overwhelming the device (16 was causing DB lock & connection errors).
  static const int _ytMaxChunks = 8;

  /// Chunk size for YouTube downloads (3 MB) — small enough to finish before
  /// YouTube's per-connection throttle kicks in (~10 MB).
  static const int _ytChunkSize = 3 * 1024 * 1024;

  /// Minimum file size (in bytes) to use chunked downloading (2 MB)
  static const int _chunkThreshold = 2 * 1024 * 1024;

  /// Callback: 1=running, 2=complete, 3=failed, 4=paused, 5=cancelled
  /// [galleryPath] is set when status=2 (complete) with the gallery URI/path.
  static Function(String id, int status, int progress, {String? galleryPath})?
      onProgressUpdate;

  static final Map<String, CancelToken> _cancelTokens = {};
  static final Map<String, List<CancelToken>> _chunkCancelTokens = {};
  static final Set<String> _pausedTasks = {};

  /// Stores context needed to resume a paused download.
  static final Map<String, _DownloadInfo> _downloadInfos = {};

  static const _uuid = Uuid();
  static const _muxerChannel =
      MethodChannel('com.example.quicklify/media_muxer');

  /// Default browser User-Agent for non-YouTube downloads.
  static const _defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  /// Must exactly match youtube_explode_dart's YoutubeHttpClient.defaultHeaders
  /// so YouTube's CDN doesn't reject with 403. The library uses a desktop
  /// Chrome UA for downloading (NOT the Android app UA used for extraction).
  static const _youtubeHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/96.0.4664.18 Safari/537.36',
    'cookie': 'CONSENT=YES+cb',
    'accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,'
            'image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
    'accept-language': 'en-US,en;q=0.5',
  };

  static Dio _createDio({bool isYouTube = false}) => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 30),
        headers: isYouTube
            ? _youtubeHeaders
            : {'User-Agent': _defaultUserAgent},
      ));

  /// Extract content-length from YouTube URL's `clen` query parameter.
  /// YouTube CDN rejects HEAD requests with 403, but embeds the size in the URL.
  static int? _extractClenFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final clen = uri.queryParameters['clen'];
      if (clen != null) return int.tryParse(clen);
    } catch (_) {}
    return null;
  }

  static Future<void> initialize() async {
    await NotificationService.initialize();
    dev.log('DownloadService initialized (chunked parallel download)',
        name: _tag);
  }

  // ── Enqueue methods ───────────────────────────────────────────────

  static Future<String?> enqueueDownload({
    required String url,
    required String filename,
    bool isYouTube = false,
  }) async {
    dev.log('--- ENQUEUE DOWNLOAD ---', name: _tag);
    dev.log('Download URL: $url', name: _tag);
    dev.log('Filename: $filename', name: _tag);
    dev.log('YouTube mode: $isYouTube', name: _tag);

    try {
      final saveDir = await StorageService.getDownloadDirectory();
      final sanitizedName = FileUtils.sanitizeFilename(filename);
      final savePath = '$saveDir/$sanitizedName';
      final taskId = _uuid.v4();
      final cancelToken = CancelToken();
      _cancelTokens[taskId] = cancelToken;

      _downloadInfos[taskId] = _DownloadInfo(
        url: url,
        savePath: savePath,
        displayName: sanitizedName,
        isYouTube: isYouTube,
      );

      _downloadFileChunked(taskId, url, savePath, sanitizedName, cancelToken,
          isYouTube: isYouTube);

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
    bool isYouTube = false,
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
        isYouTube: isYouTube,
      );

      _downloadAndMerge(
          taskId, videoUrl, audioUrl, savePath, sanitizedName, cancelToken,
          isYouTube: isYouTube);

      dev.log('Enqueued merge download with taskId: $taskId', name: _tag);
      return taskId;
    } catch (e, stackTrace) {
      dev.log('ERROR enqueuing merge download: $e', name: _tag);
      dev.log('Stack trace: $stackTrace', name: _tag);
      return null;
    }
  }

  // ── Chunked parallel download ─────────────────────────────────────

  static Future<void> _downloadFileChunked(
    String taskId,
    String url,
    String savePath,
    String displayName,
    CancelToken cancelToken, {
    bool isYouTube = false,
  }) async {
    final dio = _createDio(isYouTube: isYouTube);

    try {
      await Future.delayed(Duration.zero);
      onProgressUpdate?.call(taskId, 1, 0);
      NotificationService.showProgress(
          taskId: taskId, filename: displayName, progress: 0);

      // 1. Get content length and check Range support
      int totalSize = -1;
      bool supportsRange = false;

      if (isYouTube) {
        // YouTube CDN rejects HEAD with 403 — extract size from `clen` param
        final clen = _extractClenFromUrl(url);
        if (clen != null && clen > 0) {
          totalSize = clen;
          supportsRange = true; // YouTube CDN always supports Range
          dev.log('YouTube clen=$totalSize, supportsRange=true', name: _tag);
        }
      } else {
        try {
          final headResponse = await dio.head<void>(
            url,
            cancelToken: cancelToken,
          );
          final contentLength =
              headResponse.headers.value('content-length');
          final acceptRanges = headResponse.headers.value('accept-ranges');
          if (contentLength != null) {
            totalSize = int.tryParse(contentLength) ?? -1;
          }
          supportsRange = acceptRanges == 'bytes' || totalSize > 0;
          dev.log(
              'HEAD: size=$totalSize, acceptRanges=$acceptRanges, supportsRange=$supportsRange',
              name: _tag);
        } catch (e) {
          dev.log('HEAD request failed, falling back to single download: $e',
              name: _tag);
        }
      }

      // 2. Decide: chunked parallel or single connection
      // YouTube always uses aggressive chunking if Range is supported
      if (supportsRange && (totalSize > _chunkThreshold || isYouTube)) {
        await _parallelChunkDownload(
            taskId, url, savePath, displayName, totalSize, cancelToken,
            isYouTube: isYouTube);
      } else {
        await _singleConnectionDownload(
            taskId, url, savePath, displayName, cancelToken,
            isYouTube: isYouTube);
      }
    } catch (e) {
      // Errors are handled inside the individual methods
      dev.log('Top-level download error: $e', name: _tag);
    }
  }

  /// Downloads a file using multiple parallel connections (chunks).
  ///
  /// When [isYouTube] is true, uses many small chunks (3 MB each) with a
  /// worker-pool of [_ytMaxChunks] concurrent connections. This defeats
  /// YouTube's per-connection throttle which kicks in after ~10 MB.
  static Future<void> _parallelChunkDownload(
    String taskId,
    String url,
    String savePath,
    String displayName,
    int totalSize,
    CancelToken masterCancel, {
    bool isYouTube = false,
    int progressOffset = 0,
    int progressRange = 100,
  }) async {
    // For YouTube: many small 3 MB chunks, N workers concurrently.
    // For others: split into _maxChunks equal pieces.
    final int numChunks;
    final int chunkSize;
    final int concurrency;

    if (isYouTube) {
      chunkSize = _ytChunkSize;
      numChunks = (totalSize / chunkSize).ceil();
      concurrency = _ytMaxChunks;
    } else {
      numChunks = min(_maxChunks, max(2, totalSize ~/ (512 * 1024)));
      chunkSize = totalSize ~/ numChunks;
      concurrency = numChunks; // all at once for non-YT
    }

    final tempDir = await getTemporaryDirectory();
    final chunkPaths = <String>[];
    final chunkProgress = List<int>.filled(numChunks, 0);
    final chunkTokens = <CancelToken>[];

    _chunkCancelTokens[taskId] = chunkTokens;

    dev.log(
        'Starting ${isYouTube ? "YT-optimized " : ""}$numChunks-chunk download '
        '(${_formatSize(chunkSize)}/chunk, $concurrency concurrent, total: ${_formatSize(totalSize)})',
        name: _tag);

    // Pre-compute chunk ranges and paths
    final chunkRanges = <List<int>>[];
    for (int i = 0; i < numChunks; i++) {
      final start = i * chunkSize;
      final end =
          (i == numChunks - 1) ? totalSize - 1 : (start + chunkSize - 1);
      final chunkPath = '${tempDir.path}/ql_chunk_${taskId}_$i.tmp';
      chunkPaths.add(chunkPath);
      chunkRanges.add([start, end]);
    }

    try {
      // Throttle progress callbacks — update UI at most every 250ms,
      // notifications at most every 1s. This prevents hundreds of callbacks/sec
      // from 8+ concurrent chunks overwhelming the system.
      int lastReportedPct = -1;
      var lastNotifTime = DateTime(2000);

      void reportProgress(int chunkIdx, int received) {
        chunkProgress[chunkIdx] = received;
        final totalReceived =
            chunkProgress.fold<int>(0, (sum, v) => sum + v);
        final pct = progressOffset +
            ((totalReceived / totalSize) * progressRange).toInt();
        if (pct != lastReportedPct) {
          lastReportedPct = pct;
          onProgressUpdate?.call(taskId, 1, pct);
          final now = DateTime.now();
          if (now.difference(lastNotifTime).inMilliseconds > 1000) {
            lastNotifTime = now;
            NotificationService.showProgress(
                taskId: taskId, filename: displayName, progress: pct);
          }
        }
      }

      if (isYouTube) {
        // Worker-pool: run up to `concurrency` chunks at a time
        int nextChunk = 0;

        Future<void> worker() async {
          while (true) {
            final idx = nextChunk++;
            if (idx >= numChunks) return;
            if (masterCancel.isCancelled) return;

            final chunkCancel = CancelToken();
            chunkTokens.add(chunkCancel);
            masterCancel.whenCancel.then((_) {
              if (!chunkCancel.isCancelled) {
                chunkCancel.cancel('Master cancelled');
              }
            });

            await _downloadChunk(
              url: url,
              savePath: chunkPaths[idx],
              start: chunkRanges[idx][0],
              end: chunkRanges[idx][1],
              cancelToken: chunkCancel,
              isYouTube: isYouTube,
              onProgress: (received) => reportProgress(idx, received),
            );
          }
        }

        // Launch `concurrency` workers
        await Future.wait(
            List.generate(min(concurrency, numChunks), (_) => worker()));
      } else {
        // Original: all chunks in parallel
        final futures = <Future<void>>[];
        for (int i = 0; i < numChunks; i++) {
          final chunkCancel = CancelToken();
          chunkTokens.add(chunkCancel);
          masterCancel.whenCancel.then((_) {
            if (!chunkCancel.isCancelled) {
              chunkCancel.cancel('Master cancelled');
            }
          });

          futures.add(_downloadChunk(
            url: url,
            savePath: chunkPaths[i],
            start: chunkRanges[i][0],
            end: chunkRanges[i][1],
            cancelToken: chunkCancel,
            isYouTube: isYouTube,
            onProgress: (received) => reportProgress(i, received),
          ));
        }
        await Future.wait(futures);
      }

      // Merge chunks into final file
      dev.log('All chunks downloaded, merging...', name: _tag);
      final outFile = File(savePath);
      final sink = outFile.openWrite();
      for (final chunkPath in chunkPaths) {
        final chunkFile = File(chunkPath);
        await sink.addStream(chunkFile.openRead());
      }
      await sink.flush();
      await sink.close();

      // Clean up chunk files
      for (final chunkPath in chunkPaths) {
        _deleteFile(chunkPath);
      }
      _chunkCancelTokens.remove(taskId);

      // Verify
      final fileSize = await outFile.length();
      dev.log('Merged file size: $fileSize bytes (expected: $totalSize)',
          name: _tag);

      if (fileSize < 1024) {
        dev.log('ERROR: File too small ($fileSize bytes)', name: _tag);
        await outFile.delete();
        _cleanup(taskId);
        onProgressUpdate?.call(taskId, 3, 0);
        NotificationService.showFailed(
            taskId: taskId, filename: displayName);
        return;
      }

      _cleanup(taskId);
      final galleryUri = await StorageService.saveToGallery(savePath, displayName);
      onProgressUpdate?.call(taskId, 2, 100, galleryPath: galleryUri);
      NotificationService.showComplete(
          taskId: taskId, filename: displayName);
      dev.log(
          'Chunked download complete & saved to gallery: $displayName (${_formatSize(fileSize)})',
          name: _tag);
    } on DioException catch (e) {
      _chunkCancelTokens.remove(taskId);
      for (final chunkPath in chunkPaths) {
        _deleteFile(chunkPath);
      }

      if (CancelToken.isCancel(e)) {
        _handleCancel(taskId, savePath, displayName);
      } else {
        _cleanup(taskId);
        dev.log('Chunk download error: ${e.message}', name: _tag);
        _deleteFile(savePath);
        onProgressUpdate?.call(taskId, 3, 0);
        NotificationService.showFailed(
            taskId: taskId, filename: displayName);
      }
    } catch (e) {
      _chunkCancelTokens.remove(taskId);
      for (final chunkPath in chunkPaths) {
        _deleteFile(chunkPath);
      }
      _cleanup(taskId);
      dev.log('Chunk download error: $e', name: _tag);
      _deleteFile(savePath);
      onProgressUpdate?.call(taskId, 3, 0);
      NotificationService.showFailed(
          taskId: taskId, filename: displayName);
    }
  }

  /// Max retries for a single chunk before giving up.
  static const int _chunkMaxRetries = 3;

  /// Downloads a single byte-range chunk with retry on transient errors.
  static Future<void> _downloadChunk({
    required String url,
    required String savePath,
    required int start,
    required int end,
    required CancelToken cancelToken,
    required void Function(int received) onProgress,
    bool isYouTube = false,
  }) async {
    for (int attempt = 0; attempt <= _chunkMaxRetries; attempt++) {
      if (cancelToken.isCancelled) return;

      try {
        final dio = _createDio(isYouTube: isYouTube);
        await dio.download(
          url,
          savePath,
          cancelToken: cancelToken,
          deleteOnError: true,
          onReceiveProgress: (received, _) => onProgress(received),
          options: Options(
            headers: {'Range': 'bytes=$start-$end'},
          ),
        );
        return; // success
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow; // user cancelled — don't retry

        if (attempt < _chunkMaxRetries) {
          final delay = Duration(seconds: 2 * (attempt + 1));
          dev.log(
            'Chunk $start-$end failed (attempt ${attempt + 1}/$_chunkMaxRetries): '
            '${e.message} — retrying in ${delay.inSeconds}s',
            name: _tag,
          );
          onProgress(0); // reset chunk progress for retry
          await Future.delayed(delay);
        } else {
          dev.log(
            'Chunk $start-$end failed after $_chunkMaxRetries retries: ${e.message}',
            name: _tag,
          );
          rethrow;
        }
      } catch (e) {
        if (attempt < _chunkMaxRetries) {
          final delay = Duration(seconds: 2 * (attempt + 1));
          dev.log(
            'Chunk $start-$end error (attempt ${attempt + 1}/$_chunkMaxRetries): '
            '$e — retrying in ${delay.inSeconds}s',
            name: _tag,
          );
          onProgress(0);
          await Future.delayed(delay);
        } else {
          dev.log(
            'Chunk $start-$end failed after $_chunkMaxRetries retries: $e',
            name: _tag,
          );
          rethrow;
        }
      }
    }
  }

  /// Fallback: single-connection download (for small files or no Range support).
  static Future<void> _singleConnectionDownload(
    String taskId,
    String url,
    String savePath,
    String displayName,
    CancelToken cancelToken, {
    int startByte = 0,
    bool isYouTube = false,
  }) async {
    final dio = _createDio(isYouTube: isYouTube);

    try {
      final headers = <String, dynamic>{};
      if (startByte > 0) {
        headers['Range'] = 'bytes=$startByte-';
        dev.log('Resuming from byte $startByte', name: _tag);
      }

      dev.log('Single-connection download', name: _tag);

      await dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        deleteOnError: false,
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
        options: Options(headers: headers),
      );

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
        _cleanup(taskId);
        onProgressUpdate?.call(taskId, 3, 0);
        NotificationService.showFailed(
            taskId: taskId, filename: displayName);
        return;
      }

      _cleanup(taskId);
      final galleryUri = await StorageService.saveToGallery(savePath, displayName);
      onProgressUpdate?.call(taskId, 2, 100, galleryPath: galleryUri);
      NotificationService.showComplete(
          taskId: taskId, filename: displayName);
      dev.log(
          'Download complete & saved to gallery: $displayName ($fileSize bytes)',
          name: _tag);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _handleCancel(taskId, savePath, displayName);
      } else {
        _cleanup(taskId);
        dev.log('Download error: ${e.message}', name: _tag);
        _deleteFile(savePath);
        onProgressUpdate?.call(taskId, 3, 0);
        NotificationService.showFailed(
            taskId: taskId, filename: displayName);
      }
    } catch (e) {
      _cleanup(taskId);
      dev.log('Download error: $e', name: _tag);
      _deleteFile(savePath);
      onProgressUpdate?.call(taskId, 3, 0);
      NotificationService.showFailed(
          taskId: taskId, filename: displayName);
    }
  }

  // ── Video + Audio merge download ──────────────────────────────────

  static Future<void> _downloadAndMerge(
    String taskId,
    String videoUrl,
    String audioUrl,
    String savePath,
    String displayName,
    CancelToken cancelToken, {
    bool isYouTube = false,
  }) async {
    final dio = _createDio(isYouTube: isYouTube);
    final tempDir = await getTemporaryDirectory();
    final videoTmp = '${tempDir.path}/ql_video_$taskId.mp4';
    final audioTmp = '${tempDir.path}/ql_audio_$taskId.m4a';

    try {
      await Future.delayed(Duration.zero);
      onProgressUpdate?.call(taskId, 1, 0);
      NotificationService.showProgress(
          taskId: taskId, filename: displayName, progress: 0);

      dev.log(
          'Downloading video + audio streams in parallel${isYouTube ? " (YT-optimized)" : ""}...',
          name: _tag);

      // Probe both streams for size to decide chunked vs single
      int videoSize = -1;
      int audioSize = -1;
      bool videoSupportsRange = false;
      bool audioSupportsRange = false;

      if (isYouTube) {
        // YouTube CDN rejects HEAD with 403 — extract size from `clen` param
        final vClen = _extractClenFromUrl(videoUrl);
        final aClen = _extractClenFromUrl(audioUrl);
        if (vClen != null && vClen > 0) {
          videoSize = vClen;
          videoSupportsRange = true;
        }
        if (aClen != null && aClen > 0) {
          audioSize = aClen;
          audioSupportsRange = true;
        }
        dev.log(
            'YouTube clen — Video: ${_formatSize(videoSize)} | '
            'Audio: ${_formatSize(audioSize)}',
            name: _tag);
      } else {
        try {
          final results = await Future.wait([
            dio.head<void>(videoUrl, cancelToken: cancelToken),
            dio.head<void>(audioUrl, cancelToken: cancelToken),
          ]);
          final vLen = results[0].headers.value('content-length');
          final aLen = results[1].headers.value('content-length');
          if (vLen != null) videoSize = int.tryParse(vLen) ?? -1;
          if (aLen != null) audioSize = int.tryParse(aLen) ?? -1;
          videoSupportsRange =
              results[0].headers.value('accept-ranges') == 'bytes' ||
                  videoSize > 0;
          audioSupportsRange =
              results[1].headers.value('accept-ranges') == 'bytes' ||
                  audioSize > 0;
          dev.log(
              'Video: ${_formatSize(videoSize)}, range=$videoSupportsRange | '
              'Audio: ${_formatSize(audioSize)}, range=$audioSupportsRange',
              name: _tag);
        } catch (e) {
          dev.log('HEAD probes failed, falling back to single downloads: $e',
              name: _tag);
        }
      }

      // Use chunked download for each stream if possible.
      // Progress: video = 0-60%, audio = 60-85%, merge = 85-100%
      final useChunkedVideo = videoSupportsRange &&
          (videoSize > _chunkThreshold || isYouTube);
      final useChunkedAudio = audioSupportsRange &&
          (audioSize > _chunkThreshold || isYouTube);

      // Shared progress tracker — video and audio report independently but
      // we only ever send the combined value upward, never going backwards.
      int videoPct = 0;
      int audioPct = 0;
      int lastCombinedPct = 0;
      var lastNotifTime = DateTime(2000);

      void reportCombinedProgress() {
        final combined = videoPct + audioPct;
        if (combined <= lastCombinedPct) return; // never go backwards
        lastCombinedPct = combined;
        onProgressUpdate?.call(taskId, 1, combined);
        final now = DateTime.now();
        if (now.difference(lastNotifTime).inMilliseconds > 1000) {
          lastNotifTime = now;
          NotificationService.showProgress(
              taskId: taskId, filename: displayName, progress: combined);
        }
      }

      Future<void> downloadVideo() async {
        if (useChunkedVideo) {
          await _parallelChunkDownloadToFile(
            taskId: taskId,
            url: videoUrl,
            savePath: videoTmp,
            displayName: displayName,
            totalSize: videoSize,
            masterCancel: cancelToken,
            isYouTube: isYouTube,
            onProgressPercent: (pct) {
              videoPct = pct;
              reportCombinedProgress();
            },
            progressRange: 60,
          );
        } else {
          await dio.download(
            videoUrl,
            videoTmp,
            cancelToken: cancelToken,
            deleteOnError: true,
            onReceiveProgress: (received, total) {
              videoPct = total > 0 ? ((received / total) * 60).toInt() : 0;
              reportCombinedProgress();
            },
          );
        }
      }

      Future<void> downloadAudio() async {
        if (useChunkedAudio) {
          await _parallelChunkDownloadToFile(
            taskId: taskId,
            url: audioUrl,
            savePath: audioTmp,
            displayName: displayName,
            totalSize: audioSize,
            masterCancel: cancelToken,
            isYouTube: isYouTube,
            onProgressPercent: (pct) {
              audioPct = pct;
              reportCombinedProgress();
            },
            progressRange: 25,
          );
        } else {
          await dio.download(
            audioUrl,
            audioTmp,
            cancelToken: cancelToken,
            deleteOnError: true,
            onReceiveProgress: (received, total) {
              audioPct = total > 0 ? ((received / total) * 25).toInt() : 0;
              reportCombinedProgress();
            },
          );
        }
      }

      // Download video and audio in parallel
      await Future.wait([downloadVideo(), downloadAudio()]);

      final vSize = await File(videoTmp).length();
      final aSize = await File(audioTmp).length();
      dev.log('Video: ${_formatSize(vSize)}, Audio: ${_formatSize(aSize)}',
          name: _tag);

      if (vSize < 1024 || aSize < 512) {
        dev.log(
            'ERROR: Streams too small (video=$vSize, audio=$aSize)',
            name: _tag);
        _cleanupTempFiles([videoTmp, audioTmp]);
        onProgressUpdate?.call(taskId, 3, 0);
        NotificationService.showFailed(
            taskId: taskId, filename: displayName);
        return;
      }

      dev.log('Merging video + audio with MediaMuxer...', name: _tag);
      onProgressUpdate?.call(taskId, 1, 88);
      NotificationService.showProgress(
          taskId: taskId, filename: displayName, progress: 88);

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
        NotificationService.showFailed(
            taskId: taskId, filename: displayName);
        return;
      }

      dev.log('Merge succeeded', name: _tag);
      _cleanupTempFiles([videoTmp, audioTmp]);

      final mergedSize = await File(savePath).length();
      if (mergedSize < 1024) {
        dev.log('ERROR: Merged file too small ($mergedSize bytes)',
            name: _tag);
        await File(savePath).delete();
        onProgressUpdate?.call(taskId, 3, 0);
        NotificationService.showFailed(
            taskId: taskId, filename: displayName);
        return;
      }

      _cleanup(taskId);
      final galleryUri = await StorageService.saveToGallery(savePath, displayName);
      onProgressUpdate?.call(taskId, 2, 100, galleryPath: galleryUri);
      NotificationService.showComplete(
          taskId: taskId, filename: displayName);
      dev.log(
          'Merge download complete & saved to gallery: $displayName (${_formatSize(mergedSize)})',
          name: _tag);
    } on DioException catch (e) {
      _cleanupTempFiles([videoTmp, audioTmp]);
      if (CancelToken.isCancel(e)) {
        _handleCancel(taskId, savePath, displayName);
      } else {
        _cleanup(taskId);
        dev.log('Download error: ${e.message}', name: _tag);
        onProgressUpdate?.call(taskId, 3, 0);
        NotificationService.showFailed(
            taskId: taskId, filename: displayName);
      }
    } catch (e) {
      _cleanup(taskId);
      _cleanupTempFiles([videoTmp, audioTmp]);
      dev.log('Merge download error: $e', name: _tag);
      onProgressUpdate?.call(taskId, 3, 0);
      NotificationService.showFailed(
          taskId: taskId, filename: displayName);
    }
  }

  /// Chunked parallel download that writes to a file but does NOT save to
  /// gallery or fire completion callbacks. Used internally by _downloadAndMerge
  /// for each individual stream (video / audio).
  ///
  /// [onProgressPercent] — reports progress as 0..progressRange (caller combines).
  static Future<void> _parallelChunkDownloadToFile({
    required String taskId,
    required String url,
    required String savePath,
    required String displayName,
    required int totalSize,
    required CancelToken masterCancel,
    bool isYouTube = false,
    void Function(int pct)? onProgressPercent,
    int progressRange = 100,
  }) async {
    final int numChunks;
    final int chunkSize;
    final int concurrency;

    if (isYouTube) {
      chunkSize = _ytChunkSize;
      numChunks = (totalSize / chunkSize).ceil();
      concurrency = _ytMaxChunks;
    } else {
      numChunks = min(_maxChunks, max(2, totalSize ~/ (512 * 1024)));
      chunkSize = totalSize ~/ numChunks;
      concurrency = numChunks;
    }

    final tempDir = await getTemporaryDirectory();
    final chunkPaths = <String>[];
    final chunkProgress = List<int>.filled(numChunks, 0);

    for (int i = 0; i < numChunks; i++) {
      chunkPaths.add('${tempDir.path}/ql_mchunk_${taskId}_${savePath.hashCode}_$i.tmp');
    }

    final chunkRanges = <List<int>>[];
    for (int i = 0; i < numChunks; i++) {
      final start = i * chunkSize;
      final end =
          (i == numChunks - 1) ? totalSize - 1 : (start + chunkSize - 1);
      chunkRanges.add([start, end]);
    }

    dev.log(
        'Merge-stream chunked: $numChunks chunks, ${_formatSize(chunkSize)}/chunk, '
        '$concurrency concurrent for ${savePath.split('/').last}',
        name: _tag);

    // Report progress via callback (caller handles combining video+audio)
    int lastReportedPct = -1;

    void reportProgress(int chunkIdx, int received) {
      chunkProgress[chunkIdx] = received;
      final totalReceived =
          chunkProgress.fold<int>(0, (sum, v) => sum + v);
      final pct = ((totalReceived / totalSize) * progressRange).toInt();
      if (pct != lastReportedPct) {
        lastReportedPct = pct;
        onProgressPercent?.call(pct);
      }
    }

    if (isYouTube) {
      int nextChunk = 0;
      Future<void> worker() async {
        while (true) {
          final idx = nextChunk++;
          if (idx >= numChunks) return;
          if (masterCancel.isCancelled) return;
          final chunkCancel = CancelToken();
          masterCancel.whenCancel.then((_) {
            if (!chunkCancel.isCancelled) chunkCancel.cancel('Master cancelled');
          });
          await _downloadChunk(
            url: url,
            savePath: chunkPaths[idx],
            start: chunkRanges[idx][0],
            end: chunkRanges[idx][1],
            cancelToken: chunkCancel,
            isYouTube: isYouTube,
            onProgress: (received) => reportProgress(idx, received),
          );
        }
      }

      await Future.wait(
          List.generate(min(concurrency, numChunks), (_) => worker()));
    } else {
      final futures = <Future<void>>[];
      for (int i = 0; i < numChunks; i++) {
        final chunkCancel = CancelToken();
        masterCancel.whenCancel.then((_) {
          if (!chunkCancel.isCancelled) chunkCancel.cancel('Master cancelled');
        });
        futures.add(_downloadChunk(
          url: url,
          savePath: chunkPaths[i],
          start: chunkRanges[i][0],
          end: chunkRanges[i][1],
          cancelToken: chunkCancel,
          isYouTube: isYouTube,
          onProgress: (received) => reportProgress(i, received),
        ));
      }
      await Future.wait(futures);
    }

    // Merge chunk files into the target file
    final outFile = File(savePath);
    final sink = outFile.openWrite();
    for (final chunkPath in chunkPaths) {
      await sink.addStream(File(chunkPath).openRead());
    }
    await sink.flush();
    await sink.close();

    for (final chunkPath in chunkPaths) {
      _deleteFile(chunkPath);
    }
  }

  // ── Control methods ───────────────────────────────────────────────

  static Future<void> pause(String taskId) async {
    dev.log('Pausing download: $taskId', name: _tag);
    _pausedTasks.add(taskId);
    // Cancel all chunk tokens
    final chunks = _chunkCancelTokens[taskId];
    if (chunks != null) {
      for (final token in chunks) {
        if (!token.isCancelled) token.cancel('User paused');
      }
    }
    _cancelTokens[taskId]?.cancel('User paused');
    _cancelTokens.remove(taskId);
  }

  static Future<String?> resumeDownload(String taskId) async {
    dev.log('Resuming download: $taskId', name: _tag);
    final info = _downloadInfos[taskId];
    if (info == null) {
      dev.log('No download info found for taskId=$taskId, cannot resume',
          name: _tag);
      return null;
    }

    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    if (info.isMerge && info.audioUrl != null) {
      _downloadAndMerge(taskId, info.url, info.audioUrl!, info.savePath,
          info.displayName, cancelToken,
          isYouTube: info.isYouTube);
    } else {
      // Restart chunked download (chunks are cleaned up on pause)
      _downloadFileChunked(
          taskId, info.url, info.savePath, info.displayName, cancelToken,
          isYouTube: info.isYouTube);
    }

    return taskId;
  }

  static Future<void> cancel(String taskId) async {
    dev.log('Cancelling download: $taskId', name: _tag);
    _pausedTasks.remove(taskId);
    // Cancel all chunk tokens
    final chunks = _chunkCancelTokens[taskId];
    if (chunks != null) {
      for (final token in chunks) {
        if (!token.isCancelled) token.cancel('User cancelled');
      }
    }
    _cancelTokens[taskId]?.cancel('User cancelled');
    _cancelTokens.remove(taskId);

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

  static void _handleCancel(
      String taskId, String savePath, String displayName) {
    _cancelTokens.remove(taskId);
    if (_pausedTasks.contains(taskId)) {
      _pausedTasks.remove(taskId);
      dev.log('Download paused: $taskId', name: _tag);
      onProgressUpdate?.call(taskId, 4, -1);
      NotificationService.cancel(taskId);
    } else {
      _downloadInfos.remove(taskId);
      dev.log('Download cancelled: $taskId', name: _tag);
      _deleteFile(savePath);
      onProgressUpdate?.call(taskId, 5, 0);
      NotificationService.cancel(taskId);
    }
  }

  static void _cleanup(String taskId) {
    _cancelTokens.remove(taskId);
    _downloadInfos.remove(taskId);
    _chunkCancelTokens.remove(taskId);
  }

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

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Internal context for a running/paused download, needed for resume.
class _DownloadInfo {
  final String url;
  final String? audioUrl;
  final String savePath;
  final String displayName;
  final bool isMerge;
  final bool isYouTube;
  int resumeFromByte;

  _DownloadInfo({
    required this.url,
    this.audioUrl,
    required this.savePath,
    required this.displayName,
    this.isMerge = false,
    this.isYouTube = false,
    this.resumeFromByte = 0,
  });
}
