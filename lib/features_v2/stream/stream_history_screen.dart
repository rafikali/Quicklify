import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/utils/url_validator.dart';
import '../../features/downloads/downloads_provider.dart';
import '../../features/downloads/models/download_item.dart';
import '../capture/edit_caption_screen.dart';
import '../theme/flux_theme.dart';

const _videoExtensions = {'.mp4', '.mkv', '.webm', '.mov', '.m4v', '.3gp'};

bool _isVideoFilename(String filename) {
  final lower = filename.toLowerCase();
  final dot = lower.lastIndexOf('.');
  if (dot < 0) return false;
  return _videoExtensions.contains(lower.substring(dot));
}

class StreamHistoryScreen extends StatefulWidget {
  const StreamHistoryScreen({super.key});

  @override
  State<StreamHistoryScreen> createState() => _StreamHistoryScreenState();
}

class _StreamHistoryScreenState extends State<StreamHistoryScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FluxColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.history, color: FluxColors.cyan, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Stream History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: FluxColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: FluxColors.textSecondary),
                    color: FluxColors.surface,
                    onSelected: (val) {
                      if (val == 'clear') {
                        context.read<DownloadsProvider>().clearHistory();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'clear',
                        child: Text('Clear history',
                            style: TextStyle(color: FluxColors.textPrimary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(
                    color: FluxColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search streams...',
                  hintStyle: const TextStyle(color: FluxColors.textMuted),
                  prefixIcon: const Icon(Icons.search,
                      color: FluxColors.textMuted, size: 20),
                  filled: true,
                  fillColor: FluxColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // List
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final provider = context.watch<DownloadsProvider>();
    var items = provider.allDownloads;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      items = items
          .where((d) =>
              d.filename.toLowerCase().contains(q) ||
              d.platform.toLowerCase().contains(q))
          .toList();
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_download_outlined,
                size: 56, color: FluxColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text(
              'No streams yet',
              style: TextStyle(color: FluxColors.textMuted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // Group by date
    final groups = <String, List<DownloadItem>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final item in items) {
      final itemDate = DateTime(
          item.createdAt.year, item.createdAt.month, item.createdAt.day);
      final diff = today.difference(itemDate).inDays;
      String label;
      if (diff == 0) {
        label = 'Today';
      } else if (diff == 1) {
        label = 'Yesterday';
      } else if (diff < 7) {
        label = '$diff days ago';
      } else {
        label = DateFormat('MMM d, yyyy').format(item.createdAt);
      }
      groups.putIfAbsent(label, () => []).add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: groups.length,
      itemBuilder: (context, groupIndex) {
        final label = groups.keys.elementAt(groupIndex);
        final groupItems = groups[label]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FluxColors.textMuted,
                ),
              ),
            ),
            ...groupItems.map((item) => _StreamTile(item: item)),
          ],
        );
      },
    );
  }
}

class _StreamTile extends StatelessWidget {
  final DownloadItem item;

  const _StreamTile({required this.item});

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final platformColor = FluxColors.getPlatformColor(item.platform);
    final platformLabel =
        item.platform[0].toUpperCase() + item.platform.substring(1);
    final icon = UrlValidator.getPlatformIcon(item.platform);
    final sizeStr = _formatSize(item.fileSize);
    final title = item.filename
        .replaceAll(RegExp(r'\.\w+$'), '')
        .replaceAll(RegExp(r'\s*\(\d+p\)\s*$'), '');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FluxColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FluxColors.border),
      ),
      child: Row(
        children: [
          // Thumbnail / icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: platformColor.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: platformColor, size: 22),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FluxColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      platformLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: platformColor,
                      ),
                    ),
                    if (item.quality.isNotEmpty) ...[
                      const Text(' \u2022 ',
                          style: TextStyle(
                              color: FluxColors.textMuted, fontSize: 12)),
                      Text(
                        item.quality.endsWith('p')
                            ? item.quality
                            : '${item.quality}p',
                        style: const TextStyle(
                            fontSize: 12, color: FluxColors.textSecondary),
                      ),
                    ],
                    if (sizeStr.isNotEmpty) ...[
                      const Text(' \u2022 ',
                          style: TextStyle(
                              color: FluxColors.textMuted, fontSize: 12)),
                      Text(
                        sizeStr,
                        style: const TextStyle(
                            fontSize: 12, color: FluxColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Status / actions
          if (item.isActive)
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: item.progress > 0 ? item.progress / 100 : null,
                strokeWidth: 2.5,
                color: FluxColors.cyan,
              ),
            )
          else ...[
            if (item.isCompleted && _isVideoFilename(item.filename))
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: FluxColors.cyan, size: 20),
                tooltip: 'Edit caption',
                onPressed: () =>
                    EditCaptionScreen.guardAndOpen(context, item),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: FluxColors.textMuted, size: 20),
              onPressed: () {
                context.read<DownloadsProvider>().removeDownload(item);
              },
            ),
          ],
        ],
      ),
    );
  }
}
