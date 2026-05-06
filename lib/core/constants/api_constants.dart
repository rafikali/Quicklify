class ApiConstants {
  ApiConstants._();

  // Default: empty — user must configure their own Cobalt instance
  // The public api.cobalt.tools requires Turnstile auth (not usable from apps)
  // Deploy your own: https://railway.com/deploy/cobalt-media-downloader
  static const String defaultCobaltBaseUrl = 'https://cobalt-api-production-ad2b.up.railway.app';
  static const int connectTimeout = 15000; // ms
  static const int receiveTimeout = 30000; // ms
  static const int maxRequestsPerMinute = 20;

  static const String railwayDeployUrl =
      'https://railway.com/deploy/cobalt-media-downloader';
}
