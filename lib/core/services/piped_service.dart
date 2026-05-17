import 'dart:developer' as dev;
import 'package:dio/dio.dart';

const String _tag = 'PipedService';

/// Piped API instance URLs — fallback list in case one goes down.
/// These are community-hosted; they can go offline at any time.
/// The download flow falls back to Cobalt if all instances fail.
const List<String> _pipedInstances = [
  'https://pipedapi.kavin.rocks',
  'https://pipedapi.in.projectsegfau.lt',
  'https://pipedapi.drgns.space',
  'https://pipedapi.r4fo.com',
  'https://pipedapi.simpleprivacy.fr',
];

class PipedStream {
  final String url;
  final String format;
  final String quality;
  final String mimeType;
  final String? codec;
  final bool videoOnly;
  final int width;
  final int height;
  final int bitrate;
  final int contentLength;

  const PipedStream({
    required this.url,
    required this.format,
    required this.quality,
    required this.mimeType,
    this.codec,
    this.videoOnly = false,
    this.width = 0,
    this.height = 0,
    this.bitrate = 0,
    this.contentLength = -1,
  });

  factory PipedStream.fromJson(Map<String, dynamic> json) {
    return PipedStream(
      url: json['url'] as String,
      format: json['format'] as String? ?? '',
      quality: json['quality'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? '',
      codec: json['codec'] as String?,
      videoOnly: json['videoOnly'] as bool? ?? false,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      bitrate: json['bitrate'] as int? ?? 0,
      contentLength: json['contentLength'] as int? ?? -1,
    );
  }

  /// Parse the numeric resolution from the quality string (e.g. "1080p" → 1080).
  int get resolutionHeight {
    final match = RegExp(r'(\d+)').firstMatch(quality);
    return match != null ? int.parse(match.group(1)!) : 0;
  }
}

class PipedResult {
  final String title;
  final int duration;
  final String? thumbnailUrl;
  final List<PipedStream> videoStreams;
  final List<PipedStream> audioStreams;

