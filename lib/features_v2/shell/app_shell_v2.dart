import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../features/downloads/downloads_provider.dart';
import '../theme/flux_theme.dart';
import '../capture/capture_screen.dart';
import '../stream/stream_history_screen.dart';
import '../system/system_screen_v2.dart';

class AppShellV2 extends StatefulWidget {
  final String? sharedUrl;

  const AppShellV2({super.key, this.sharedUrl});

  @override
  State<AppShellV2> createState() => _AppShellV2State();
}

class _AppShellV2State extends State<AppShellV2> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _captureKey = GlobalKey<CaptureScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _screens = [
      CaptureScreen(
        key: _captureKey,
        initialUrl: widget.sharedUrl,
      ),
      const StreamHistoryScreen(),
      const SystemScreenV2(),
    ];

    _setSystemUI();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setSystemUI();
    }
  }

  void _setSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: FluxColors.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        context.watch<DownloadsProvider>().activeDownloads.length;

    return Scaffold(
      backgroundColor: FluxColors.bg,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: FluxColors.bg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: FluxColors.cyan.withValues(alpha: 0.1),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Capture',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              backgroundColor: FluxColors.cyan,
              textColor: FluxColors.bg,
              child: const Icon(Icons.history_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              backgroundColor: FluxColors.cyan,
              textColor: FluxColors.bg,
              child: const Icon(Icons.history),
            ),
            label: 'Stream',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'System',
          ),
        ],
      ),
    );
  }
}
