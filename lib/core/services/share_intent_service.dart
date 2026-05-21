import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../utils/url_validator.dart';

class ShareIntentService {
  static StreamSubscription? _subscription;
  static Function(String url, String platform)? onUrlReceived;

  static String? pendingUrl;
  static String? pendingPlatform;

  static void initialize() {
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) => _handleSharedMedia(value),
    );

    ReceiveSharingIntent.instance.getInitialMedia().then(_handleSharedMedia);
  }

  static void _handleSharedMedia(List<SharedMediaFile> files) {
    for (final file in files) {
      if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
        _processText(file.path);
        break;
      }
    }
  }

  static void _processText(String text) {
    var url = text;
    var platform = UrlValidator.detectPlatform(url);
    if (platform == null) {
      final extracted = UrlValidator.extractUrl(text);
      if (extracted == null) return;
      platform = UrlValidator.detectPlatform(extracted);
      if (platform == null) return;
      url = extracted;
    }

    pendingUrl = url;
    pendingPlatform = platform;
    onUrlReceived?.call(url, platform);
  }

  static void consumePending() {
    pendingUrl = null;
    pendingPlatform = null;
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
