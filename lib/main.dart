import 'dart:async';
import 'dart:developer' as dev;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/services/app_config_service.dart';
import 'core/services/device_ban_service.dart';
import 'core/services/download_service.dart';
import 'core/services/plans_service.dart';
import 'core/services/premium_service.dart';
import 'core/services/share_intent_service.dart';
import 'core/services/user_ban_service.dart';
import 'features/downloads/downloads_provider.dart';
import 'features/premium/plans_provider.dart';
import 'features/premium/premium_provider.dart';
import 'features/settings/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase first — required for Auth/Firestore/Functions used by Premium.
  // If google-services.json is missing this throws; that's intentional so
  // the build fails loudly during setup rather than silently breaking premium.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    dev.log(
      'Firebase init failed (premium features disabled): $e',
      name: 'main',
    );
  }

  await MobileAds.instance.initialize();

  await DownloadService.initialize();

  // Initialize share intent service
  ShareIntentService.initialize();

  // Create providers
  final downloadsProvider = DownloadsProvider();
  final settingsProvider = SettingsProvider();
  final premiumProvider = PremiumProvider();
  final plansProvider = PlansProvider();

  // Initialize providers
  await settingsProvider.initialize();
  await downloadsProvider.initialize();
  await PremiumService.instance.initialize();
  // Plans listener is fire-and-forget — fallback catalog is used until the
  // first Firestore snapshot arrives.
  unawaited(PlansService.instance.initialize());
  // App gate: force-update config (global) + per-device ban + per-user ban.
  await AppConfigService.instance.initialize();
  unawaited(DeviceBanService.instance.initialize());
  unawaited(UserBanService.instance.initialize());

  // Listen for share intents
  String? sharedUrl;
  ShareIntentService.onUrlReceived = (url, platform) {
    sharedUrl = url;
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: downloadsProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: premiumProvider),
        ChangeNotifierProvider.value(value: plansProvider),
      ],
      child: QuicklifyApp(sharedUrl: sharedUrl),
    ),
  );
}
