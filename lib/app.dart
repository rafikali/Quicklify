import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'features/settings/settings_provider.dart';
import 'features_v2/theme/flux_theme.dart';
import 'features_v2/splash/splash_screen_v2.dart';

class QuicklifyApp extends StatelessWidget {
  final String? sharedUrl;

  const QuicklifyApp({super.key, this.sharedUrl});

  @override
  Widget build(BuildContext context) {
    final useV2 = context.watch<SettingsProvider>().useV2UI;

    if (useV2) {
      return MaterialApp(
        title: 'Quicklify',
        debugShowCheckedModeBanner: false,
        theme: FluxTheme.dark,
        home: SplashScreenV2(sharedUrl: sharedUrl),
      );
    }

    return MaterialApp(
      title: 'Quicklify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: AppShell(sharedUrl: sharedUrl),
    );
  }
}
