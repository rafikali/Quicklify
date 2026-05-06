import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/url_validator.dart';
import '../../core/services/cobalt_service.dart';
import '../../data/models/cobalt_request.dart';
import '../downloads/downloads_provider.dart';
import 'widgets/url_input_card.dart';
import 'widgets/quality_selector.dart';
import 'widgets/platform_chip.dart';

const String _tag = 'HomeScreen';

class HomeScreen extends StatefulWidget {
  final String? initialUrl;

  const HomeScreen({super.key, this.initialUrl});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  String? _detectedUrl;
  String? _detectedPlatform;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialUrl != null) {
      _setUrl(widget.initialUrl!);
    } else {
      _checkClipboard();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
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
        _urlController.text = url;
      });
    }
  }

  void _onPasteAndDownload() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      Fluttertoast.showToast(msg: 'Please paste a video URL');
      return;
    }
    final platform = UrlValidator.detectPlatform(url);
    if (platform == null) {
      Fluttertoast.showToast(msg: 'Unsupported URL. Try YouTube, TikTok, Facebook, Instagram, or Twitter.');
      return;
    }
    setState(() {
      _detectedUrl = url;
      _detectedPlatform = platform;
    });
    _showQualitySelector(url, platform);
  }

  void _showQualitySelector(String url, String platform) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
    dev.log('Quality: $quality, Mode: $downloadMode, Audio: $audioFormat', name: _tag);

    setState(() => _isLoading = true);

    try {
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
      dev.log('Cobalt response - downloadUrl: ${response.downloadUrl}', name: _tag);
      dev.log('Cobalt response - filename: ${response.filename}', name: _tag);
      dev.log('Cobalt response - error: ${response.errorMessage}', name: _tag);
      dev.log('Cobalt response - isSuccess: ${response.isSuccess}', name: _tag);

      if (!mounted) {
        dev.log('Widget not mounted, aborting', name: _tag);
        return;
      }

      if (response.isSuccess && response.downloadUrl != null) {
        dev.log('Success! Enqueuing download...', name: _tag);
        final downloadsProvider = context.read<DownloadsProvider>();
        await downloadsProvider.enqueueDownload(
          sourceUrl: url,
          downloadUrl: response.downloadUrl!,
          filename: response.filename ?? 'quicklify_download',
          platform: platform,
          quality: quality,
        );
        dev.log('Download enqueued successfully', name: _tag);
        Fluttertoast.showToast(msg: 'Download started!');
      } else if (response.status == 'picker' && response.pickerItems != null) {
        dev.log('Picker response with ${response.pickerItems!.length} items', name: _tag);
        final firstItem = response.pickerItems!.first;
        dev.log('Downloading first picker item: ${firstItem.url}', name: _tag);
        final downloadsProvider = context.read<DownloadsProvider>();
        await downloadsProvider.enqueueDownload(
          sourceUrl: url,
          downloadUrl: firstItem.url,
          filename: firstItem.filename ?? 'quicklify_download',
          platform: platform,
          quality: quality,
        );
        Fluttertoast.showToast(msg: 'Download started!');
      } else {
        dev.log('FAILED - status: ${response.status}, error: ${response.errorMessage}', name: _tag);
        Fluttertoast.showToast(
          msg: response.errorMessage ?? 'Failed to get download link',
        );
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // App title
            Row(
              children: [
                Icon(Icons.bolt, color: AppColors.primary, size: 32),
                const SizedBox(width: 8),
                Text(
                  'Quicklify',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Download videos in one tap',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Clipboard detection banner
            if (_detectedUrl != null && _detectedPlatform != null)
              _buildClipboardBanner(),

            const SizedBox(height: 16),

            // URL input card
            UrlInputCard(
              controller: _urlController,
              isLoading: _isLoading,
              onDownload: _onPasteAndDownload,
              onPaste: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  _urlController.text = data!.text!.trim();
                }
              },
            ),

            const SizedBox(height: 32),

            // Supported platforms
            Text(
              'Supported Platforms',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                PlatformChip(platform: 'youtube', label: 'YouTube'),
                PlatformChip(platform: 'tiktok', label: 'TikTok'),
                PlatformChip(platform: 'facebook', label: 'Facebook'),
                PlatformChip(platform: 'instagram', label: 'Instagram'),
                PlatformChip(platform: 'twitter', label: 'Twitter/X'),
                PlatformChip(platform: 'reddit', label: 'Reddit'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClipboardBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        color: AppColors.primary.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showQualitySelector(_detectedUrl!, _detectedPlatform!),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  UrlValidator.getPlatformIcon(_detectedPlatform!),
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Link detected from ${_detectedPlatform!.toUpperCase()}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _detectedUrl!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Download',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
