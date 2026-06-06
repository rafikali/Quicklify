import 'dart:developer' as dev;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/url_validator.dart';
import '../../core/services/ads_service.dart';
import '../../core/services/cobalt_service.dart';
import '../../core/services/share_intent_service.dart';
import '../../core/services/youtube_service.dart';
import '../../data/models/cobalt_request.dart';
import '../downloads/downloads_provider.dart';
import '../premium/widgets/remove_ads_cta.dart';
import '../settings/settings_provider.dart';
import 'widgets/quality_selector.dart';

const String _tag = 'HomeScreen';

class HomeScreen extends StatefulWidget {
  final String? initialUrl;
  final VoidCallback? onDownloadStarted;

  const HomeScreen({super.key, this.initialUrl, this.onDownloadStarted});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  String? _detectedUrl;
  String? _detectedPlatform;
  bool _isLoading = false;

  late AnimationController _rippleController;
  late AnimationController _pulseController;
  late AnimationController _ringController;

  // Cadence + provider come from the remote AdsConfig (admin panel).
  final _interstitial = InterstitialAdHelper(slot: AdSlot.downloadStart);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _interstitial.loadInterstitial();

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();

    ShareIntentService.onUrlReceived = (url, platform) {
      if (!mounted) return;
      _autoStartFromShare(url, platform);
    };

