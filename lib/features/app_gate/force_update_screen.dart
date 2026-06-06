import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features_v2/theme/flux_theme.dart';

/// Full-screen blocker shown when the installed version is older than
/// `minRequiredVersion`. The user can either tap "Download update" (opens
/// the APK URL in the system browser) or close the app. No way past.
class ForceUpdateScreen extends StatelessWidget {
  final String currentVersion;
  final String requiredVersion;
  final String apkUrl;
  final String message;

  const ForceUpdateScreen({
    super.key,
    required this.currentVersion,
    required this.requiredVersion,
    required this.apkUrl,
    required this.message,
  });

  Future<void> _download(BuildContext context) async {
    final uri = Uri.parse(apkUrl);
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open download link'),
          backgroundColor: FluxColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: FluxColors.bg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: FluxColors.cyan.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.system_update_alt,
                      size: 48,
                      color: FluxColors.cyan,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Update required',
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
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: FluxColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: FluxColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _VersionChip(label: 'Installed', value: currentVersion),
                        const SizedBox(width: 14),
                        const Icon(
                          Icons.arrow_forward,
                          color: FluxColors.textMuted,
                          size: 16,
                        ),
                        const SizedBox(width: 14),
                        _VersionChip(
                          label: 'Required',
                          value: requiredVersion,
                          accent: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _download(context),
                      icon: const Icon(Icons.download, size: 20),
                      label: const Text(
                        'Download update',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FluxColors.cyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => SystemNavigator.pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: FluxColors.textMuted,
                    ),
                    child: const Text('Close app'),
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

class _VersionChip extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _VersionChip({
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: FluxColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: accent ? FluxColors.cyan : FluxColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
