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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          AppColors.accent.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(Icons.settings_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Server setup guide (show prominently if not configured)
              if (!hasServer) ...[
                _sectionTitle(context, 'Setup Required'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.warning.withValues(alpha: 0.08),
                        AppColors.warning.withValues(alpha: 0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.warning_amber_rounded,
                                color: AppColors.warning, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Cobalt Server Not Configured',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Quicklify needs a Cobalt server to download videos. '
                        'You can deploy your own for free in 2 minutes:',
                        style:
                            TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      _setupStep('1', 'Tap "Deploy on Railway" below'),
                      _setupStep('2', 'Create a free Railway account'),
                      _setupStep('3', 'Click Deploy — wait for it to finish'),
                      _setupStep(
                          '4', 'Copy your server URL (e.g. cobalt-xxx.up.railway.app)'),
                      _setupStep('5', 'Paste it in "Cobalt API URL" below'),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _launchRailway(),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.warning,
                                    AppColors.warning.withValues(alpha: 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.warning.withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.rocket_launch_rounded,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Deploy on Railway (Free)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // Server settings
              _sectionTitle(context, 'Server'),
              const SizedBox(height: 10),
              _buildSettingsTile(
                context,
                icon: hasServer ? Icons.check_circle_rounded : Icons.dns_rounded,
                iconColor: hasServer ? AppColors.success : AppColors.primary,
                title: 'Cobalt API URL',
                subtitle:
                    hasServer ? settings.cobaltBaseUrl : 'Not configured — tap to set up',
                subtitleColor: hasServer ? AppColors.success : AppColors.error,
                borderColor: hasServer
                    ? AppColors.success.withValues(alpha: 0.2)
                    : null,
                onTap: () => _showCobaltUrlEditor(context, settings),
              ),

              const SizedBox(height: 10),
              _buildSettingsTile(
                context,
                icon: Icons.play_circle_fill_rounded,
                iconColor: AppColors.youtube,
                title: 'YouTube',
                subtitle: 'On-device extraction — no server needed',
                subtitleColor: AppColors.success,
                borderColor: AppColors.success.withValues(alpha: 0.2),
                onTap: () {},
              ),

              const SizedBox(height: 28),

              // Download preferences
              _sectionTitle(context, 'Download Defaults'),
              const SizedBox(height: 10),
              _buildSettingsTile(
                context,
                icon: Icons.high_quality_rounded,
                title: 'Default Quality',
                subtitle: AppConstants.qualityLabels[settings.defaultQuality] ??
                    settings.defaultQuality,
                onTap: () => _showQualityPicker(context, settings),
              ),
              const SizedBox(height: 8),
              _buildSettingsTile(
                context,
                icon: Icons.videocam_rounded,
                title: 'Default Mode',
                subtitle: AppConstants.downloadModes[settings.defaultMode] ??
                    settings.defaultMode,
                onTap: () => _showModePicker(context, settings),
              ),
              const SizedBox(height: 8),
              _buildSettingsTile(
                context,
                icon: Icons.audiotrack_rounded,
                title: 'Default Audio Format',
                subtitle: settings.defaultAudioFormat.toUpperCase(),
                onTap: () => _showAudioFormatPicker(context, settings),
              ),

              const SizedBox(height: 28),

              // Data
              _sectionTitle(context, 'Data'),
              const SizedBox(height: 10),
              _buildSettingsTile(
                context,
                icon: Icons.delete_sweep_rounded,
                iconColor: AppColors.error,
                title: 'Clear Download History',
                subtitle: 'Remove all completed downloads from history',
                onTap: () => _confirmClearHistory(context),
              ),

              const SizedBox(height: 28),

              // Appearance
              _sectionTitle(context, 'Appearance'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: SwitchListTile(
                  title: const Text('V2 Interface',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('Modern capture-flow UI',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  value: settings.useV2UI,
                  activeColor: AppColors.primary,
                  onChanged: (v) => settings.setUseV2UI(v),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),

              const SizedBox(height: 28),

              // About
              _sectionTitle(context, 'About'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Column(
                  children: [
                    _buildInlineTile(
                      icon: Icons.info_outline_rounded,
                      title: 'Quicklify',
                      subtitle: 'Version 1.0.0',
                    ),
                    const Divider(
                        height: 1, indent: 56, color: AppColors.glassBorder),
                    _buildInlineTile(
                      icon: Icons.code_rounded,
                      title: 'Powered by Cobalt',
                      subtitle: 'Open-source video download engine',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    Color? subtitleColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor ?? AppColors.glassBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: iconColor ?? AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleColor ?? AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _setupStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
        ),
      ],
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
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppColors.glassBorder),
            left: BorderSide(color: AppColors.glassBorder),
            right: BorderSide(color: AppColors.glassBorder),
          ),
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: AppConstants.videoQualities.map((quality) {
            final isSelected = settings.defaultQuality == quality;
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24),
              title: Text(
                AppConstants.qualityLabels[quality] ?? quality,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 22)
                  : null,
              onTap: () {
                settings.setDefaultQuality(quality);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showModePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppColors.glassBorder),
            left: BorderSide(color: AppColors.glassBorder),
            right: BorderSide(color: AppColors.glassBorder),
          ),
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: AppConstants.downloadModes.entries.map((entry) {
            final isSelected = settings.defaultMode == entry.key;
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24),
              title: Text(
                entry.value,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 22)
                  : null,
              onTap: () {
                settings.setDefaultMode(entry.key);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAudioFormatPicker(
      BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppColors.glassBorder),
            left: BorderSide(color: AppColors.glassBorder),
            right: BorderSide(color: AppColors.glassBorder),
          ),
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: AppConstants.audioFormats.map((format) {
            final isSelected = settings.defaultAudioFormat == format;
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24),
              title: Text(
                format.toUpperCase(),
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 22)
                  : null,
              onTap: () {
                settings.setDefaultAudioFormat(format);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCobaltUrlEditor(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.cobaltBaseUrl);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cobalt API URL',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your Cobalt server URL.\n\n'
              'Example: https://cobalt-production-xxxx.up.railway.app',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
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
              child:
                  const Text('Clear', style: TextStyle(color: AppColors.error)),
            ),
          ElevatedButton(
            onPressed: () {
              var url = controller.text.trim();
              if (url.isNotEmpty) {
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
        title: const Text('Clear History',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will remove all completed downloads from history. Downloaded files will not be deleted.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              context.read<DownloadsProvider>().clearHistory();
              Navigator.pop(context);
              Fluttertoast.showToast(msg: 'History cleared');
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