    final pendingUrl = ShareIntentService.pendingUrl;
    final pendingPlatform = ShareIntentService.pendingPlatform;
    if (pendingUrl != null && pendingPlatform != null) {
      ShareIntentService.consumePending();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _autoStartFromShare(pendingUrl, pendingPlatform);
      });
    } else if (widget.initialUrl != null) {
      final platform = UrlValidator.detectPlatform(widget.initialUrl!);
      if (platform != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _autoStartFromShare(widget.initialUrl!, platform);
        });
      } else {
        _setUrl(widget.initialUrl!);
      }
    } else {
      _checkClipboard();
    }
  }

  void _autoStartFromShare(String url, String platform) {
    if (_isLoading) return;
    setState(() {
      _detectedUrl = url;
      _detectedPlatform = platform;
    });
    final settings = context.read<SettingsProvider>();
    _startDownload(
      url,
      platform,
      settings.defaultQuality,
      settings.defaultMode,
      settings.defaultAudioFormat,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rippleController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    _interstitial.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

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
      });
    }
  }

  void _onTapDownload() async {
    // Prevent double-tap while already loading
    if (_isLoading) return;

    // If we have a detected URL, quick download it
    if (_detectedUrl != null && _detectedPlatform != null) {
      final settings = context.read<SettingsProvider>();
      _startDownload(
        _detectedUrl!,
        _detectedPlatform!,
        settings.defaultQuality,
        settings.defaultMode,
        settings.defaultAudioFormat,
      );
      return;
    }

    // Otherwise try to read clipboard
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        final url = data.text!.trim();
        final platform = UrlValidator.detectPlatform(url);
        if (platform != null) {
          setState(() {
            _detectedUrl = url;
            _detectedPlatform = platform;
          });
          if (!mounted) return;
          final settings = context.read<SettingsProvider>();
          _startDownload(
            url,
            platform,
            settings.defaultQuality,
            settings.defaultMode,
            settings.defaultAudioFormat,
          );
          return;
        }
      }
    } catch (_) {}

    Fluttertoast.showToast(msg: 'Copy a video link first');
  }

  void _onLongPress() {
    if (_detectedUrl != null && _detectedPlatform != null) {
      _showQualitySelector(_detectedUrl!, _detectedPlatform!);
    }
  }

  void _showQualitySelector(String url, String platform) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QualitySelector(
        url: url,
        platform: platform,
        onDownload: (quality, mode, audioFormat) {
          Navigator.pop(context);
          _startDownload(url, platform, quality, mode, audioFormat);
        },
      ),
    );
  }

  Future<void> _startDownload(
    String url,
    String platform,
    String quality,
    String downloadMode,
    String audioFormat,
  ) async {
    dev.log('=== DOWNLOAD FLOW START ===', name: _tag);
    dev.log('Source URL: $url', name: _tag);
    dev.log('Platform: $platform', name: _tag);
    dev.log('Quality: $quality, Mode: $downloadMode, Audio: $audioFormat',
        name: _tag);

    setState(() => _isLoading = true);

    try {
      if (platform == 'youtube') {
        // YouTube uses a dedicated self-hosted yt-dlp API server
        await _startYouTubeDownload(url, quality, downloadMode, audioFormat);
      } else {
        // All other platforms go through Cobalt
        await _startCobaltDownload(url, platform, quality, downloadMode, audioFormat);
      }
    } catch (e, stackTrace) {
      dev.log('EXCEPTION in download flow: $e', name: _tag);
      dev.log('Stack trace: $stackTrace', name: _tag);
      Fluttertoast.showToast(msg: 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
      dev.log('=== DOWNLOAD FLOW END ===', name: _tag);
    }
  }

  Future<void> _startYouTubeDownload(
    String url,
    String quality,
    String downloadMode,
    String audioFormat,
  ) async {
    final settings = context.read<SettingsProvider>();
    dev.log('YouTube extraction (explode → yt-dlp → piped) ...', name: _tag);

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
      dev.log('YouTube extraction success: ${result.filename}', name: _tag);
      final downloadsProvider = context.read<DownloadsProvider>();

      if (result.needsMerge && result.audioUrl != null) {
        // High-quality: separate video + audio streams, need merge
        dev.log('Using merge download (video + audio)', name: _tag);
        await downloadsProvider.enqueueMergeDownload(
          sourceUrl: url,
          videoUrl: result.url!,
          audioUrl: result.audioUrl!,
          filename: result.filename ?? 'youtube_video.mp4',
          platform: 'youtube',
          quality: quality,
          isYouTube: true,
        );
      } else {
        // Muxed stream or audio-only
        await downloadsProvider.enqueueDownload(
          sourceUrl: url,
          downloadUrl: result.url!,
          filename: result.filename ?? 'youtube_video.mp4',
          platform: 'youtube',
          quality: quality,
          isYouTube: true,
        );
      }
      if (mounted) _showDownloadStarted();
    } else {
      dev.log('YouTube extraction failed: ${result.error}', name: _tag);
      Fluttertoast.showToast(
        msg: result.error ?? 'Failed to get YouTube download link',
      );
    }
  }

  Future<void> _startCobaltDownload(
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

    dev.log('Calling Cobalt API...', name: _tag);
    final cobaltService = CobaltService();
    final response = await cobaltService.requestDownload(request);

    dev.log('Cobalt response - status: ${response.status}', name: _tag);

    if (!mounted) return;

    if (response.isSuccess && response.downloadUrl != null) {
      final downloadsProvider = context.read<DownloadsProvider>();
      await downloadsProvider.enqueueDownload(
        sourceUrl: url,
        downloadUrl: response.downloadUrl!,
        filename: response.filename ?? 'quicklify_download',
        platform: platform,
        quality: quality,
      );
      if (mounted) _showDownloadStarted();
    } else if (response.status == 'picker' && response.pickerItems != null) {
      final firstItem = response.pickerItems!.first;
      final downloadsProvider = context.read<DownloadsProvider>();
      await downloadsProvider.enqueueDownload(
        sourceUrl: url,
        downloadUrl: firstItem.url,
        filename: firstItem.filename ?? 'quicklify_download',
        platform: platform,
        quality: quality,
      );
      if (mounted) _showDownloadStarted();
    } else {
      Fluttertoast.showToast(
        msg: response.errorMessage ?? 'Failed to get download link',
      );
    }
  }

  void _showDownloadStarted() {
    // Navigate to downloads tab
    widget.onDownloadStarted?.call();

    // Cadence + provider come from AdsConfig (admin-controlled).
    if (context.read<SettingsProvider>().adsEnabled) {
      _interstitial.maybeShow(context);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            SizedBox(width: 12),
            Text(
              'Download started!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasLink = _detectedUrl != null && _detectedPlatform != null;

    return SafeArea(
      child: Column(
        children: [
          const RemoveAdsCta(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  _buildMainButton(hasLink),
                  const SizedBox(height: 32),
                  _buildStatusText(hasLink),
                  if (hasLink) ...[
                    const SizedBox(height: 16),
                    _buildOptionsHint(),
                  ],
                  const Spacer(flex: 4),
                ],
              ),
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildMainButton(bool hasLink) {
    final platformColor = hasLink
        ? AppColors.getPlatformColor(_detectedPlatform!)
        : AppColors.primary;

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring
          AnimatedBuilder(
            animation: _ringController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _ringController.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(200, 200),
                  painter: _RingPainter(
                    color: platformColor,
                    opacity: 0.15 + _pulseController.value * 0.1,
                  ),
                ),
              );
            },
          ),

          // Ripple rings
          if (!_isLoading) ...[
            AnimatedBuilder(
              animation: _rippleController,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(200, 200),
                  painter: _RipplePainter(
                    progress: _rippleController.value,
                    color: platformColor,
                  ),
                );
              },
            ),
          ],

          // Main tap circle
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = _isLoading ? 1.0 : 1.0 + _pulseController.value * 0.06;
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: GestureDetector(
              onTap: _isLoading ? null : _onTapDownload,
              onLongPress: _isLoading ? null : _onLongPress,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      platformColor.withValues(alpha: 0.25),
                      platformColor.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: platformColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: platformColor.withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: platformColor,
                          ),
                        )
                      : Icon(
                          hasLink
                              ? Icons.download_rounded
                              : Icons.content_paste_rounded,
                          color: platformColor,
                          size: 48,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText(bool hasLink) {
    if (_isLoading) {
      return const Text(
        'Getting download link...',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      );
    }

    if (hasLink) {
      final label = _detectedPlatform![0].toUpperCase() +
          _detectedPlatform!.substring(1);
      return Column(
        children: [
          Text(
            '$label link detected',
            style: TextStyle(
              color: AppColors.getPlatformColor(_detectedPlatform!),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              _detectedUrl!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.heroGradient.createShader(bounds),
          child: const Text(
            'Quicklify',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Copy a video link, then tap',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsHint() {
    return Text(
      'Long press for quality options',
      style: TextStyle(
        color: AppColors.textHint,
        fontSize: 12,
      ),
    );
  }
}

// ── Custom painters ────────────────────────────────────────────────

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final p = (progress + i * 0.33) % 1.0;
      final radius = 70 + p * 30;
      final opacity = (1.0 - p) * 0.25;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double opacity;

  _RingPainter({required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.opacity != opacity;
}
