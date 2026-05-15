import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_validator.dart';
import '../downloads_provider.dart';
import '../models/download_item.dart';

class DownloadTile extends StatelessWidget {
  final DownloadItem item;

  const DownloadTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final platformColor = AppColors.getPlatformColor(item.platform);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isActive
              ? platformColor.withValues(alpha: 0.2)
              : AppColors.glassBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Platform icon with gradient background
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        platformColor.withValues(alpha: 0.15),
                        platformColor.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: platformColor.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Icon(
                    UrlValidator.getPlatformIcon(item.platform),
                    color: platformColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),

                // Filename and info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _infoPill(
                            '${item.platform[0].toUpperCase()}${item.platform.substring(1)}',
                            platformColor,
                          ),
                          const SizedBox(width: 6),
                          _infoPill('${item.quality}p', AppColors.textHint),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat.MMMd().add_jm().format(item.createdAt),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                // Status badge
                _buildStatusBadge(),
              ],
            ),

            // Progress bar for active downloads
            if (item.isActive) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          // Background
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          // Progress with gradient
                          FractionallySizedBox(
                            widthFactor: item.progress / 100,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: item.isPaused
                                    ? LinearGradient(
                                        colors: [
                                          AppColors.warning,
                                          AppColors.warning
                                              .withValues(alpha: 0.7),
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          platformColor,
                                          AppColors.primary,
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: (item.isPaused
                                            ? AppColors.warning
                                            : platformColor)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '${item.progress}%',
                    style: TextStyle(
                      color: item.isPaused ? AppColors.warning : platformColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (item.isPaused)
                    _actionChip(
                      context,
                      icon: Icons.play_arrow_rounded,
                      label: 'Resume',
                      color: AppColors.success,
                      onTap: () =>
                          context.read<DownloadsProvider>().resumeDownload(item),
                    )
                  else if (item.status == 1)
                    _actionChip(
                      context,
                      icon: Icons.pause_rounded,
                      label: 'Pause',
                      color: AppColors.warning,
                      onTap: () =>
                          context.read<DownloadsProvider>().pauseDownload(item),
                    ),
                  const SizedBox(width: 8),
                  _actionChip(
                    context,
                    icon: Icons.close_rounded,
                    label: 'Cancel',
                    color: AppColors.error,
                    onTap: () =>
                        context.read<DownloadsProvider>().cancelDownload(item),
                  ),
                ],
              ),
            ],

            // Actions for failed downloads
            if (item.isFailed) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _actionChip(
                    context,
                    icon: Icons.refresh_rounded,
                    label: 'Retry',
                    color: AppColors.primary,
                    onTap: () =>
                        context.read<DownloadsProvider>().retryDownload(item),
                  ),
                  const SizedBox(width: 8),
                  _actionChip(
                    context,
                    icon: Icons.delete_outline_rounded,
                    label: 'Remove',
                    color: AppColors.error,
                    onTap: () =>
                        context.read<DownloadsProvider>().removeDownload(item),
                  ),
                ],
              ),
            ],

            // Actions for completed downloads
            if (item.isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _actionChip(
                    context,
                    icon: Icons.delete_outline_rounded,
                    label: 'Remove',
                    color: AppColors.error,
                    onTap: () =>
                        context.read<DownloadsProvider>().removeDownload(item),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.withValues(alpha: 0.8),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    IconData icon;
    Color color;
    String label;

    switch (item.status) {
      case 0:
        icon = Icons.hourglass_empty_rounded;
        color = AppColors.textHint;
        label = 'Pending';
        break;
      case 1:
        icon = Icons.downloading_rounded;
        color = AppColors.primary;
        label = 'Downloading';
        break;
      case 2:
        icon = Icons.check_circle_rounded;
        color = AppColors.success;
        label = 'Done';
        break;
      case 3:
        icon = Icons.error_rounded;
        color = AppColors.error;
        label = 'Failed';
        break;
      case 4:
        icon = Icons.pause_circle_rounded;
        color = AppColors.warning;
        label = 'Paused';
        break;
      case 5:
        icon = Icons.cancel_rounded;
        color = AppColors.textHint;
        label = 'Canceled';
        break;
      default:
        icon = Icons.help_outline_rounded;
        color = AppColors.textHint;
        label = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
