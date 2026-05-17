import 'dart:developer' as dev;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'piped_service.dart';
import 'yt_dlp_service.dart';

const String _tag = 'YouTubeService';

class YouTubeResult {
  final bool success;
  final String? url;
  /// For video+audio merge downloads (high quality), this holds the audio URL.
  final String? audioUrl;
  /// True when [url] is video-only and [audioUrl] is set — caller must merge.
  final bool needsMerge;
  final String? filename;
  final String? quality;
  final int? filesize;
  final String? error;

  const YouTubeResult({
    required this.success,
    this.url,
    this.audioUrl,
    this.needsMerge = false,
    this.filename,
    this.quality,
    this.filesize,
    this.error,
  });
}

class YouTubeService {
  /// Max retries when YouTube rate-limits us.
  static const int _maxRetries = 3;

  /// Prevents concurrent extractions from hammering YouTube.
  static bool _extracting = false;

  /// Extract a direct download URL for a YouTube video.
  ///
  /// Fallback chain:
  ///   1. On-device (youtube_explode_dart) with retry
  ///   2. yt-dlp API server (if configured)
  ///   3. Piped API (community instances)
  static Future<YouTubeResult> getDownloadUrl({
    required String url,
    required String quality,
    required String mode,
    required String audioFormat,
    String? ytDlpApiUrl,
    String? ytDlpApiKey,
  }) async {
    dev.log('--- YouTube extraction ---', name: _tag);
    dev.log('URL: $url', name: _tag);
    dev.log('Quality: $quality, Mode: $mode', name: _tag);

    // Prevent concurrent extractions — queue up behind the active one
    if (_extracting) {
      dev.log('Extraction already in progress, waiting...', name: _tag);
      while (_extracting) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    _extracting = true;

    try {
      // 1. Try yt-dlp API server first (if configured)
      if (ytDlpApiUrl != null && ytDlpApiUrl.isNotEmpty) {
        dev.log('Trying yt-dlp API first...', name: _tag);
        final apiResult = await YtDlpService.getDownloadUrl(
          baseUrl: ytDlpApiUrl,
          url: url,
          quality: quality,
          mode: mode,
          audioFormat: audioFormat,
          apiKey: ytDlpApiKey,
        );
        if (apiResult.success) return apiResult;
        dev.log('yt-dlp API failed: ${apiResult.error}', name: _tag);
      }

      // 2. Fall back to on-device extraction (youtube_explode)
      dev.log('Trying on-device extraction...', name: _tag);
      final result = await _extractWithRetry(url, quality, mode);
      if (result.success) return result;

      // 3. Fall back to Piped API
      dev.log('Trying Piped fallback...', name: _tag);
      final pipedResult = await _pipedFallback(url, quality, mode);
      if (pipedResult != null) return pipedResult;

      return result;
    } finally {
      _extracting = false;
    }
  }

  /// Try on-device extraction up to [_maxRetries] times with exponential backoff.
  static Future<YouTubeResult> _extractWithRetry(
    String url,
    String quality,
    String mode,
  ) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      if (attempt > 0) {
        final delay = Duration(seconds: 2 * attempt); // 2s, 4s, 6s
        dev.log(
            'Rate limited — retrying in ${delay.inSeconds}s (attempt ${attempt + 1}/${_maxRetries + 1})',
            name: _tag);
        await Future.delayed(delay);
      }

      final yt = YoutubeExplode();
      try {
        final video = await yt.videos.get(url);
        dev.log('Video: ${video.title} (${video.duration})', name: _tag);

        final manifest = await yt.videos.streamsClient.getManifest(video.id);

        final isAudio = mode == 'audio';
        final isMute = mode == 'mute';
        final targetHeight = int.tryParse(quality) ?? 1080;

        if (isAudio) {
          return _pickAudio(manifest, video.title);
        } else if (isMute) {
          return _pickVideoOnly(manifest, video.title, targetHeight);
        } else {
          return _pickMuxed(manifest, video.title, targetHeight);
        }
      } catch (e) {
        dev.log('Extraction attempt ${attempt + 1} failed: $e', name: _tag);

        final isRateLimit = e.toString().contains('RequestLimitExceeded') ||
            e.toString().contains('rate limit') ||
            e.toString().contains('429');

        if (!isRateLimit || attempt == _maxRetries) {
          // Non-rate-limit error or last attempt — give up
          String message = e.toString();
          if (message.contains('VideoUnplayable')) {
            message = 'This video is unavailable or region-restricted.';
          } else if (message.contains('VideoRequiresPurchase')) {
            message = 'This video requires purchase.';
          } else if (isRateLimit) {
            message = 'YouTube rate limited — trying fallback...';
          } else if (message.length > 100) {
            message = message.substring(0, 100);
          }
          return YouTubeResult(success: false, error: message);
        }
        // Rate limited — continue to next attempt
      } finally {
        yt.close();
      }
    }
    return const YouTubeResult(
        success: false, error: 'YouTube rate limited — trying fallback...');
  }

  /// Fallback: use Piped API when on-device extraction is rate-limited.
  /// Piped proxies through different servers so it bypasses our IP's rate limit.
  static Future<YouTubeResult?> _pipedFallback(
    String url,
    String quality,
    String mode,
  ) async {
    dev.log('Piped fallback for: $url', name: _tag);
    final piped = await PipedService.getStreams(url);
    if (piped == null) {
      dev.log('Piped fallback failed — all instances down', name: _tag);
      return null;
    }

    final isAudio = mode == 'audio';
    final isMute = mode == 'mute';
    final targetQuality = quality;

    if (isAudio) {
      final audio = PipedService.pickAudioStream(piped.audioStreams);
      if (audio == null) return null;
      final filename = '${piped.title}.m4a';
      dev.log('Piped fallback: audio ${audio.bitrate}bps', name: _tag);
      return YouTubeResult(
        success: true,
        url: audio.url,
        filename: filename,
        quality: '${audio.bitrate ~/ 1000}kbps',
      );
    }

    // Pick video stream
    final video = PipedService.pickVideoStream(
        piped.videoStreams, targetQuality);
    if (video == null) return null;

    if (video.videoOnly) {
      // Need merge — pick audio too
      final audio = PipedService.pickAudioStream(piped.audioStreams);
      if (audio != null && !isMute) {
        final filename = '${piped.title} (${video.quality}).mp4';
        dev.log(
            'Piped fallback: video ${video.quality} + audio (merge)',
            name: _tag);
        return YouTubeResult(
          success: true,
          url: video.url,
          audioUrl: audio.url,
          needsMerge: true,
          filename: filename,
          quality: video.quality,
        );
      }
      // Mute mode or no audio available
      final filename = '${piped.title} (${video.quality}).mp4';
      dev.log('Piped fallback: video-only ${video.quality}', name: _tag);
      return YouTubeResult(
        success: true,
        url: video.url,
        filename: filename,
        quality: video.quality,
      );
    } else {
      // Combined stream
      final filename = '${piped.title} (${video.quality}).mp4';
      dev.log('Piped fallback: combined ${video.quality}', name: _tag);
      return YouTubeResult(
        success: true,
        url: video.url,
        filename: filename,
        quality: video.quality,
      );
    }
  }

  /// Pick best stream(s) for video+audio at target quality.
  ///
  /// YouTube muxed streams cap at 720p. For higher quality we pick a
  /// video-only stream + the best audio stream and set [needsMerge] = true
  /// so the caller can use enqueueMergeDownload.
  static YouTubeResult _pickMuxed(
    StreamManifest manifest,
    String title,
    int targetHeight,
  ) {
    // Try video-only + audio for quality above 720p (or when muxed is empty)
    final videoOnly = manifest.videoOnly.toList();
    final audioOnly = manifest.audioOnly.toList();

    if (videoOnly.isNotEmpty && audioOnly.isNotEmpty && targetHeight > 720) {
      // Sort video by resolution descending
      videoOnly.sort((a, b) =>
          (b.videoResolution.height).compareTo(a.videoResolution.height));

      VideoOnlyStreamInfo? bestVideo;
      for (final stream in videoOnly) {
        if (stream.videoResolution.height <= targetHeight) {
          if (bestVideo == null || stream.container.name == 'mp4') {
            bestVideo = stream;
            if (stream.container.name == 'mp4') break;
          }
        }
      }
      bestVideo ??= videoOnly.first;

      // Best audio — prefer M4A for MP4 muxer compatibility
      audioOnly.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      AudioOnlyStreamInfo? bestAudio;
      for (final stream in audioOnly) {
        if (stream.container.name == 'mp4' || stream.container.name == 'm4a') {
          bestAudio = stream;
          break;
        }
      }
      bestAudio ??= audioOnly.first;

      final height = bestVideo.videoResolution.height;
      final filename = '$title (${height}p).mp4';
      final filesize = bestVideo.size.totalBytes + bestAudio.size.totalBytes;

      dev.log(
          'Separate streams: video=${height}p ${bestVideo.container.name} '
          '+ audio ${(bestAudio.bitrate.kiloBitsPerSecond).round()}kbps — '
          'total ~${_formatSize(filesize)}',
          name: _tag);

      return YouTubeResult(
        success: true,
        url: bestVideo.url.toString(),
        audioUrl: bestAudio.url.toString(),
        needsMerge: true,
        filename: filename,
        quality: '${height}p',
        filesize: filesize,
      );
    }

    // Fall back to muxed streams (≤720p)
    final muxed = manifest.muxed.toList();
    if (muxed.isEmpty) {
      dev.log('No muxed streams, trying video-only fallback', name: _tag);
      return _pickVideoOnly(manifest, title, targetHeight);
    }

    muxed.sort((a, b) =>
        (b.videoResolution.height).compareTo(a.videoResolution.height));

    MuxedStreamInfo? best;
    for (final stream in muxed) {
      if (stream.videoResolution.height <= targetHeight) {
        best = stream;
        break;
      }
    }
    best ??= muxed.last;

    final height = best.videoResolution.height;
    final ext = best.container.name;
    final filename = '$title (${height}p).$ext';
    final filesize = best.size.totalBytes;

    dev.log('Muxed stream: ${height}p $ext ${_formatSize(filesize)}', name: _tag);

    return YouTubeResult(
      success: true,
      url: best.url.toString(),
      filename: filename,
      quality: '${height}p',
      filesize: filesize,
    );
  }

  /// Pick best video-only stream at target quality.
  static YouTubeResult _pickVideoOnly(
    StreamManifest manifest,
    String title,
    int targetHeight,
  ) {
    final videoOnly = manifest.videoOnly.toList();
    if (videoOnly.isEmpty) {
      return const YouTubeResult(
        success: false,
        error: 'No video streams available for this video.',
      );
    }

    // Sort by resolution descending
    videoOnly.sort((a, b) =>
        (b.videoResolution.height).compareTo(a.videoResolution.height));

    // Prefer MP4 at target resolution
    VideoOnlyStreamInfo? best;
    for (final stream in videoOnly) {
      if (stream.videoResolution.height <= targetHeight) {
        if (best == null || stream.container.name == 'mp4') {
          best = stream;
          if (stream.container.name == 'mp4') break;
        }
      }
    }
    best ??= videoOnly.last;

    final height = best.videoResolution.height;
    final ext = best.container.name;
    final filename = '$title (${height}p).$ext';
    final filesize = best.size.totalBytes;

    dev.log('Video-only stream: ${height}p $ext ${_formatSize(filesize)}', name: _tag);

    return YouTubeResult(
      success: true,
      url: best.url.toString(),
      filename: filename,
      quality: '${height}p',
      filesize: filesize,
    );
  }

  /// Pick best audio stream.
  static YouTubeResult _pickAudio(
    StreamManifest manifest,
    String title,
  ) {
    final audioOnly = manifest.audioOnly.toList();
    if (audioOnly.isEmpty) {
      return const YouTubeResult(
        success: false,
        error: 'No audio streams available for this video.',
      );
    }

    // Sort by bitrate descending (best quality first)
    audioOnly.sort((a, b) => b.bitrate.compareTo(a.bitrate));

    // Prefer M4A/MP4 for compatibility
    AudioOnlyStreamInfo? best;
    for (final stream in audioOnly) {
      if (stream.container.name == 'mp4' || stream.container.name == 'm4a') {
        best = stream;
        break;
      }
    }
    best ??= audioOnly.first;

    final ext = best.container.name == 'mp4' ? 'm4a' : best.container.name;
    final filename = '$title.$ext';
    final filesize = best.size.totalBytes;
    final bitrate = (best.bitrate.kiloBitsPerSecond).round();

    dev.log('Audio stream: ${bitrate}kbps $ext ${_formatSize(filesize)}', name: _tag);

    return YouTubeResult(
      success: true,
      url: best.url.toString(),
      filename: filename,
      quality: '${bitrate}kbps',
      filesize: filesize,
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
