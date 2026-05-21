import 'dart:io';

class FileUtils {
  FileUtils._();

  /// Maximum length for the base name (excluding extension) before truncation.
  static const int _maxBaseLength = 150;

  /// Strip filesystem-illegal characters, collapse whitespace, trim, and
  /// enforce a reasonable max length while preserving the extension.
  static String sanitizeFilename(String filename) {
    // Replace invalid characters with a space (cleaner than underscore for titles)
    var sanitized = filename.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ');
    // Collapse runs of whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Strip leading/trailing dots (Windows-illegal, Unix-hidden)
    sanitized = sanitized.replaceAll(RegExp(r'^\.+|\.+$'), '').trim();

    if (sanitized.isEmpty) return 'quicklify_download';

    final ext = getExtension(sanitized);
    final base = ext.isEmpty
        ? sanitized
        : sanitized.substring(0, sanitized.length - ext.length);

    if (base.length > _maxBaseLength) {
      return '${base.substring(0, _maxBaseLength).trim()}$ext';
    }
    return sanitized;
  }

  /// Returns the extension including the leading dot, e.g. ".mp4". Empty if none.
  static String getExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot <= 0 || lastDot == filename.length - 1) return '';
    return filename.substring(lastDot);
  }

  /// Splits a filename into (base, extension) where extension includes the
  /// leading dot or is empty.
  static (String, String) splitNameAndExtension(String filename) {
    final ext = getExtension(filename);
    final base = ext.isEmpty
        ? filename
        : filename.substring(0, filename.length - ext.length);
    return (base, ext);
  }

  /// If a file with [desiredName] already exists in [directory], returns a
  /// new name with a human-readable suffix appended before the extension —
  /// e.g. `Foo.mp4` → `Foo (1).mp4`, `Foo (2).mp4`, ... Otherwise returns
  /// [desiredName] unchanged.
  static String resolveUniqueFilename(String directory, String desiredName) {
    final dir = Directory(directory);
    if (!dir.existsSync()) return desiredName;

    if (!File('$directory/$desiredName').existsSync()) return desiredName;

    final (base, ext) = splitNameAndExtension(desiredName);
    var counter = 1;
    while (true) {
      final candidate = '$base ($counter)$ext';
      if (!File('$directory/$candidate').existsSync()) return candidate;
      counter++;
    }
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
