import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../features/downloads/downloads_provider.dart';
import '../../features/settings/settings_provider.dart';
import '../theme/flux_theme.dart';

class SystemScreenV2 extends StatelessWidget {
  const SystemScreenV2({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: FluxColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            // Header
            const Row(
              children: [
                Icon(Icons.settings_outlined, color: FluxColors.cyan, size: 24),
                SizedBox(width: 12),
                Text(
                  'System',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: FluxColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Server ──
            _sectionLabel('Server'),
            _tile(
              icon: Icons.cloud_outlined,
              title: 'Cobalt API',
              subtitle: settings.cobaltBaseUrl.isEmpty
                  ? 'Not configured'
                  : settings.cobaltBaseUrl,
              onTap: () => _editUrl(
                context,
                title: 'Cobalt API URL',
                current: settings.cobaltBaseUrl,
                onSave: settings.setCobaltBaseUrl,
              ),
            ),
            _tile(
              icon: Icons.smart_display_outlined,
              title: 'YouTube API',
              subtitle: settings.youtubeApiUrl.isEmpty
                  ? 'Not configured'
                  : settings.youtubeApiUrl,
              onTap: () => _editUrl(
                context,
                title: 'YouTube API URL',
                current: settings.youtubeApiUrl,
                onSave: settings.setYoutubeApiUrl,
              ),
            ),
            const SizedBox(height: 20),

            // ── Defaults ──
            _sectionLabel('Defaults'),
            _tile(
              icon: Icons.high_quality_outlined,
              title: 'Quality',
              subtitle: '${settings.defaultQuality}p',
              onTap: () => _showPicker(
                context,
                title: 'Default Quality',
                options: AppConstants.videoQualities,
                current: settings.defaultQuality,
                labelBuilder: (v) => '${v}p',
                onSelect: settings.setDefaultQuality,
              ),
            ),
            _tile(
              icon: Icons.tune,
              title: 'Mode',
              subtitle: AppConstants.downloadModes[settings.defaultMode] ??
                  settings.defaultMode,
              onTap: () => _showPicker(
                context,
                title: 'Default Mode',
                options: AppConstants.downloadModes.keys.toList(),
                current: settings.defaultMode,
                labelBuilder: (v) =>
                    AppConstants.downloadModes[v] ?? v,
                onSelect: settings.setDefaultMode,
              ),
            ),
            _tile(
              icon: Icons.audiotrack_outlined,
              title: 'Audio Format',
              subtitle: settings.defaultAudioFormat.toUpperCase(),
              onTap: () => _showPicker(
                context,
                title: 'Audio Format',
                options: AppConstants.audioFormats,
                current: settings.defaultAudioFormat,
                labelBuilder: (v) => v.toUpperCase(),
                onSelect: settings.setDefaultAudioFormat,
              ),
            ),
            const SizedBox(height: 20),

            // ── Data ──
            _sectionLabel('Data'),
            _tile(
              icon: Icons.delete_sweep_outlined,
              title: 'Clear History',
              subtitle: 'Remove completed downloads',
              onTap: () {
                context.read<DownloadsProvider>().clearHistory();
              },
            ),
            const SizedBox(height: 20),

            // ── Appearance ──
            _sectionLabel('Appearance'),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: FluxColors.card,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.palette_outlined,
                          color: FluxColors.cyan, size: 20),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('V2 Interface',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: FluxColors.textPrimary)),
                            SizedBox(height: 2),
                            Text('Switch to classic UI',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: FluxColors.textSecondary)),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.useV2UI,
                        activeTrackColor: FluxColors.cyan,
                        onChanged: (v) => settings.setUseV2UI(v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── About ──
            _sectionLabel('About'),
            _tile(
              icon: Icons.info_outline,
              title: 'Quicklify',
              subtitle: 'v2.0 \u2022 Parallel streaming engine',
            ),
            _tile(
              icon: Icons.open_in_new,
              title: 'Deploy Cobalt Server',
              subtitle: 'Free on Railway',
              onTap: () {
                launchUrl(Uri.parse(ApiConstants.railwayDeployUrl),
                    mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: FluxColors.textMuted,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: FluxColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: FluxColors.cyan, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: FluxColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: FluxColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right,
                      color: FluxColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editUrl(
    BuildContext context, {
    required String title,
    required String current,
    required Future<void> Function(String) onSave,
  }) {
    final controller = TextEditingController(text: current);
    showModalBottomSheet(
      context: context,
      backgroundColor: FluxColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: FluxColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: FluxColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: const TextStyle(color: FluxColors.textMuted),
                filled: true,
                fillColor: FluxColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onSave(controller.text.trim());
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FluxColors.cyan,
                  foregroundColor: FluxColors.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String current,
    required String Function(String) labelBuilder,
    required Future<void> Function(String) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FluxColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: FluxColors.textPrimary)),
            const SizedBox(height: 16),
            ...options.map((opt) {
              final selected = opt == current;
              return ListTile(
                dense: true,
                title: Text(
                  labelBuilder(opt),
                  style: TextStyle(
                    color: selected
                        ? FluxColors.cyan
                        : FluxColors.textPrimary,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check, color: FluxColors.cyan, size: 18)
                    : null,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onTap: () {
                  onSelect(opt);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
