import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../core/utils/url_validator.dart';
import '../../core/services/ads_service.dart';
import '../../core/services/cobalt_service.dart';
import '../../core/services/youtube_service.dart';
import '../../data/models/cobalt_request.dart';
import '../../features/downloads/downloads_provider.dart';
import '../../features/downloads/models/download_item.dart';
import '../../features/premium/widgets/remove_ads_cta.dart';
import '../../features/settings/settings_provider.dart';
import '../theme/flux_theme.dart';
import '../widgets/rain_background.dart';
import '../widgets/pipeline_steps.dart';
import '../widgets/circular_progress_ring.dart';
import '../widgets/confetti_overlay.dart';

const String _tag = 'CaptureScreen';

enum CaptureState {
  idle,
  linkDetected,
  extracting, // pipeline steps: detecting + capturing
  downloading, // circular progress ring
  merging, // pipeline step: merging
  complete, // confetti + done
  error,
}

class CaptureScreen extends StatefulWidget {
  final String? initialUrl;

  const CaptureScreen({super.key, this.initialUrl});

  @override
  State<CaptureScreen> createState() => CaptureScreenState();
}

class CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CaptureState _state = CaptureState.idle;
  String? _detectedUrl;
  String? _detectedPlatform;
  String? _activeTaskId;
  String? _completedFilename;
  String? _completedQuality;
  int? _completedFileSize;
  int _pipelineStep = 0;

  // Speed tracking
  int _lastProgress = 0;
  DateTime _lastProgressTime = DateTime.now();
  double _speedMBps = 0;

  late AnimationController _pulseController;

  final _interstitial = InterstitialAdHelper(frequency: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _interstitial.loadInterstitial();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    if (widget.initialUrl != null) {
      _setUrl(widget.initialUrl!);
    } else {
      _checkClipboard();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _interstitial.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _state == CaptureState.idle) {
      _checkClipboard();
    }
  }

  void setUrl(String url) => _setUrl(url);

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        final url = data.text!.trim();
        final platform = UrlValidator.detectPlatform(url);
        if (platform != null && url != _detectedUrl) {
          setState(() {
            _detectedUrl = url;
            _detectedPlatform = platform;
            _state = CaptureState.linkDetected;
          });
        }
      }
    } catch (_) {}
  }

  void _setUrl(String url) {
    final platform = UrlValidator.detectPlatform(url);
    if (platform != null) {
      setState(() {
        _detectedUrl = url;
        _detectedPlatform = platform;
        _state = CaptureState.linkDetected;
      });
    }
  }

  void _onCaptureStream() async {
    if (_state == CaptureState.extracting ||
        _state == CaptureState.downloading) return;
    if (_detectedUrl == null || _detectedPlatform == null) {
      // Try clipboard
      await _checkClipboard();
      if (_detectedUrl == null) {
        Fluttertoast.showToast(msg: 'Copy a video link first');
        return;
      }
    }

    final settings = context.read<SettingsProvider>();
    _startCapture(
      _detectedUrl!,
      _detectedPlatform!,
      settings.defaultQuality,
      settings.defaultMode,
      settings.defaultAudioFormat,
    );
  }

  Future<void> _startCapture(
    String url,
    String platform,
    String quality,
    String downloadMode,
    String audioFormat,
  ) async {
    dev.log('=== CAPTURE FLOW START ===', name: _tag);
    setState(() {
      _state = CaptureState.extracting;
      _pipelineStep = 0;
      _speedMBps = 0;
      _lastProgress = 0;
    });

    // Step 0: detecting media source
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _pipelineStep = 1); // Step 1: capturing stream data

    try {
      if (platform == 'youtube') {
        await _captureYouTube(url, quality, downloadMode, audioFormat);
      } else {
        await _captureCobalt(url, platform, quality, downloadMode, audioFormat);
      }
    } catch (e) {
      dev.log('CAPTURE ERROR: $e', name: _tag);
      if (mounted) {
        setState(() => _state = CaptureState.error);
        Fluttertoast.showToast(msg: 'Error: $e');
      }
    }
    dev.log('=== CAPTURE FLOW END ===', name: _tag);
  }

  Future<void> _captureYouTube(
    String url,
    String quality,
    String downloadMode,
    String audioFormat,
  ) async {
    final settings = context.read<SettingsProvider>();
    final result = await YouTubeService.getDownloadUrl(
      url: url,
      quality: quality,
      mode: downloadMode,
      audioFormat: audioFormat,
      ytDlpApiUrl: settings.youtubeApiUrl,
      ytDlpApiKey: settings.youtubeApiKey,
    );

    if (!mounted) return;

    if (result.success && result.url != null) {
      setState(() => _pipelineStep = 2); // merging

      final downloadsProvider = context.read<DownloadsProvider>();
      final filename = result.filename ?? 'youtube_video.mp4';

      if (result.needsMerge && result.audioUrl != null) {
        await downloadsProvider.enqueueMergeDownload(
          sourceUrl: url,
          videoUrl: result.url!,
          audioUrl: result.audioUrl!,
          filename: filename,
          platform: 'youtube',
          quality: quality,
          isYouTube: true,
        );
      } else {
        await downloadsProvider.enqueueDownload(
          sourceUrl: url,
          downloadUrl: result.url!,
          filename: filename,
          platform: 'youtube',
          quality: quality,
          isYouTube: true,
        );
      }

      _completedFilename = filename;
      _completedQuality = result.quality ?? quality;
      _completedFileSize = result.filesize;
      _startTrackingDownload(downloadsProvider);
    } else {
      setState(() => _state = CaptureState.error);
      Fluttertoast.showToast(
        msg: result.error ?? 'Failed to get YouTube download link',
      );
    }
  }

  Future<void> _captureCobalt(
    String url,
    String platform,
    String quality,
    String downloadMode,
    String audioFormat,
  ) async {
    final request = CobaltRequest(
      url: url,
      videoQuality: quality,
      downloadMode: downloadMode,
      audioFormat: audioFormat,
    );

    final cobaltService = CobaltService();
    final response = await cobaltService.requestDownload(request);

    if (!mounted) return;

    if (response.isSuccess && response.downloadUrl != null) {
      setState(() => _pipelineStep = 2);

      final downloadsProvider = context.read<DownloadsProvider>();
      final filename = response.filename ?? 'quicklify_download';

      await downloadsProvider.enqueueDownload(
        sourceUrl: url,
        downloadUrl: response.downloadUrl!,
        filename: filename,
        platform: platform,
        quality: quality,
      );

      _completedFilename = filename;
      _completedQuality = quality;
      _startTrackingDownload(downloadsProvider);
    } else if (response.status == 'picker' && response.pickerItems != null) {
      setState(() => _pipelineStep = 2);

      final firstItem = response.pickerItems!.first;
      final downloadsProvider = context.read<DownloadsProvider>();
      final filename = firstItem.filename ?? 'quicklify_download';

      await downloadsProvider.enqueueDownload(
        sourceUrl: url,
        downloadUrl: firstItem.url,
        filename: filename,
        platform: platform,
        quality: quality,
      );

      _completedFilename = filename;
      _completedQuality = quality;
      _startTrackingDownload(downloadsProvider);
    } else {
      setState(() => _state = CaptureState.error);
      Fluttertoast.showToast(
        msg: response.errorMessage ?? 'Failed to get download link',
      );
    }
  }

  void _startTrackingDownload(DownloadsProvider provider) {
    // Find the latest active download
    final active = provider.activeDownloads;
    if (active.isNotEmpty) {
      _activeTaskId = active.first.taskId;
      _lastProgressTime = DateTime.now();
      _lastProgress = 0;
    }

    // Transition to downloading state
    setState(() {
      _state = CaptureState.downloading;
      _pipelineStep = 3;
    });

    // Show an interstitial every Nth successful enqueue (respects ads toggle).
    if (context.read<SettingsProvider>().adsEnabled) {
      _interstitial.maybeShow();
    }

    // Start listening for updates
    provider.addListener(_onProviderUpdate);
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    final provider = context.read<DownloadsProvider>();

    // Find our download
    DownloadItem? item;
    if (_activeTaskId != null) {
      item = provider.allDownloads
          .where((d) => d.taskId == _activeTaskId)
          .firstOrNull;
    }
    // Fallback: first active
    item ??= provider.activeDownloads.firstOrNull;
    // Fallback: first completed
    item ??= provider.completedDownloads.firstOrNull;

    if (item == null) return;

    _activeTaskId = item.taskId;

    // Calculate speed
    final now = DateTime.now();
    final elapsed = now.difference(_lastProgressTime).inMilliseconds;
    if (elapsed > 500 && item.progress > _lastProgress && item.fileSize != null) {
      final bytesDownloaded =
          ((item.progress - _lastProgress) / 100) * item.fileSize!;
      _speedMBps = (bytesDownloaded / (elapsed / 1000)) / (1024 * 1024);
      _lastProgress = item.progress;
      _lastProgressTime = now;
    } else if (item.progress > _lastProgress) {
      _lastProgress = item.progress;
      _lastProgressTime = now;
    }

    if (item.isCompleted && _state != CaptureState.complete) {
      _completedFileSize = item.fileSize;
      setState(() => _state = CaptureState.complete);
      provider.removeListener(_onProviderUpdate);
    } else if (item.isFailed && _state != CaptureState.error) {
      setState(() => _state = CaptureState.error);
      provider.removeListener(_onProviderUpdate);
      Fluttertoast.showToast(msg: 'Download failed');
    } else if (_state == CaptureState.downloading) {
      setState(() {}); // rebuild for progress
    }
  }

  void _resetToIdle() {
    setState(() {
      _state = CaptureState.idle;
      _detectedUrl = null;
      _detectedPlatform = null;
      _activeTaskId = null;
      _completedFilename = null;
      _completedQuality = null;
      _completedFileSize = null;
      _pipelineStep = 0;
      _speedMBps = 0;
    });
    _checkClipboard();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FluxColors.bg,
      body: RainBackground(
        lineCount: _state == CaptureState.complete ? 0 : 50,
        child: SafeArea(
          child: Column(
            children: [
              const RemoveAdsCta(),
              Expanded(child: _buildBody()),
              const BannerAdWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case CaptureState.idle:
        return _buildIdle();
      case CaptureState.linkDetected:
        return _buildLinkDetected();
      case CaptureState.extracting:
        return _buildExtracting();
      case CaptureState.downloading:
        return _buildDownloading();
      case CaptureState.merging:
        return _buildExtracting(); // same UI, different step
      case CaptureState.complete:
        return _buildComplete();
      case CaptureState.error:
        return _buildError();
    }
  }

  Widget _buildIdle() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'QUICKLIFY',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w200,
              letterSpacing: 10,
              color: FluxColors.cyan,
              shadows: [
                Shadow(
                  color: FluxColors.cyan.withValues(alpha: 0.4),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Share anything. Quicklify handles the rest.',
            style: TextStyle(
              fontSize: 13,
              color: FluxColors.textSecondary,
            ),
          ),
          const SizedBox(height: 60),
          const Text(
            'Copy a video link to get started',
            style: TextStyle(
              fontSize: 14,
              color: FluxColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkDetected() {
    return Column(
      children: [
        const Spacer(flex: 2),
        // Branding
        Text(
          'QUICKLIFY',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w200,
            letterSpacing: 8,
            color: FluxColors.cyan,
            shadows: [
              Shadow(
                color: FluxColors.cyan.withValues(alpha: 0.4),
                blurRadius: 16,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Share anything. Quicklify handles the rest.',
          style: TextStyle(fontSize: 12, color: FluxColors.textSecondary),
        ),
        const Spacer(),
        // Link detected card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FluxColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: FluxColors.borderCyan),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FluxColors.cyan.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: FluxColors.cyan, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Link detected',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FluxColors.cyan,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _detectedUrl!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: FluxColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Capture Stream button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _onCaptureStream,
              style: ElevatedButton.styleFrom(
                backgroundColor: FluxColors.cyan,
                foregroundColor: FluxColors.bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Capture Stream',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildExtracting() {
    final titles = [
      'Detecting media source',
      'Capturing stream data',
      'Merging audio & video',
      'Optimizing download',
    ];
    final title = _pipelineStep < titles.length
        ? titles[_pipelineStep]
        : 'Processing...';

    return Column(
      children: [
        const Spacer(flex: 2),
        // Animated icon
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = 1.0 + _pulseController.value * 0.08;
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FluxColors.cyan.withValues(alpha: 0.12),
              border: Border.all(
                color: FluxColors.cyan.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: FluxColors.cyan.withValues(alpha: 0.2),
                  blurRadius: 24,
                ),
              ],
            ),
            child: const Icon(Icons.radar, color: FluxColors.cyan, size: 36),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: FluxColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Automatic pipeline active',
          style: TextStyle(fontSize: 13, color: FluxColors.textMuted),
        ),
        const SizedBox(height: 32),
        PipelineSteps(
          activeStep: _pipelineStep,
          url: _detectedUrl ?? '',
        ),
        const Spacer(flex: 3),
      ],
    );
  }

  Widget _buildDownloading() {
    final provider = context.watch<DownloadsProvider>();
    DownloadItem? item;
    if (_activeTaskId != null) {
      item = provider.allDownloads
          .where((d) => d.taskId == _activeTaskId)
          .firstOrNull;
    }
    item ??= provider.activeDownloads.firstOrNull;

    final progress = item?.progress ?? 0;
    final speedStr = _speedMBps > 0
        ? '${_speedMBps.toStringAsFixed(1)} MB/s'
        : '';

    return Column(
      children: [
        const Spacer(flex: 2),
        CircularProgressRing(
          progress: progress,
          speedText: speedStr,
        ),
        const SizedBox(height: 32),
        const Text(
          'Streaming media',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: FluxColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Parallel pipeline active',
          style: TextStyle(fontSize: 13, color: FluxColors.textMuted),
        ),
        const SizedBox(height: 32),
        // Parallel streams indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(8, (i) {
                  return Container(
                    width: 24,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i < (progress / 12.5).ceil()
                          ? FluxColors.cyan
                          : FluxColors.surface,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: FluxColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '8 parallel streams',
                  style: TextStyle(
                    fontSize: 12,
                    color: FluxColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }

  Widget _buildComplete() {
    final sizeStr = _completedFileSize != null
        ? _formatSize(_completedFileSize!)
        : '';
    final qualityStr = _completedQuality ?? '';
    final titleStr = _completedFilename
            ?.replaceAll(RegExp(r'\.\w+$'), '')
            .replaceAll(RegExp(r'\s*\(\d+p\)\s*$'), '') ??
        'Video captured';

    return Stack(
      children: [
        // Confetti
        const Positioned.fill(child: ConfettiOverlay()),
        // Content
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Checkmark
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: FluxColors.cyan, width: 3),
                ),
                child: const Icon(Icons.check, color: FluxColors.cyan, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'Captured',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: FluxColors.textPrimary,
                ),
              ),
              const SizedBox(height: 28),
              // Video info card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FluxColors.card.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: FluxColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: FluxColors.cyan.withValues(alpha: 0.15),
                      ),
                      child: const Icon(Icons.movie_creation,
                          color: FluxColors.cyan, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: FluxColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [qualityStr, sizeStr]
                                .where((s) => s.isNotEmpty)
                                .join(' \u2022 '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: FluxColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // New capture button
              TextButton.icon(
                onPressed: _resetToIdle,
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('New Capture'),
                style: TextButton.styleFrom(
                  foregroundColor: FluxColors.cyan,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FluxColors.error.withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.error_outline,
                color: FluxColors.error, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'Capture failed',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: FluxColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Something went wrong. Try again.',
            style: TextStyle(fontSize: 13, color: FluxColors.textSecondary),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _resetToIdle,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FluxColors.cyan,
              foregroundColor: FluxColors.bg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
