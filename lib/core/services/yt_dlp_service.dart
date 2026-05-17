import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'youtube_service.dart';

const String _tag = 'YtDlpService';

/// Calls the self-hosted yt-dlp API server (youtube-api/).
/// Returns a [YouTubeResult] that plugs into the same download flow.
class YtDlpService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
    validateStatus: (status) => true,
  ));

  /// Extract download URL(s) via the yt-dlp API server.
  ///
  /// [baseUrl] — server URL (e.g. "https://your-app.railway.app")
  /// [apiKey]  — optional API key for the x-api-key header
  static Future<YouTubeResult> getDownloadUrl({
    required String baseUrl,
    required String url,
    required String quality,
    required String mode,
    required String audioFormat,
    String? apiKey,
  }) async {
    dev.log('--- yt-dlp API extraction ---', name: _tag);
    dev.log('Server: $baseUrl', name: _tag);
    dev.log('URL: $url, quality: $quality, mode: $mode', name: _tag);

    try {
      final headers = <String, String>{};
      if (apiKey != null && apiKey.isNotEmpty) {
        headers['x-api-key'] = apiKey;
      }

      final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final response = await _dio.post(
        '$base/download',
        data: {
          'url': url,
          'quality': quality,
          'mode': mode,
          'audioFormat': audioFormat,
        },
        options: Options(headers: headers),
      );

      if (response.statusCode != 200 || response.data is! Map) {
        dev.log(
            'API error: status=${response.statusCode} body=${response.data}',
            name: _tag);
        return YouTubeResult(
          success: false,
          error: 'yt-dlp API returned ${response.statusCode}',
        );
      }

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status != 'ok') {
        final msg = data['message'] as String? ?? 'Unknown error';
        dev.log('API extraction failed: $msg', name: _tag);
        return YouTubeResult(success: false, error: msg);
      }

      final streamUrl = data['url'] as String?;
      if (streamUrl == null || streamUrl.isEmpty) {
        return const YouTubeResult(
          success: false,
          error: 'yt-dlp API returned no URL',
        );
      }

      final audioUrl = data['audioUrl'] as String?;
      final needsMerge = data['needsMerge'] as bool? ?? false;
      final filename = data['filename'] as String?;
      final resultQuality = data['quality'] as String?;
      final filesize = data['filesize'] as int?;

      dev.log(
          'yt-dlp API success: ${filename ?? "unknown"} '
          '${needsMerge ? "(merge)" : "(single)"}',
          name: _tag);

      return YouTubeResult(
        success: true,
        url: streamUrl,
        audioUrl: needsMerge ? audioUrl : null,
        needsMerge: needsMerge && audioUrl != null,
        filename: filename,
        quality: resultQuality,
        filesize: filesize,
      );
    } on DioException catch (e) {
      dev.log('yt-dlp API network error: ${e.message}', name: _tag);
      return YouTubeResult(
        success: false,
        error: 'yt-dlp API unreachable: ${e.message}',
      );
    } catch (e) {
      dev.log('yt-dlp API error: $e', name: _tag);
      return YouTubeResult(
        success: false,
        error: 'yt-dlp API error: $e',
      );
    }
  }

  /// Quick health check — returns true if the server is reachable.
  static Future<bool> isAvailable(String baseUrl) async {
    try {
      final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final response = await _dio.get(
        '$base/health',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

