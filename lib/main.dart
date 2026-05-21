import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/download_service.dart';
import 'core/services/share_intent_service.dart';
import 'features/downloads/downloads_provider.dart';
import 'features/settings/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize();

  await DownloadService.initialize();

  // Initialize share intent service
  ShareIntentService.initialize();

  // Create providers
  final downloadsProvider = DownloadsProvider();
  final settingsProvider = SettingsProvider();

  // Initialize providers
  await settingsProvider.initialize();
  await downloadsProvider.initialize();

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
      ],
      child: QuicklifyApp(sharedUrl: sharedUrl),
    ),
  );
}
