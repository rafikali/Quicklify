import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/analytics/analytics_navigator_observer.dart';
import 'core/theme/app_theme.dart';
import 'features/app_gate/app_gate.dart';
import 'features/shell/app_shell.dart';
import 'features/settings/settings_provider.dart';
import 'features_v2/theme/flux_theme.dart';
import 'features_v2/splash/splash_screen_v2.dart';

class QuicklifyApp extends StatelessWidget {
  final String? sharedUrl;

  // One observer instance, shared between v1 and v2 paths. Stateless across
  // theme switches so screen tracking doesn't reset when the user toggles
  // UI versions.
  static final _navObserver = AnalyticsNavigatorObserver();

  const QuicklifyApp({super.key, this.sharedUrl});

  @override
  Widget build(BuildContext context) {
    final useV2 = context.watch<SettingsProvider>().useV2UI;

    if (useV2) {
      return MaterialApp(
        title: 'Quicklify',
        debugShowCheckedModeBanner: false,
        theme: FluxTheme.dark,
        navigatorObservers: [_navObserver],
        home: AppGate(child: SplashScreenV2(sharedUrl: sharedUrl)),
      );
    }

    return MaterialApp(
      title: 'Quicklify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorObservers: [_navObserver],
      home: AppGate(child: AppShell(sharedUrl: sharedUrl)),
    );
  }
}
