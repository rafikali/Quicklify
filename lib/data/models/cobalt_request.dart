class CobaltRequest {
  final String url;
  final String videoQuality;
  final String downloadMode;
  final String audioFormat;
  final String filenameStyle;
  final bool tiktokFullAudio;

  const CobaltRequest({
    required this.url,
    this.videoQuality = '1080',
    this.downloadMode = 'auto',
    this.audioFormat = 'mp3',
    this.filenameStyle = 'basic',
    this.tiktokFullAudio = false,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'videoQuality': videoQuality,
    'downloadMode': downloadMode,
    'audioFormat': audioFormat,
    'filenameStyle': filenameStyle,
    if (tiktokFullAudio) 'tiktokFullAudio': true,
  };
}
