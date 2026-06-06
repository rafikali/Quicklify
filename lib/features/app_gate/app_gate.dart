/// Root-level gate that wraps the app's home tree.
///
/// Decision order (first match wins):
///   1. signed-in user has `profiles/{uid}.banned == true` → BlackoutScreen
///      (per-user ban applied from the admin panel)
///   2. installed version < min_required_version → ForceUpdateScreen
///   3. otherwise → child (the real app)
///
/// Re-evaluates on every Firestore snapshot AND on AppLifecycleState.resumed
/// so changes made while the app was backgrounded take effect the instant
/// the user comes back.
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/services/app_config_service.dart';
import '../../core/services/user_ban_service.dart';
import '../../data/models/app_config.dart';
import 'blackout_screen.dart';
import 'force_update_screen.dart';

class AppGate extends StatefulWidget {
  final Widget child;

  const AppGate({super.key, required this.child});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  late AppConfig _config;
  String _currentVersion = '0.0.0';

  @override
  void initState() {
    super.initState();
    _config = AppConfigService.instance.current;
    WidgetsBinding.instance.addObserver(this);
    _loadVersion();
    AppConfigService.instance.changes.listen((cfg) {
      if (mounted) setState(() => _config = cfg);
    });
    UserBanService.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _currentVersion = info.version);
    } catch (_) {
      // Keep '0.0.0' — gate will treat as needing update if min is non-zero.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppConfigService.instance.fetchOnce();
      UserBanService.instance.fetchOnce();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (UserBanService.instance.isBanned) {
      return BlackoutScreen(message: UserBanService.instance.banReason);
    }
    if (_config.requiresUpdate(_currentVersion)) {
      return ForceUpdateScreen(
        currentVersion: _currentVersion,
        requiredVersion: _config.minRequiredVersion,
        apkUrl: _config.apkUrl,
        message: _config.updateMessage,
      );
    }
    return widget.child;
  }
}
