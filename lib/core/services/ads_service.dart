import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../data/models/ads_config.dart';
import '../../features/premium/premium_provider.dart';
import '../../features/settings/settings_provider.dart';
import 'ads_config_service.dart';
import 'premium_service.dart';

const String _tag = 'AdsService';

class AdUnitIds {
  // Using Google's universal test ad unit IDs in both debug and release so
  // users always see the ad slots — even before live AdMob units are wired up.
  // These are safe to ship: Google will never charge or attribute clicks on them.
  // Swap to real ca-app-pub-3985125214088479/... unit IDs when ready to go live.
  static const String banner = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitial = 'ca-app-pub-3940256099942544/1033173712';
}

/// Router widget — picks AdMob banner or HouseBannerWidget based on the
/// current AdsConfig. Listens to the config service so a provider flip in
/// the admin panel takes effect on the next config snapshot without a
/// restart.
class BannerAdWidget extends StatefulWidget {
  final AdSize size;

  const BannerAdWidget({super.key, this.size = AdSize.banner});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetRouterState();
}

class _BannerAdWidgetRouterState extends State<BannerAdWidget> {
  late AdsConfig _config;
  StreamSubscription<AdsConfig>? _sub;

  @override
  void initState() {
    super.initState();
    _config = AdsConfigService.instance.current;
    _sub = AdsConfigService.instance.changes.listen((cfg) {
      if (!mounted) return;
      setState(() => _config = cfg);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_config.bannerEnabled) return const SizedBox.shrink();
    if (_config.bannerProvider == AdProvider.house) {
      return HouseBannerWidget(
        imageUrl: _config.houseBannerImageUrl,
        ctaUrl: _config.houseBannerCtaUrl,
      );
    }
    return _AdmobBannerWidget(size: widget.size);
  }
}

class _AdmobBannerWidget extends StatefulWidget {
  final AdSize size;

  const _AdmobBannerWidget({required this.size});

  @override
  State<_AdmobBannerWidget> createState() => _AdmobBannerWidgetState();
}

class _AdmobBannerWidgetState extends State<_AdmobBannerWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (PremiumService.instance.isPremiumSync()) return;
    final ad = BannerAd(
      adUnitId: AdUnitIds.banner,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          dev.log('Banner failed: $error', name: _tag);
          ad.dispose();
        },
      ),
    );
    ad.load();
    _ad = ad;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adsEnabled = context.select<SettingsProvider, bool>((s) => s.adsEnabled);

    // Premium-gate inline (diversified verify site #1).
    // Both the Provider (cheap read) AND the service-level cache are checked —
    // a patch of one doesn't kill the other.
    final isPremium = context.select<PremiumProvider, bool>((p) => p.isPremium);
    final premiumCached = PremiumService.instance.isPremiumSync();

    if (!adsEnabled || isPremium || premiumCached || !_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}

/// Logical "where in the funnel" an interstitial fires. Used to look up
/// the right cadence knob from [AdsConfig].
enum AdSlot {
  downloadStart,
  downloadComplete,
}

/// Public router for interstitials.
///
/// Replaces the old fixed-frequency class. The slot determines which
/// cadence knob in [AdsConfig] applies; the live config also picks the
/// provider (AdMob vs. in-app house ad). A static min-interval guard makes
/// sure two interstitials can't fire within [AdsConfig.interstitialMinIntervalSeconds]
/// even when both [AdSlot]s would otherwise be due — this is the safety
/// floor that keeps the app under AdMob policy when the admin dials the
/// frequency knobs to 1 on both events.
class InterstitialAdHelper {
  final AdSlot slot;
  final _AdmobInterstitialAdHelper _admob = _AdmobInterstitialAdHelper();
  int _counter = 0;

  // Global so two helpers (one per slot) share the floor.
  static DateTime? _lastShownAt;

  InterstitialAdHelper({required this.slot});

  /// Backwards-compat constructor — existing call sites that pass
  /// `frequency:` are kept compiling. The frequency arg is ignored; the
  /// real frequency now comes from [AdsConfig]. Default slot covers the
  /// "kick off a download" case which is what every existing caller did.
  @Deprecated('Use InterstitialAdHelper(slot: …). Frequency is now remote.')
  factory InterstitialAdHelper.legacy({int frequency = 1}) =>
      InterstitialAdHelper(slot: AdSlot.downloadStart);

  void loadInterstitial() => _admob.loadInterstitial();

  bool maybeShow(BuildContext context) {
    final cfg = AdsConfigService.instance.current;
    final frequency = switch (slot) {
      AdSlot.downloadStart => cfg.interstitialOnDownloadStart,
      AdSlot.downloadComplete => cfg.interstitialOnDownloadComplete,
    };

    if (frequency <= 0) return false;
    if (PremiumService.instance.isPremiumSync()) return false;

    _counter++;
    if (_counter % frequency != 0) return false;

    final now = DateTime.now();
    final last = _lastShownAt;
    if (last != null) {
      final gap = now.difference(last).inSeconds;
      if (gap < cfg.interstitialMinIntervalSeconds) {
        dev.log(
          'Skipping interstitial: only ${gap}s since last (floor: ${cfg.interstitialMinIntervalSeconds}s)',
          name: _tag,
        );
        return false;
      }
    }

    bool shown;
    if (cfg.interstitialProvider == AdProvider.house) {
      shown = _showHouseInterstitial(context, cfg);
    } else {
      shown = _admob.showIfReady();
    }
    if (shown) _lastShownAt = now;
    return shown;
  }

