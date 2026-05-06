import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/api_constants.dart';
import '../downloads/downloads_provider.dart';
import 'settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final hasServer = settings.cobaltBaseUrl.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.settings, color: AppColors.primary, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Server setup guide (show prominently if not configured)
              if (!hasServer) ...[
                _sectionTitle(context, 'Setup Required'),
                const SizedBox(height: 8),
                Card(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber, color: AppColors.warning, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Cobalt Server Not Configured',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Quicklify needs a Cobalt server to download videos. '
                          'You can deploy your own for free in 2 minutes:',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        _setupStep('1', 'Tap "Deploy on Railway" below'),
                        _setupStep('2', 'Create a free Railway account'),
                        _setupStep('3', 'Click Deploy — wait for it to finish'),
                        _setupStep('4', 'Copy your server URL (e.g. cobalt-xxx.up.railway.app)'),
                        _setupStep('5', 'Paste it in "Cobalt API URL" below'),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _launchRailway(),
                            icon: const Icon(Icons.rocket_launch, size: 20),
                            label: const Text('Deploy on Railway (Free)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Server settings
              _sectionTitle(context, 'Server'),
              const SizedBox(height: 8),

              Card(
                color: hasServer ? AppColors.success.withValues(alpha: 0.1) : null,
                shape: hasServer
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.success.withValues(alpha: 0.3)),
                      )
                    : null,
                child: ListTile(
                  leading: Icon(
                    hasServer ? Icons.check_circle : Icons.dns,
                    color: hasServer ? AppColors.success : AppColors.primary,
                  ),
                  title: const Text('Cobalt API URL', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(
                    hasServer ? settings.cobaltBaseUrl : 'Not configured — tap to set up',
                    style: TextStyle(
                      color: hasServer ? AppColors.success : AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => _showCobaltUrlEditor(context, settings),
                ),
              ),

              const SizedBox(height: 24),

              // Download preferences
              _sectionTitle(context, 'Download Defaults'),
              const SizedBox(height: 8),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.high_quality, color: AppColors.primary),
                  title: const Text('Default Quality', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(
                    AppConstants.qualityLabels[settings.defaultQuality] ?? settings.defaultQuality,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  onTap: () => _showQualityPicker(context, settings),
                ),
              ),
              const SizedBox(height: 8),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.videocam, color: AppColors.primary),
                  title: const Text('Default Mode', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(
                    AppConstants.downloadModes[settings.defaultMode] ?? settings.defaultMode,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  onTap: () => _showModePicker(context, settings),
                ),
              ),
              const SizedBox(height: 8),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.audiotrack, color: AppColors.primary),
                  title: const Text('Default Audio Format', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(
                    settings.defaultAudioFormat.toUpperCase(),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  onTap: () => _showAudioFormatPicker(context, settings),
                ),
              ),

              const SizedBox(height: 24),

              // Data
              _sectionTitle(context, 'Data'),
              const SizedBox(height: 8),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.delete_sweep, color: AppColors.error),
                  title: const Text('Clear Download History', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text(
                    'Remove all completed downloads from history',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  onTap: () => _confirmClearHistory(context),
                ),
              ),

              const SizedBox(height: 24),

              // About
              _sectionTitle(context, 'About'),
              const SizedBox(height: 8),

              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info_outline, color: AppColors.primary),
                      title: Text('Quicklify', style: TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text(
                        'Version 1.0.0',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    const ListTile(
                      leading: Icon(Icons.code, color: AppColors.primary),
                      title: Text('Powered by Cobalt', style: TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text(
                        'Open-source video download engine',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  static Widget _setupStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Future<void> _launchRailway() async {
    final uri = Uri.parse(ApiConstants.railwayDeployUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showQualityPicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: AppConstants.videoQualities.map((quality) {
          return ListTile(
            title: Text(
              AppConstants.qualityLabels[quality] ?? quality,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            trailing: settings.defaultQuality == quality
                ? const Icon(Icons.check, color: AppColors.primary)
                : null,
            onTap: () {
              settings.setDefaultQuality(quality);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showModePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: AppConstants.downloadModes.entries.map((entry) {
          return ListTile(
            title: Text(entry.value, style: const TextStyle(color: AppColors.textPrimary)),
            trailing: settings.defaultMode == entry.key
                ? const Icon(Icons.check, color: AppColors.primary)
                : null,
            onTap: () {
              settings.setDefaultMode(entry.key);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showAudioFormatPicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: AppConstants.audioFormats.map((format) {
          return ListTile(
            title: Text(format.toUpperCase(), style: const TextStyle(color: AppColors.textPrimary)),
            trailing: settings.defaultAudioFormat == format
                ? const Icon(Icons.check, color: AppColors.primary)
                : null,
            onTap: () {
              settings.setDefaultAudioFormat(format);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showCobaltUrlEditor(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.cobaltBaseUrl);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cobalt API URL', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your Cobalt server URL.\n\n'
              'Example: https://cobalt-production-xxxx.up.railway.app',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'https://your-cobalt-server.up.railway.app',
              ),
            ),
          ],
        ),
        actions: [
          if (settings.cobaltBaseUrl.isNotEmpty)
            TextButton(
              onPressed: () {
                settings.resetCobaltBaseUrl();
                Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
          ElevatedButton(
            onPressed: () {
              var url = controller.text.trim();
              if (url.isNotEmpty) {
                // Remove trailing slash
                if (url.endsWith('/')) {
                  url = url.substring(0, url.length - 1);
                }
                settings.setCobaltBaseUrl(url);
                Fluttertoast.showToast(msg: 'Server URL saved!');
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear History', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will remove all completed downloads from history. Downloaded files will not be deleted.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              context.read<DownloadsProvider>().clearHistory();
              Navigator.pop(context);
              Fluttertoast.showToast(msg: 'History cleared');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
