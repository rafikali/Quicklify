class DownloadItem {
  final String id;
  final String sourceUrl;
  final String downloadUrl;
  final String filename;
  final String platform;
  final String quality;
  final String? taskId; // flutter_downloader task ID
  int status; // 0=pending, 1=running, 2=completed, 3=failed, 4=paused, 5=canceled
  int progress;
  final DateTime createdAt;
  DateTime? completedAt;
  int? fileSize;
  String? galleryPath; // gallery URI or file path after save

  DownloadItem({
    required this.id,
    required this.sourceUrl,
    required this.downloadUrl,
    required this.filename,
    required this.platform,
    required this.quality,
    this.taskId,
    this.status = 0,
    this.progress = 0,
    DateTime? createdAt,
    this.completedAt,
    this.fileSize,
    this.galleryPath,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isActive => status == 0 || status == 1 || status == 4;
  bool get isCompleted => status == 2;
  bool get isFailed => status == 3;
  bool get isPaused => status == 4;

  String get statusText {
    switch (status) {
      case 0:
        return 'Pending';
      case 1:
        return 'Downloading';
      case 2:
        return 'Completed';
      case 3:
        return 'Failed';
      case 4:
        return 'Paused';
      case 5:
        return 'Canceled';
      default:
        return 'Unknown';
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'source_url': sourceUrl,
    'download_url': downloadUrl,
    'filename': filename,
    'platform': platform,
    'quality': quality,
    'task_id': taskId,
    'status': status,
    'progress': progress,
    'created_at': createdAt.millisecondsSinceEpoch,
    'completed_at': completedAt?.millisecondsSinceEpoch,
    'file_size': fileSize,
    'gallery_path': galleryPath,
  };

  factory DownloadItem.fromMap(Map<String, dynamic> map) => DownloadItem(
    id: map['id'] as String,
    sourceUrl: map['source_url'] as String,
    downloadUrl: map['download_url'] as String,
    filename: map['filename'] as String,
    platform: map['platform'] as String,
    quality: map['quality'] as String,
    taskId: map['task_id'] as String?,
    status: map['status'] as int? ?? 0,
    progress: map['progress'] as int? ?? 0,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    completedAt: map['completed_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
        : null,
    fileSize: map['file_size'] as int?,
    galleryPath: map['gallery_path'] as String?,
  );

  DownloadItem copyWith({
    String? taskId,
    int? status,
    int? progress,
    DateTime? completedAt,
    int? fileSize,
    String? galleryPath,
  }) {
    return DownloadItem(
      id: id,
      sourceUrl: sourceUrl,
      downloadUrl: downloadUrl,
      filename: filename,
      platform: platform,
      quality: quality,
      taskId: taskId ?? this.taskId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      fileSize: fileSize ?? this.fileSize,
      galleryPath: galleryPath ?? this.galleryPath,
    );
  }
}