  bool _showHouseInterstitial(BuildContext context, AdsConfig cfg) {
    if (cfg.houseInterstitialVideoUrl.isEmpty) return false;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => HouseInterstitialScreen(
          videoUrl: cfg.houseInterstitialVideoUrl,
          ctaText: cfg.houseInterstitialCtaText,
          ctaUrl: cfg.houseInterstitialCtaUrl,
          skipAfterSeconds: cfg.houseInterstitialSkipAfterSeconds,
        ),
        fullscreenDialog: true,
      ),
    );
    return true;
  }

  void dispose() {
    _admob.dispose();
  }
}

/// Internal AdMob-only helper — preserves the original preload/show/reload
/// behavior. Wrapped by [InterstitialAdHelper] which decides whether to
/// call it or route to the house provider.
class _AdmobInterstitialAdHelper {
  InterstitialAd? _ad;
  bool _loading = false;

  void loadInterstitial() {
    if (_ad != null || _loading) return;
    if (PremiumService.instance.isPremiumSync()) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _ad = null;
              loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              dev.log('Interstitial show failed: $error', name: _tag);
              ad.dispose();
              _ad = null;
              loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          dev.log('Interstitial load failed: $error', name: _tag);
          _loading = false;
          _ad = null;
        },
      ),
    );
  }

  bool showIfReady() {
    if (PremiumService.instance.isPremiumSync()) return false;
    if (_ad == null) {
      loadInterstitial();
      return false;
    }
    _ad!.show();
    return true;
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}

// ── House interstitial (in-app full-screen video) ───────────────────

/// Full-screen video shown instead of an AdMob interstitial when the admin
/// sets `interstitialProvider == "house"`. Plays the configured video,
/// shows a skip button after `skipAfterSeconds`, and an optional CTA
/// button that opens [ctaUrl] in the system browser / launcher.
class HouseInterstitialScreen extends StatefulWidget {
  final String videoUrl;
  final String ctaText;
  final String ctaUrl;
  final int skipAfterSeconds;

  const HouseInterstitialScreen({
    super.key,
    required this.videoUrl,
    required this.ctaText,
    required this.ctaUrl,
    required this.skipAfterSeconds,
  });

  @override
  State<HouseInterstitialScreen> createState() =>
      _HouseInterstitialScreenState();
}

class _HouseInterstitialScreenState extends State<HouseInterstitialScreen> {
  VideoPlayerController? _controller;
  Timer? _skipTimer;
  bool _canSkip = false;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.skipAfterSeconds;
    _canSkip = widget.skipAfterSeconds <= 0;
    _initVideo();
    if (!_canSkip) _startSkipCountdown();
  }

  Future<void> _initVideo() async {
    try {
      final uri = Uri.parse(widget.videoUrl);
      final c = VideoPlayerController.networkUrl(uri);
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      await c.play();
      c.addListener(_onVideoTick);
      setState(() => _controller = c);
    } catch (e) {
      dev.log('house ad video load failed: $e', name: _tag);
      // If the video can't load, close immediately rather than locking
      // the user on a black screen.
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _onVideoTick() {
    if (!mounted) return;
    final c = _controller;
    if (c == null) return;
    // Auto-close when the video naturally ends.
    if (c.value.position >= c.value.duration && c.value.duration.inSeconds > 0) {
      Navigator.of(context).maybePop();
    }
  }

  void _startSkipCountdown() {
    _skipTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        setState(() => _canSkip = true);
      }
    });
  }

  Future<void> _openCta() async {
    final url = widget.ctaUrl;
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      dev.log('CTA launch failed: $e', name: _tag);
    }
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return PopScope(
      canPop: _canSkip,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (c != null && c.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            // Skip button / countdown — top-right.
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: _canSkip
                    ? _CapsuleButton(
                        icon: Icons.close_rounded,
                        label: 'Skip ad',
                        onTap: () => Navigator.of(context).pop(),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Skip in $_secondsLeft',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
            ),
            // CTA — bottom-center, only if both fields set.
            if (widget.ctaText.isNotEmpty && widget.ctaUrl.isNotEmpty)
              Positioned(
                left: 24,
                right: 24,
                bottom: 32,
                child: SafeArea(
                  child: _CapsuleButton(
                    icon: Icons.arrow_forward_rounded,
                    label: widget.ctaText,
                    primary: true,
                    onTap: _openCta,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _CapsuleButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: primary
                ? Colors.white
                : Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: primary ? Colors.black : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon,
                  size: 18, color: primary ? Colors.black : Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ── House banner (image with CTA) ───────────────────────────────────

/// Image-based banner shown instead of an AdMob banner when the admin
/// sets `bannerProvider == "house"`. Taps the image to open the CTA URL.
class HouseBannerWidget extends StatelessWidget {
  final String imageUrl;
  final String ctaUrl;
  final double height;

  const HouseBannerWidget({
    super.key,
    required this.imageUrl,
    required this.ctaUrl,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return const SizedBox.shrink();

    final adsEnabled =
        context.select<SettingsProvider, bool>((s) => s.adsEnabled);
    final isPremium =
        context.select<PremiumProvider, bool>((p) => p.isPremium);
    if (!adsEnabled || isPremium) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: ctaUrl.isEmpty
              ? null
              : () async {
                  try {
                    await launchUrl(
                      Uri.parse(ctaUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (e) {
                    dev.log('house banner CTA failed: $e', name: _tag);
                  }
                },
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
