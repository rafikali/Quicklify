import 'package:flutter/material.dart';

class UrlValidator {
  UrlValidator._();

  static final Map<String, RegExp> _platformPatterns = {
    'youtube': RegExp(
      r'(youtube\.com|youtu\.be|youtube-nocookie\.com)',
      caseSensitive: false,
    ),
    'tiktok': RegExp(
      r'(tiktok\.com|vm\.tiktok\.com)',
      caseSensitive: false,
    ),
    'facebook': RegExp(
      r'(facebook\.com|fb\.watch|fb\.com)',
      caseSensitive: false,
    ),
    'instagram': RegExp(
      r'(instagram\.com|instagr\.am)',
      caseSensitive: false,
    ),
    'twitter': RegExp(
      r'(twitter\.com|x\.com|t\.co)',
      caseSensitive: false,
    ),
    'reddit': RegExp(
      r'(reddit\.com|redd\.it)',
      caseSensitive: false,
    ),
    'vimeo': RegExp(
      r'vimeo\.com',
      caseSensitive: false,
    ),
    'twitch': RegExp(
      r'(twitch\.tv|clips\.twitch\.tv)',
      caseSensitive: false,
    ),
    'snapchat': RegExp(
      r'snapchat\.com',
      caseSensitive: false,
    ),
    'pinterest': RegExp(
      r'pinterest\.(com|co\.uk|ca)',
      caseSensitive: false,
    ),
    'soundcloud': RegExp(
      r'soundcloud\.com',
      caseSensitive: false,
    ),
    'dailymotion': RegExp(
      r'dailymotion\.com',
      caseSensitive: false,
    ),
  };

  static String? detectPlatform(String url) {
    if (!_isValidUrl(url)) return null;

    for (final entry in _platformPatterns.entries) {
      if (entry.value.hasMatch(url)) {
        return entry.key;
      }
    }
    return null;
  }

  static bool isSupported(String url) => detectPlatform(url) != null;

  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  /// Extract a URL from text that may contain other content
  /// e.g., "Check out this video: https://youtube.com/watch?v=abc"
  static String? extractUrl(String text) {
    final urlRegex = RegExp(
      r'https?://[^\s<>"{}|\\^`\[\]]+',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);
    return match?.group(0);
  }

  static IconData getPlatformIcon(String platform) {
    switch (platform) {
      case 'youtube':
        return Icons.play_circle_fill;
      case 'tiktok':
        return Icons.music_note;
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt;
      case 'twitter':
        return Icons.alternate_email;
      case 'reddit':
        return Icons.forum;
      case 'vimeo':
        return Icons.videocam;
      case 'twitch':
        return Icons.live_tv;
      case 'soundcloud':
        return Icons.audiotrack;
      default:
        return Icons.link;
    }
  }
}