  const PipedResult({
    required this.title,
    required this.duration,
    this.thumbnailUrl,
    required this.videoStreams,
    required this.audioStreams,
  });
}

class PipedService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    validateStatus: (status) => true,
  ));

  /// Extract a YouTube video ID from various URL formats.
  static String? extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // youtu.be/VIDEO_ID
    if (uri.host.contains('youtu.be')) {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      return id != null && id.length == 11 ? id : null;
    }

    // youtube.com/watch?v=VIDEO_ID
    if (uri.host.contains('youtube.com') || uri.host.contains('youtube-nocookie.com')) {
      // /watch?v=...
      final v = uri.queryParameters['v'];
      if (v != null && v.length == 11) return v;

      // /shorts/VIDEO_ID or /embed/VIDEO_ID
      if (uri.pathSegments.length >= 2) {
        final segment = uri.pathSegments[0];
        if (segment == 'shorts' || segment == 'embed') {
          final id = uri.pathSegments[1];
          if (id.length == 11) return id;
        }
      }
    }

    return null;
  }

  /// Fetch stream info for a YouTube video via the Piped API.
  static Future<PipedResult?> getStreams(String youtubeUrl) async {
    final videoId = extractVideoId(youtubeUrl);
    if (videoId == null) {
      dev.log('Could not extract video ID from: $youtubeUrl', name: _tag);
      return null;
    }
    dev.log('Video ID: $videoId', name: _tag);

    // Try each Piped instance until one succeeds
    for (final baseUrl in _pipedInstances) {
      try {
        dev.log('Trying Piped instance: $baseUrl', name: _tag);
        final response = await _dio.get('$baseUrl/streams/$videoId');

        if (response.statusCode != 200 || response.data is! Map) {
          dev.log('Instance $baseUrl returned status ${response.statusCode}', name: _tag);
          continue;
        }

        final data = response.data as Map<String, dynamic>;
        final title = data['title'] as String? ?? 'YouTube Video';
        final duration = data['duration'] as int? ?? 0;
        final thumbnail = data['thumbnailUrl'] as String?;

        final videoStreams = (data['videoStreams'] as List? ?? [])
            .map((s) => PipedStream.fromJson(s as Map<String, dynamic>))
            .where((s) => s.url.isNotEmpty && !s.quality.contains('LBRY'))
            .toList();

        final audioStreams = (data['audioStreams'] as List? ?? [])
            .map((s) => PipedStream.fromJson(s as Map<String, dynamic>))
            .where((s) => s.url.isNotEmpty)
            .toList();

        dev.log('Got ${videoStreams.length} video streams, ${audioStreams.length} audio streams', name: _tag);

        if (videoStreams.isEmpty && audioStreams.isEmpty) {
          dev.log('Instance $baseUrl returned 0 streams, skipping', name: _tag);
          continue;
        }

        dev.log('Title: $title', name: _tag);

        return PipedResult(
          title: title,
          duration: duration,
          thumbnailUrl: thumbnail,
          videoStreams: videoStreams,
          audioStreams: audioStreams,
        );
      } catch (e) {
        dev.log('Instance $baseUrl failed: $e', name: _tag);
      }
    }

    dev.log('All Piped instances failed', name: _tag);
    return null;
  }

  /// Pick the best video stream for a requested quality.
  /// Prefers MP4 (h264) for compatibility, falls back to WEBM.
  static PipedStream? pickVideoStream(List<PipedStream> streams, String requestedQuality) {
    final targetRes = int.tryParse(requestedQuality) ?? 1080;

    // Separate video-only and combined streams
    final videoOnly = streams.where((s) => s.videoOnly).toList();
    final combined = streams.where((s) => !s.videoOnly).toList();

    // First try: combined stream at or below requested quality (rare above 360p)
    if (combined.isNotEmpty) {
      combined.sort((a, b) => b.resolutionHeight.compareTo(a.resolutionHeight));
      final match = combined.where((s) => s.resolutionHeight <= targetRes).firstOrNull;
      if (match != null && match.resolutionHeight >= 360) {
        dev.log('Using combined stream: ${match.quality} ${match.format}', name: _tag);
        return match;
      }
    }

    // Second: video-only stream — prefer MP4/h264 at the target resolution
    if (videoOnly.isNotEmpty) {
      // Sort by how close to target, then prefer MP4
      videoOnly.sort((a, b) {
        final aDiff = (a.resolutionHeight - targetRes).abs();
        final bDiff = (b.resolutionHeight - targetRes).abs();
        if (aDiff != bDiff) return aDiff.compareTo(bDiff);
        // Prefer MP4 over WEBM for broader device compatibility
        final aIsMp4 = a.mimeType.contains('mp4') ? 0 : 1;
        final bIsMp4 = b.mimeType.contains('mp4') ? 0 : 1;
        return aIsMp4.compareTo(bIsMp4);
      });

      final best = videoOnly.first;
      dev.log('Using video-only stream: ${best.quality} ${best.format} ${best.codec}', name: _tag);
      return best;
    }

    return null;
  }

  /// Pick the best audio stream. Prefers M4A (AAC) for MP4 compatibility.
  static PipedStream? pickAudioStream(List<PipedStream> streams, {bool preferM4a = true}) {
    if (streams.isEmpty) return null;

    final m4a = streams.where((s) => s.format == 'M4A').toList();
    final opus = streams.where((s) => s.format == 'WEBMA_OPUS').toList();

    // Sort by bitrate descending
    m4a.sort((a, b) => b.bitrate.compareTo(a.bitrate));
    opus.sort((a, b) => b.bitrate.compareTo(a.bitrate));

    if (preferM4a && m4a.isNotEmpty) return m4a.first;
    if (opus.isNotEmpty) return opus.first;
    if (m4a.isNotEmpty) return m4a.first;

    return streams.first;
  }
}
