import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/url_validator.dart';

class QualitySelector extends StatefulWidget {
  final String url;
  final String platform;
  final void Function(String quality, String downloadMode, String audioFormat)
      onDownload;

  const QualitySelector({
    super.key,
    required this.url,
    required this.platform,
    required this.onDownload,
  });

  @override
  State<QualitySelector> createState() => _QualitySelectorState();
}

class _QualitySelectorState extends State<QualitySelector> {
  String _selectedQuality = '1080';
  String _downloadMode = 'auto';
  String _audioFormat = 'mp3';

  @override
  Widget build(BuildContext context) {
    final platformColor = AppColors.getPlatformColor(widget.platform);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(
          top: BorderSide(color: AppColors.glassBorder),
          left: BorderSide(color: AppColors.glassBorder),
          right: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Platform header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: platformColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        UrlValidator.getPlatformIcon(widget.platform),
                        color: platformColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Download Options',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'From ${widget.platform[0].toUpperCase()}${widget.platform.substring(1)}',
                          style: TextStyle(
                            color: platformColor.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Download mode selector
                _sectionLabel('Download Mode'),
                const SizedBox(height: 10),
                Row(
                  children: AppConstants.downloadModes.entries.map((entry) {
                    final isSelected = _downloadMode == entry.key;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: entry.key != AppConstants.downloadModes.keys.last
                              ? 8
                              : 0,
                        ),
                        child: _buildModeChip(
                          label: entry.value,
                          isSelected: isSelected,
                          onTap: () =>
                              setState(() => _downloadMode = entry.key),
                          icon: _getModeIcon(entry.key),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                // Quality selector (only for video modes)
                if (_downloadMode != 'audio') ...[
                  _sectionLabel('Video Quality'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppConstants.videoQualities.map((quality) {
                      final isSelected = _selectedQuality == quality;
                      return _buildQualityChip(
                        quality: quality,
                        label:
                            AppConstants.qualityLabels[quality] ?? '${quality}p',
                        isSelected: isSelected,
                        onTap: () =>
                            setState(() => _selectedQuality = quality),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                ],

                // Audio format selector (only for audio mode)
                if (_downloadMode == 'audio') ...[
                  _sectionLabel('Audio Format'),
                  const SizedBox(height: 10),
                  Row(
                    children: AppConstants.audioFormats.map((format) {
                      final isSelected = _audioFormat == format;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right:
                                format != AppConstants.audioFormats.last ? 8 : 0,
                          ),
                          child: _buildModeChip(
                            label: format.toUpperCase(),
                            isSelected: isSelected,
                            onTap: () =>
                                setState(() => _audioFormat = format),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                ],

                // Download button
                SizedBox(
                  height: 54,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        widget.onDownload(
                          _selectedQuality,
                          _downloadMode,
                          _audioFormat,
                        );
                      },
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [platformColor, platformColor.withValues(alpha: 0.75)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: platformColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download_rounded,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              _downloadMode == 'audio'
                                  ? 'Download Audio'
                                  : 'Download Video',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
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
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildModeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityChip({
    required String quality,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isHD = int.tryParse(quality) != null && int.parse(quality) >= 720;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
            if (isHD) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'HD',
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getModeIcon(String mode) {
    switch (mode) {
      case 'auto':
        return Icons.videocam_rounded;
      case 'audio':
        return Icons.audiotrack_rounded;
      case 'mute':
        return Icons.videocam_off_rounded;
      default:
        return Icons.download_rounded;
    }
  }
}
