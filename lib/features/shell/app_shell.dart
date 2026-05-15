import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../home/home_screen.dart';
import '../downloads/downloads_screen.dart';
import '../downloads/downloads_provider.dart';
import '../settings/settings_screen.dart';

class AppShell extends StatefulWidget {
  final String? sharedUrl;

  const AppShell({super.key, this.sharedUrl});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      HomeScreen(initialUrl: widget.sharedUrl),
      const DownloadsScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.surface,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.glassBorder, width: 0.5),
          ),
        ),
        child: Consumer<DownloadsProvider>(
          builder: (context, provider, _) {
            final activeCount = provider.activeDownloads.length;

            return NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) =>
                  setState(() => _currentIndex = index),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: activeCount > 0
                      ? Badge(
                          label: Text(
                            '$activeCount',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.download_outlined),
                        )
                      : const Icon(Icons.download_outlined),
                  selectedIcon: activeCount > 0
                      ? Badge(
                          label: Text(
                            '$activeCount',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.download_rounded),
                        )
                      : const Icon(Icons.download_rounded),
                  label: 'Downloads',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
