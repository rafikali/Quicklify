import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class UrlInputCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onDownload;
  final VoidCallback onPaste;

  const UrlInputCard({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onDownload,
    required this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Paste video URL',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'https://youtube.com/watch?v=...',
                prefixIcon: const Icon(Icons.link, color: AppColors.textSecondary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste, color: AppColors.primary),
                  onPressed: onPaste,
                  tooltip: 'Paste from clipboard',
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onDownload,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text(isLoading ? 'Processing...' : 'Download'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
