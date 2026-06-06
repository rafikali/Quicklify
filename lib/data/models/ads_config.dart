import 'package:cloud_firestore/cloud_firestore.dart';

/// Remote-controlled ads tuning — sourced from Firestore `config/ads`.
///
/// Two axes of control:
///   1. Cadence — how often interstitials fire, with a minimum-interval
///      floor so back-to-back ads can't surprise a user. Admob policy
///      compliance lives here.
///   2. Provider — "admob" routes to the real AdMob unit; "house" routes
///      to an in-app full-screen video / banner image so the user can
///      cross-promote their own content (premium upsell, sister apps, etc.)
///      without paying ad-network rev share.
enum AdProvider {
  admob,
  house;

  static AdProvider parse(String? v) {
    switch (v) {
      case 'house':
        return AdProvider.house;
      case 'admob':
      default:
        return AdProvider.admob;
    }
  }

  String get wire => name;
}

class AdsConfig {
  // ── Cadence ────────────────────────────────────────────────────────
  /// Fire an interstitial every Nth successful download enqueue.
  /// 0 disables, 1 = every download.
  final int interstitialOnDownloadStart;

  /// Fire an interstitial every Nth download completion.
  final int interstitialOnDownloadComplete;

  /// Hard minimum seconds between any two interstitials. Safety floor so
  /// "start + complete" can't fire back-to-back on a fast clip.
  final int interstitialMinIntervalSeconds;

  /// Master switch for the bottom banner ad.
  final bool bannerEnabled;

  // ── Provider routing ───────────────────────────────────────────────
  final AdProvider interstitialProvider;
  final AdProvider bannerProvider;

  // ── House ad content ───────────────────────────────────────────────
  /// MP4 / supported video URL shown when interstitialProvider == house.
  final String houseInterstitialVideoUrl;
  final String houseInterstitialCtaText;
  final String houseInterstitialCtaUrl;

  /// 0 = skippable from the start. Otherwise the skip button only appears
  /// after this many seconds.
  final int houseInterstitialSkipAfterSeconds;

  /// Image URL shown when bannerProvider == house.
  final String houseBannerImageUrl;
  final String houseBannerCtaUrl;

  const AdsConfig({
    required this.interstitialOnDownloadStart,
    required this.interstitialOnDownloadComplete,
    required this.interstitialMinIntervalSeconds,
    required this.bannerEnabled,
    required this.interstitialProvider,
    required this.bannerProvider,
    required this.houseInterstitialVideoUrl,
    required this.houseInterstitialCtaText,
    required this.houseInterstitialCtaUrl,
    required this.houseInterstitialSkipAfterSeconds,
    required this.houseBannerImageUrl,
    required this.houseBannerCtaUrl,
  });

  /// Safe defaults — used when Firestore is unreachable on first launch
  /// or when the admin hasn't created the doc yet. Matches the previous
  /// hardcoded behavior (interstitial every download, banner enabled,
  /// AdMob provider).
  static const fallback = AdsConfig(
    interstitialOnDownloadStart: 1,
    interstitialOnDownloadComplete: 1,
    interstitialMinIntervalSeconds: 30,
    bannerEnabled: true,
    interstitialProvider: AdProvider.admob,
    bannerProvider: AdProvider.admob,
    houseInterstitialVideoUrl: '',
    houseInterstitialCtaText: '',
    houseInterstitialCtaUrl: '',
    houseInterstitialSkipAfterSeconds: 5,
    houseBannerImageUrl: '',
    houseBannerCtaUrl: '',
  );

  factory AdsConfig.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    return AdsConfig.fromMap(snap.data() ?? const {});
  }

  factory AdsConfig.fromMap(Map<String, dynamic> d) => AdsConfig(
        interstitialOnDownloadStart:
            (d['interstitialOnDownloadStart'] as num?)?.toInt() ??
                fallback.interstitialOnDownloadStart,
        interstitialOnDownloadComplete:
            (d['interstitialOnDownloadComplete'] as num?)?.toInt() ??
                fallback.interstitialOnDownloadComplete,
        interstitialMinIntervalSeconds:
            (d['interstitialMinIntervalSeconds'] as num?)?.toInt() ??
                fallback.interstitialMinIntervalSeconds,
        bannerEnabled:
            (d['bannerEnabled'] as bool?) ?? fallback.bannerEnabled,
        interstitialProvider:
            AdProvider.parse(d['interstitialProvider'] as String?),
        bannerProvider: AdProvider.parse(d['bannerProvider'] as String?),
        houseInterstitialVideoUrl:
            (d['houseInterstitialVideoUrl'] as String?) ?? '',
        houseInterstitialCtaText:
            (d['houseInterstitialCtaText'] as String?) ?? '',
        houseInterstitialCtaUrl:
            (d['houseInterstitialCtaUrl'] as String?) ?? '',
        houseInterstitialSkipAfterSeconds:
            (d['houseInterstitialSkipAfterSeconds'] as num?)?.toInt() ??
                fallback.houseInterstitialSkipAfterSeconds,
        houseBannerImageUrl:
            (d['houseBannerImageUrl'] as String?) ?? '',
        houseBannerCtaUrl: (d['houseBannerCtaUrl'] as String?) ?? '',
      );

  Map<String, dynamic> toCacheMap() => {
        'interstitialOnDownloadStart': interstitialOnDownloadStart,
        'interstitialOnDownloadComplete': interstitialOnDownloadComplete,
        'interstitialMinIntervalSeconds': interstitialMinIntervalSeconds,
        'bannerEnabled': bannerEnabled,
        'interstitialProvider': interstitialProvider.wire,
        'bannerProvider': bannerProvider.wire,
        'houseInterstitialVideoUrl': houseInterstitialVideoUrl,
        'houseInterstitialCtaText': houseInterstitialCtaText,
        'houseInterstitialCtaUrl': houseInterstitialCtaUrl,
        'houseInterstitialSkipAfterSeconds': houseInterstitialSkipAfterSeconds,
        'houseBannerImageUrl': houseBannerImageUrl,
        'houseBannerCtaUrl': houseBannerCtaUrl,
      };

  factory AdsConfig.fromCacheMap(Map<String, dynamic> d) =>
      AdsConfig.fromMap(d);
}
