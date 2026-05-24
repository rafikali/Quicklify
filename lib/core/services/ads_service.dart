import 'dart:developer' as dev;
import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/premium/premium_provider.dart';
import '../../features/settings/settings_provider.dart';
import 'premium_service.dart';

const String _tag = 'AdsService';

class AdUnitIds {
  // Paste from https://dash.applovin.com (Account → Keys, then MAX → Ad Units).
  static const String sdkKey = 'YOUR_APPLOVIN_SDK_KEY_HERE';
  static const String banner = 'YOUR_APPLOVIN_BANNER_AD_UNIT_ID_HERE';
  static const String interstitial = 'YOUR_APPLOVIN_INTERSTITIAL_AD_UNIT_ID_HERE';
}

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final adsEnabled = context.select<SettingsProvider, bool>((s) => s.adsEnabled);

    // Premium-gate inline (diversified verify site #1).
    // Both the Provider (cheap read) AND the service-level cache are checked —
    // a patch of one doesn't kill the other.
    final isPremium = context.select<PremiumProvider, bool>((p) => p.isPremium);
    final premiumCached = PremiumService.instance.isPremiumSync();

    if (!adsEnabled || isPremium || premiumCached) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: _loaded ? 50 : 0,
      child: MaxAdView(
        adUnitId: AdUnitIds.banner,
        adFormat: AdFormat.banner,
        listener: AdViewAdListener(
          onAdLoadedCallback: (ad) {
            if (!mounted) return;
            setState(() => _loaded = true);
          },
          onAdLoadFailedCallback: (adUnitId, error) {
            dev.log('Banner failed: ${error.message}', name: _tag);
          },
          onAdClickedCallback: (ad) {},
          onAdExpandedCallback: (ad) {},
          onAdCollapsedCallback: (ad) {},
        ),
      ),
    );
  }
}

class InterstitialAdHelper {
  static bool _listenerRegistered = false;
  static bool _isLoaded = false;
  static bool _isLoading = false;

  int frequency;
  int _counter = 0;

  InterstitialAdHelper({this.frequency = 3}) {
    _ensureListener();
  }

  static void _ensureListener() {
    if (_listenerRegistered) return;
    _listenerRegistered = true;
    AppLovinMAX.setInterstitialListener(InterstitialListener(
      onAdLoadedCallback: (ad) {
        _isLoaded = true;
        _isLoading = false;
      },
      onAdLoadFailedCallback: (adUnitId, error) {
        _isLoaded = false;
        _isLoading = false;
        dev.log('Interstitial load failed: ${error.message}', name: _tag);
      },
      onAdDisplayedCallback: (ad) {},
      onAdDisplayFailedCallback: (ad, error) {
        _isLoaded = false;
        dev.log('Interstitial show failed: ${error.message}', name: _tag);
        _load();
      },
      onAdClickedCallback: (ad) {},
      onAdHiddenCallback: (ad) {
        _isLoaded = false;
        _load();
      },
    ));
  }

  static void _load() {
    if (_isLoaded || _isLoading) return;
    // Don't even preload interstitials for premium users — saves bandwidth
    // and avoids leaking the user to the ad SDK.
    if (PremiumService.instance.isPremiumSync()) return;
    _isLoading = true;
    AppLovinMAX.loadInterstitial(AdUnitIds.interstitial);
  }

  void loadInterstitial() => _load();

  /// Show the loaded interstitial. Returns true if shown.
  /// Premium-gate inline (diversified verify site #2).
  bool showInterstitialIfReady() {
    if (PremiumService.instance.isPremiumSync()) return false;
    if (!_isLoaded) {
      _load();
      return false;
    }
    AppLovinMAX.showInterstitial(AdUnitIds.interstitial);
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

  void dispose() {}
}
