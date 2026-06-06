import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features_v2/theme/flux_theme.dart';

/// Full-screen kill-switch shown when [AppConfig.blackoutEnabled] is true.
/// No back navigation, no close button, no interaction with the rest of the
/// app. Wrapped in a PopScope so Android back is also swallowed.
class BlackoutScreen extends StatelessWidget {
  final String message;

  const BlackoutScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: FluxColors.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: FluxColors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: FluxColors.error,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Service unavailable',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: FluxColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: FluxColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  OutlinedButton.icon(
                    onPressed: () => SystemNavigator.pop(),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Close app'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FluxColors.textSecondary,
                      side: const BorderSide(color: FluxColors.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
