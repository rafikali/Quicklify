class FileUtils {
  FileUtils._();

  static String sanitizeFilename(String filename) {
    // Remove invalid characters
    var sanitized = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    // Remove leading/trailing dots and spaces
    sanitized = sanitized.trim().replaceAll(RegExp(r'^\.+|\.+$'), '');
    // Limit length
    if (sanitized.length > 200) {
      final ext = getExtension(sanitized);
      sanitized = '${sanitized.substring(0, 196)}$ext';
    }
    return sanitized.isEmpty ? 'quicklify_download' : sanitized;
  }

  static String getExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filename.length - 1) return '';
    return filename.substring(lastDot);
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
