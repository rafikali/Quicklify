import 'dart:developer' as dev;

import 'package:applovin_max/applovin_max.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/services/ads_service.dart';
import 'core/services/download_service.dart';
import 'core/services/premium_service.dart';
import 'core/services/share_intent_service.dart';
import 'features/downloads/downloads_provider.dart';
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
    dev.log('Firebase init failed (premium features disabled): $e', name: 'main');
  }

  await MobileAds.instance.initialize();
  await AppLovinMAX.initialize(AdUnitIds.sdkKey);

  await DownloadService.initialize();

  // Initialize share intent service
  ShareIntentService.initialize();

  // Create providers
  final downloadsProvider = DownloadsProvider();
  final settingsProvider = SettingsProvider();
  final premiumProvider = PremiumProvider();

  // Initialize providers
  await settingsProvider.initialize();
  await downloadsProvider.initialize();
  await PremiumService.instance.initialize();

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
      ],
      child: QuicklifyApp(sharedUrl: sharedUrl),
    ),
  );
}
