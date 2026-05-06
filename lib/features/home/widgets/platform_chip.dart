import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_validator.dart';

class PlatformChip extends StatelessWidget {
  final String platform;
  final String label;

  const PlatformChip({
    super.key,
    required this.platform,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        UrlValidator.getPlatformIcon(platform),
        size: 18,
        color: _getPlatformColor(),
      ),
      label: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      backgroundColor: AppColors.surfaceLight,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Color _getPlatformColor() {
    switch (platform) {
      case 'youtube':
        return AppColors.youtube;
      case 'facebook':
        return AppColors.facebook;
      case 'instagram':
        return AppColors.instagram;
      case 'twitter':
        return AppColors.twitter;
      case 'reddit':
        return AppColors.reddit;
      default:
        return AppColors.primary;
    }
  }
}
