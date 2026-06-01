import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../features/premium/premium_provider.dart';
import '../../features/settings/settings_provider.dart';
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

/// Manages a single interstitial: preload, show, reload after dismissal.
class InterstitialAdHelper {
  InterstitialAd? _ad;
  bool _loading = false;
  int _counter = 0;

  int frequency;

  InterstitialAdHelper({this.frequency = 3});

  void loadInterstitial() {
    if (_ad != null || _loading) return;
    // Don't even preload for premium users — saves bandwidth and avoids
    // leaking the user to the ad SDK.
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

  /// Show the loaded interstitial. Returns true if shown.
  /// Premium-gate inline (diversified verify site #2).
  bool showInterstitialIfReady() {
    if (PremiumService.instance.isPremiumSync()) return false;
    if (_ad == null) {
      loadInterstitial();
      return false;
    }
    _ad!.show();
    return true;
  }

  /// Throttled show: only every [frequency]-th call.
  /// Premium-gate inline (also short-circuits the counter to avoid
  /// "interstitial about to fire next call" surprise when user upgrades).
  bool maybeShow() {
    if (PremiumService.instance.isPremiumSync()) return false;
    _counter++;
    if (_counter % frequency != 0) return false;
    return showInterstitialIfReady();
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
