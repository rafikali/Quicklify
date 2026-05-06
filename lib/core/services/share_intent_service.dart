import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../utils/url_validator.dart';

class ShareIntentService {
  static StreamSubscription? _subscription;
  static Function(String url, String platform)? onUrlReceived;

  static void initialize() {
    // Handle shared text when app is already running
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        _handleSharedMedia(value);
      },
    );

    // Handle shared text when app is opened from share
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      _handleSharedMedia(value);
    });
  }

  static void _handleSharedMedia(List<SharedMediaFile> files) {
    for (final file in files) {
      if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
        final text = file.path;
        _processText(text);
        break;
      }
    }
  }

  static void _processText(String text) {
    // Try direct URL
    var platform = UrlValidator.detectPlatform(text);
    if (platform != null) {
      onUrlReceived?.call(text, platform);
      return;
    }

    // Try extracting URL from text
    final extracted = UrlValidator.extractUrl(text);
    if (extracted != null) {
      platform = UrlValidator.detectPlatform(extracted);
      if (platform != null) {
        onUrlReceived?.call(extracted, platform);
      }
    }
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
