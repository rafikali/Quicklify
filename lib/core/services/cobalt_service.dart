import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../../data/models/cobalt_request.dart';
import '../../data/models/cobalt_response.dart';

class CobaltService {
  static const String _tag = 'CobaltService';
  late final Dio _dio;
  String? _bearerToken;

  CobaltService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
      // Accept all status codes so we can parse error bodies ourselves
      validateStatus: (status) => true,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));
  }

  Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('cobalt_base_url') ?? ApiConstants.defaultCobaltBaseUrl;
    dev.log('Using Cobalt base URL: $url', name: _tag);
    return url;
  }

  /// Try to create a session and get a JWT bearer token
  Future<String?> _getSessionToken(String baseUrl) async {
    dev.log('Attempting to get session token...', name: _tag);
    try {
      final response = await _dio.post(
        '$baseUrl/session',
        data: {},
      );
      dev.log('Session response status: ${response.statusCode}', name: _tag);
      dev.log('Session response body: ${response.data}', name: _tag);

      if (response.statusCode == 200 && response.data is Map) {
        final token = response.data['token'] as String?;
        if (token != null) {
          dev.log('Got session token (${token.length} chars)', name: _tag);
          return token;
        }
      }
    } catch (e) {
      dev.log('Session token request failed: $e', name: _tag);
    }
    return null;
  }

  Future<CobaltResponse> requestDownload(CobaltRequest request) async {
    dev.log('--- REQUEST START ---', name: _tag);
    dev.log('URL to download: ${request.url}', name: _tag);
    dev.log('Request body: ${request.toJson()}', name: _tag);

    try {
      final baseUrl = await _getBaseUrl();

      if (baseUrl.isEmpty) {
        dev.log('No Cobalt URL configured', name: _tag);
        return const CobaltResponse(
          status: 'error',
          errorMessage:
              'No Cobalt server configured.\n\n'
              '1. Deploy your own free Cobalt server on Railway\n'
              '2. Go to Settings > Cobalt API URL\n'
              '3. Paste your server URL',
        );
      }

      // Try to get a session token if we don't have one
      _bearerToken ??= await _getSessionToken(baseUrl);

      // Build headers
      final headers = <String, dynamic>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (_bearerToken != null) {
        headers['Authorization'] = 'Bearer $_bearerToken';
        dev.log('Using bearer token for auth', name: _tag);
      }

      dev.log('POST $baseUrl', name: _tag);
      final response = await _dio.post(
        baseUrl,
        data: request.toJson(),
        options: Options(headers: headers),
      );

      dev.log('Response status code: ${response.statusCode}', name: _tag);
      dev.log('Response body: ${response.data}', name: _tag);

      // If auth failed, clear token and show proper message
      if (response.statusCode == 400 || response.statusCode == 401) {
        final data = response.data;
        if (data is Map) {
          final errorCode = data['error']?['code'] as String?;
          dev.log('Error code from API: $errorCode', name: _tag);

          if (errorCode == 'error.api.auth.jwt.missing' ||
              errorCode == 'error.api.auth.jwt.invalid') {
            _bearerToken = null; // Clear invalid token
            dev.log('Auth required - public API needs authentication', name: _tag);
            return const CobaltResponse(
              status: 'error',
              errorMessage:
                  'The public Cobalt API requires authentication. '
                  'Please set a self-hosted Cobalt URL in Settings.\n\n'
                  'Go to Settings > Cobalt API URL',
            );
          }

          // Parse other error responses
          return CobaltResponse.fromJson(data as Map<String, dynamic>);
        }
      }

      if (response.statusCode == 429) {
        dev.log('Rate limited', name: _tag);
        return const CobaltResponse(
          status: 'error',
          errorMessage: 'Rate limited. Please wait a moment.',
        );
      }

      if (response.statusCode == 200 && response.data is Map) {
        final cobaltResponse = CobaltResponse.fromJson(response.data as Map<String, dynamic>);
        dev.log('Parsed response - status: ${cobaltResponse.status}', name: _tag);
        dev.log('Download URL: ${cobaltResponse.downloadUrl}', name: _tag);
        dev.log('Filename: ${cobaltResponse.filename}', name: _tag);
        if (cobaltResponse.pickerItems != null) {
          dev.log('Picker items: ${cobaltResponse.pickerItems!.length}', name: _tag);
        }
        if (cobaltResponse.errorMessage != null) {
          dev.log('Error message: ${cobaltResponse.errorMessage}', name: _tag);
        }
        dev.log('--- REQUEST END (success) ---', name: _tag);
        return cobaltResponse;
      }

      dev.log('ERROR: Server returned status ${response.statusCode}', name: _tag);
      dev.log('--- REQUEST END (http error) ---', name: _tag);
      return CobaltResponse(
        status: 'error',
        errorMessage: 'Server returned status ${response.statusCode}',
      );
    } on DioException catch (e) {
      dev.log('DioException type: ${e.type}', name: _tag);
      dev.log('DioException message: ${e.message}', name: _tag);
      dev.log('DioException response status: ${e.response?.statusCode}', name: _tag);
      dev.log('DioException response body: ${e.response?.data}', name: _tag);
      dev.log('--- REQUEST END (dio error) ---', name: _tag);

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return const CobaltResponse(
          status: 'error',
          errorMessage: 'Connection timed out. Check your internet.',
        );
      }
      return CobaltResponse(
        status: 'error',
        errorMessage: 'Network error: ${e.message}',
      );
    } catch (e, stackTrace) {
      dev.log('Unexpected error: $e', name: _tag);
      dev.log('Stack trace: $stackTrace', name: _tag);
      dev.log('--- REQUEST END (exception) ---', name: _tag);
      return CobaltResponse(
        status: 'error',
        errorMessage: 'Unexpected error: $e',
      );
    }
  }
}
