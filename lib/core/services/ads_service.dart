import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../features/settings/settings_provider.dart';

const String _tag = 'AdsService';

class AdUnitIds {
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _prodBanner = 'ca-app-pub-3985125214088479/3480381901';
  static const String _prodInterstitial = 'ca-app-pub-3985125214088479/5437599476';

  static String get banner => kDebugMode ? _testBanner : _prodBanner;
  static String get interstitial => kDebugMode ? _testInterstitial : _prodInterstitial;
}

/// Reusable banner widget. Returns SizedBox.shrink() if ads disabled in settings
/// or if the banner failed to load.
class BannerAdWidget extends StatefulWidget {
  final AdSize size;

  const BannerAdWidget({super.key, this.size = AdSize.banner});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
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
    if (!adsEnabled || !_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}

/// Manages a single interstitial ad: preload, show, reload after dismissal.
/// Tracks an internal counter so callers can fire `maybeShow()` every Nth event.
class InterstitialAdHelper {
  InterstitialAd? _ad;
  bool _loading = false;
  int _counter = 0;

  /// Show an interstitial only every [frequency] calls (default 3).
  int frequency;

  InterstitialAdHelper({this.frequency = 3});

  void loadInterstitial() {
    if (_ad != null || _loading) return;
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

  /// Show the ad if it's loaded. Returns true if shown.
  bool showInterstitialIfReady() {
    if (_ad == null) {
      loadInterstitial();
      return false;
    }
    _ad!.show();
    return true;
  }

  /// Increments the counter and shows the ad only every [frequency]th call.
  /// Returns true if an ad was shown.
  bool maybeShow() {
    _counter++;
    if (_counter % frequency != 0) return false;
    return showInterstitialIfReady();
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
