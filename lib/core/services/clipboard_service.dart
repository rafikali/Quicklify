import 'package:flutter/services.dart';
import '../utils/url_validator.dart';

class ClipboardService {
  ClipboardService._();

  static Future<({String url, String platform})?> checkForVideoUrl() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == null || data!.text!.isEmpty) return null;

      final text = data.text!.trim();

      // Try direct URL first
      var platform = UrlValidator.detectPlatform(text);
      if (platform != null) {
        return (url: text, platform: platform);
      }

      // Try extracting URL from text (e.g., "Check this out: https://...")
      final extracted = UrlValidator.extractUrl(text);
      if (extracted != null) {
        platform = UrlValidator.detectPlatform(extracted);
        if (platform != null) {
          return (url: extracted, platform: platform);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
