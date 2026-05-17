import 'package:flutter/material.dart';
import '../theme/flux_theme.dart';
import '../widgets/rain_background.dart';
import '../shell/app_shell_v2.dart';

class SplashScreenV2 extends StatefulWidget {
  final String? sharedUrl;

  const SplashScreenV2({super.key, this.sharedUrl});

  @override
  State<SplashScreenV2> createState() => _SplashScreenV2State();
}

class _SplashScreenV2State extends State<SplashScreenV2>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              AppShellV2(sharedUrl: widget.sharedUrl),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FluxColors.bg,
      body: RainBackground(
        lineCount: 80,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'QUICKLIFY',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 12,
                    color: FluxColors.cyan,
                    shadows: [
                      Shadow(
                        color: FluxColors.cyan.withValues(alpha: 0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Share anything. Quicklify handles the rest.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: FluxColors.textSecondary.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
