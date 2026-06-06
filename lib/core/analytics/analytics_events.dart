/// Single source of truth for event names + standard param keys. Keep
/// names short (GA4 caps custom event names at 40 chars) and snake_case
/// per GA4 convention. The `important` flag identifies events that also
/// write to the Firestore activity log so admins can pull them up in the
/// per-user timeline.
library;

class AnalyticsEvent {
  final String name;
  final bool important;

  const AnalyticsEvent._(this.name, {this.important = false});

  // ── Lifecycle ──────────────────────────────────────────────────────
  static const appOpen = AnalyticsEvent._('app_open', important: true);
  static const appResume = AnalyticsEvent._('app_resume');
  static const appBackground = AnalyticsEvent._('app_background');

  // ── Auth ───────────────────────────────────────────────────────────
  static const signInSuccess =
      AnalyticsEvent._('sign_in_success', important: true);
  static const signInFailed =
      AnalyticsEvent._('sign_in_failed', important: true);
  static const signOut = AnalyticsEvent._('sign_out', important: true);

  // ── Capture / download ─────────────────────────────────────────────
  static const linkDetected = AnalyticsEvent._('link_detected');
  static const captureStarted =
      AnalyticsEvent._('capture_started', important: true);
  static const captureExtractOk = AnalyticsEvent._('capture_extract_ok');
  static const captureExtractFailed =
      AnalyticsEvent._('capture_extract_failed', important: true);
  static const downloadSucceeded =
      AnalyticsEvent._('download_succeeded', important: true);
  static const downloadFailed =
      AnalyticsEvent._('download_failed', important: true);

  // ── Caption editor ─────────────────────────────────────────────────
  static const editorOpened =
      AnalyticsEvent._('editor_opened', important: true);
  static const editorBlockAdded = AnalyticsEvent._('editor_block_added');
  static const editorBlockRemoved =
      AnalyticsEvent._('editor_block_removed');
  static const editorPreview = AnalyticsEvent._('editor_preview');
  static const editorExportStart =
      AnalyticsEvent._('editor_export_start', important: true);
  static const editorExportOk =
      AnalyticsEvent._('editor_export_ok', important: true);
  static const editorExportFailed =
      AnalyticsEvent._('editor_export_failed', important: true);

  // ── Premium ────────────────────────────────────────────────────────
  static const premiumGateHit =
      AnalyticsEvent._('premium_gate_hit', important: true);
  static const premiumUpgradeTap =
      AnalyticsEvent._('premium_upgrade_tap', important: true);
  static const premiumPlanSelected =
      AnalyticsEvent._('premium_plan_selected', important: true);
  static const premiumGranted =
      AnalyticsEvent._('premium_granted', important: true);
  static const premiumRevoked =
      AnalyticsEvent._('premium_revoked', important: true);

  // ── Ads ────────────────────────────────────────────────────────────
  static const adInterstitialShown =
      AnalyticsEvent._('ad_interstitial_shown');
  static const adInterstitialSkipped =
      AnalyticsEvent._('ad_interstitial_skipped');
  static const adInterstitialFailed =
      AnalyticsEvent._('ad_interstitial_failed');
  static const adBannerClicked = AnalyticsEvent._('ad_banner_clicked');
  static const adHouseCtaClicked =
      AnalyticsEvent._('ad_house_cta_clicked', important: true);

  // ── Settings / nav ────────────────────────────────────────────────
  static const settingChanged = AnalyticsEvent._('setting_changed');

  // ── Errors ─────────────────────────────────────────────────────────
  static const errorCaught =
      AnalyticsEvent._('error_caught', important: true);
}

/// Standard param keys — kept here so the spelling can't drift between
/// call sites. GA4 caps param key length at 40 chars.
class AnalyticsParam {
  static const platform = 'platform'; // youtube, tiktok, …
  static const quality = 'quality'; // 720p, audio, …
  static const sourceUrl = 'source_url';
  static const filename = 'filename';
  static const error = 'error';
  static const screen = 'screen';
  static const route = 'route';
  static const previousRoute = 'previous_route';
  static const sessionId = 'session_id';
  static const provider = 'provider'; // ad provider: admob / house
  static const slot = 'slot'; // ad slot: download_start / download_complete
  static const planId = 'plan_id';
  static const blockCount = 'block_count';
  static const durationMs = 'duration_ms';
  static const fileSize = 'file_size';
  static const ctaUrl = 'cta_url';
  static const featureFlag = 'feature_flag';
  static const reason = 'reason';
}
