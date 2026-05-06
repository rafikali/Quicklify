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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Platform icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    UrlValidator.getPlatformIcon(item.platform),
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

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
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.platform.toUpperCase()} - ${item.quality}p - ${DateFormat.yMd().add_jm().format(item.createdAt)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge
                _buildStatusBadge(),
              ],
            ),

            // Progress bar for active downloads
            if (item.isActive) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.progress / 100,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          item.isPaused ? AppColors.warning : AppColors.primary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${item.progress}%',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (item.isPaused)
                    _actionButton(
                      context,
                      icon: Icons.play_arrow,
                      label: 'Resume',
                      onTap: () => context.read<DownloadsProvider>().resumeDownload(item),
                    )
                  else if (item.status == 1)
                    _actionButton(
                      context,
                      icon: Icons.pause,
                      label: 'Pause',
                      onTap: () => context.read<DownloadsProvider>().pauseDownload(item),
                    ),
                  const SizedBox(width: 8),
                  _actionButton(
                    context,
                    icon: Icons.close,
                    label: 'Cancel',
                    color: AppColors.error,
                    onTap: () => context.read<DownloadsProvider>().cancelDownload(item),
                  ),
                ],
              ),
            ],

            // Actions for failed downloads
            if (item.isFailed) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _actionButton(
                    context,
                    icon: Icons.refresh,
                    label: 'Retry',
                    onTap: () => context.read<DownloadsProvider>().retryDownload(item),
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    context,
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    color: AppColors.error,
                    onTap: () => context.read<DownloadsProvider>().removeDownload(item),
                  ),
                ],
              ),
            ],

            // Actions for completed downloads
            if (item.isCompleted) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _actionButton(
                    context,
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    color: AppColors.error,
                    onTap: () => context.read<DownloadsProvider>().removeDownload(item),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    switch (item.status) {
      case 1:
        color = AppColors.primary;
        break;
      case 2:
        color = AppColors.success;
        break;
      case 3:
        color = AppColors.error;
        break;
      case 4:
        color = AppColors.warning;
        break;
      default:
        color = AppColors.textHint;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        item.statusText,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color ?? AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
