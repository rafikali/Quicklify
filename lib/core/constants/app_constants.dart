class AppConstants {
  AppConstants._();

  static const String appName = 'Quicklify';
  static const String downloadFolder = 'Quicklify';

  static const List<String> videoQualities = [
    '360',
    '480',
    '720',
    '1080',
    '1440',
    '2160',
  ];

  static const Map<String, String> qualityLabels = {
    '360': '360p',
    '480': '480p',
    '720': '720p (HD)',
    '1080': '1080p (Full HD)',
    '1440': '1440p (2K)',
    '2160': '2160p (4K)',
  };

  static const List<String> audioFormats = ['mp3', 'ogg', 'wav', 'opus'];

  static const Map<String, String> downloadModes = {
    'auto': 'Video + Audio',
    'audio': 'Audio Only',
    'mute': 'Video Only (No Audio)',
  };
}
