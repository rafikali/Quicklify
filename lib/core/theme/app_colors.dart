import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary gradient
  static const Color primary = Color(0xFF00E5FF);
  static const Color primaryDark = Color(0xFF00B8D4);
  static const Color primaryDeep = Color(0xFF0097A7);
  static const Color primaryLight = Color(0xFF80DEEA);

  // Secondary / accent
  static const Color accent = Color(0xFF7C4DFF);
  static const Color accentLight = Color(0xFFB388FF);

  // Neon glow
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonPurple = Color(0xFF7C4DFF);
  static const Color neonPink = Color(0xFFFF4081);

  // Background layers
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceLight = Color(0xFF1A1A28);
  static const Color surfaceElevated = Color(0xFF222236);
  static const Color card = Color(0xFF16162A);
  static const Color cardHover = Color(0xFF1E1E38);

  // Glass effect
  static const Color glassBorder = Color(0x20FFFFFF);
  static const Color glassBackground = Color(0x0AFFFFFF);
  static const Color glassSurface = Color(0x14FFFFFF);

  // Text
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFF9E9EB8);
  static const Color textHint = Color(0xFF5C5C7A);
  static const Color textMuted = Color(0xFF44445A);

  // Status
  static const Color success = Color(0xFF00E676);
  static const Color successDark = Color(0xFF00C853);
  static const Color error = Color(0xFFFF5252);
  static const Color errorDark = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFFAB40);
  static const Color info = Color(0xFF448AFF);

  // Platform colors
  static const Color youtube = Color(0xFFFF0000);
  static const Color tiktok = Color(0xFFEE1D52);
  static const Color facebook = Color(0xFF1877F2);
  static const Color instagram = Color(0xFFE4405F);
  static const Color twitter = Color(0xFF1DA1F2);
  static const Color reddit = Color(0xFFFF4500);
  static const Color vimeo = Color(0xFF1AB7EA);
  static const Color twitch = Color(0xFF9146FF);
  static const Color snapchat = Color(0xFFFFFC00);
  static const Color pinterest = Color(0xFFE60023);
  static const Color soundcloud = Color(0xFFFF5500);
  static const Color dailymotion = Color(0xFF0066DC);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF12121A), Color(0xFF1A1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF), Color(0xFFFF4081)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient downloadGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF448AFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static Color getPlatformColor(String platform) {
    switch (platform) {
      case 'youtube':
        return youtube;
      case 'tiktok':
        return tiktok;
      case 'facebook':
        return facebook;
      case 'instagram':
        return instagram;
      case 'twitter':
        return twitter;
      case 'reddit':
        return reddit;
      case 'vimeo':
        return vimeo;
      case 'twitch':
        return twitch;
      case 'snapchat':
        return snapchat;
      case 'pinterest':
        return pinterest;
      case 'soundcloud':
        return soundcloud;
      case 'dailymotion':
        return dailymotion;
      default:
        return primary;
    }
  }

  static LinearGradient getPlatformGradient(String platform) {
    final color = getPlatformColor(platform);
    return LinearGradient(
      colors: [color, color.withValues(alpha: 0.6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
