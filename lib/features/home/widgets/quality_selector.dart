import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

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
    return Container(
      padding: const EdgeInsets.all(20),
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
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Download Options',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'From ${widget.platform.toUpperCase()}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Download mode selector
          Text(
            'Download Mode',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: AppConstants.downloadModes.entries.map((entry) {
              final isSelected = _downloadMode == entry.key;
              return ChoiceChip(
                label: Text(entry.value),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _downloadMode = entry.key);
                },
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceLight,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Quality selector (only for video modes)
          if (_downloadMode != 'audio') ...[
            Text(
              'Video Quality',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.videoQualities.map((quality) {
                final isSelected = _selectedQuality == quality;
                return ChoiceChip(
                  label: Text(AppConstants.qualityLabels[quality] ?? quality),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedQuality = quality);
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceLight,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Audio format selector (only for audio mode)
          if (_downloadMode == 'audio') ...[
            Text(
              'Audio Format',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AppConstants.audioFormats.map((format) {
                final isSelected = _audioFormat == format;
                return ChoiceChip(
                  label: Text(format.toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _audioFormat = format);
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceLight,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Download button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onDownload(
                  _selectedQuality,
                  _downloadMode,
                  _audioFormat,
                );
              },
              icon: const Icon(Icons.download, size: 22),
              label: Text(
                _downloadMode == 'audio' ? 'Download Audio' : 'Download Video',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
