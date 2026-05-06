class CobaltResponse {
  final String status;
  final String? downloadUrl;
  final String? filename;
  final List<PickerItem>? pickerItems;
  final String? errorCode;
  final String? errorMessage;

  const CobaltResponse({
    required this.status,
    this.downloadUrl,
    this.filename,
    this.pickerItems,
    this.errorCode,
    this.errorMessage,
  });

  bool get isSuccess => status == 'tunnel' || status == 'redirect';

  factory CobaltResponse.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'error';

    List<PickerItem>? pickerItems;
    if (status == 'picker' && json['picker'] != null) {
      pickerItems = (json['picker'] as List)
          .map((item) => PickerItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return CobaltResponse(
      status: status,
      downloadUrl: json['url'] as String?,
      filename: json['filename'] as String?,
      pickerItems: pickerItems,
      errorCode: json['error']?['code'] as String?,
      errorMessage: _getErrorMessage(status, json),
    );
  }

  static String? _getErrorMessage(String status, Map<String, dynamic> json) {
    if (status != 'error') return null;
    final code = json['error']?['code'] as String?;
    switch (code) {
      case 'error.api.link.invalid':
        return 'Invalid URL. Please check the link.';
      case 'error.api.rate_exceeded':
        return 'Too many requests. Please wait a moment.';
      case 'error.api.service.unsupported':
        return 'This platform is not supported.';
      case 'error.api.fetch.fail':
        return 'Could not fetch the video. It may be private or unavailable.';
      case 'error.api.fetch.rate':
        return 'Platform rate limit hit. Try again in a few seconds.';
      case 'error.api.auth.jwt.missing':
        return 'Authentication required. Set a self-hosted Cobalt URL in Settings.';
      case 'error.api.auth.jwt.invalid':
        return 'Authentication token invalid. Try again or use a self-hosted Cobalt URL.';
      case 'error.api.auth.turnstile.missing':
        return 'Turnstile verification required. Use a self-hosted Cobalt URL in Settings.';
      default:
        return code ?? 'An unknown error occurred.';
    }
  }
}

class PickerItem {
  final String url;
  final String? filename;
  final String? type;

  const PickerItem({
    required this.url,
    this.filename,
    this.type,
  });

  factory PickerItem.fromJson(Map<String, dynamic> json) {
    return PickerItem(
      url: json['url'] as String,
      filename: json['filename'] as String?,
      type: json['type'] as String?,
    );
  }
}
