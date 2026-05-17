import 'package:flutter/material.dart';

class FluxColors {
  FluxColors._();

  // Primary accent
  static const Color cyan = Color(0xFF00E5FF);
  static const Color cyanDark = Color(0xFF00B8D4);
  static const Color cyanGlow = Color(0xFF00E5FF);

  // Progress ring gradient
  static const Color progressStart = Color(0xFF00E5FF);
  static const Color progressEnd = Color(0xFF00E676);

  // Backgrounds
  static const Color bg = Color(0xFF0D0D12);
  static const Color bgLight = Color(0xFF141420);
  static const Color surface = Color(0xFF1A1A28);
  static const Color surfaceLight = Color(0xFF222232);
  static const Color card = Color(0xFF1C1C2E);

  // Text
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF8888A0);
  static const Color textMuted = Color(0xFF555570);

  // Status
  static const Color success = Color(0xFF00E676);
  static const Color error = Color(0xFFFF5252);

  // Step indicators
  static const Color stepDone = Color(0xFF00E676);
  static const Color stepActive = Color(0xFF00E5FF);
  static const Color stepPending = Color(0xFF444460);

  // Borders
  static const Color border = Color(0xFF2A2A40);
  static const Color borderCyan = Color(0x4000E5FF);

  // Platform colors (same as v1)
  static const Color youtube = Color(0xFFFF0000);
  static const Color tiktok = Color(0xFFEE1D52);
  static const Color facebook = Color(0xFF1877F2);
  static const Color instagram = Color(0xFFE4405F);
  static const Color twitter = Color(0xFF1DA1F2);
  static const Color reddit = Color(0xFFFF4500);

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
      default:
        return cyan;
    }
  }
}

class FluxTheme {
  FluxTheme._();

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: FluxColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: FluxColors.cyan,
          surface: FluxColors.surface,
          error: FluxColors.error,
        ),
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: FluxColors.textPrimary,
          ),
          iconTheme: IconThemeData(color: FluxColors.textPrimary),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: FluxColors.bg,
          indicatorColor: FluxColors.cyan.withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: FluxColors.cyan,
              );
            }
            return const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: FluxColors.textMuted,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: FluxColors.cyan, size: 24);
            }
            return const IconThemeData(color: FluxColors.textMuted, size: 24);
          }),
        ),
      );
}
