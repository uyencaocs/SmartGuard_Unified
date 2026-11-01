import 'package:flutter/material.dart';

class AppTheme {
  // Cute Capybara Security Brand Colors (Matching User Design)
  static const Color creamBg = Color(0xFFFFFBF5);          // Warm pastel cream background
  static const Color cardWhite = Color(0xFFFFFFFF);        // Pure card white
  static const Color borderWarm = Color(0xFFF0EAE1);       // Soft warm border
  static const Color borderSoft = Color(0xFFE8E1D5);       // Subtle divider border

  // Accent Colors
  static const Color coralPink = Color(0xFFFF6B4A);        // Coral Pink / Orange primary
  static const Color royalPurple = Color(0xFF7C3AED);      // Royal Violet / Purple
  static const Color deepPurple = Color(0xFF5B44BA);       // Deep Purple button
  static const Color primaryNavy = Color(0xFF26384F);      // Primary Navy uniform
  static const Color securityBlue = Color(0xFF405C83);     // Security Blue
  static const Color lightBlue = Color(0xFFE3F2FD);        // Light Blue pill

  // Text Colors
  static const Color headingDark = Color(0xFF2D2327);      // Warm dark heading text
  static const Color textDark = Color(0xFF26384F);         // Primary navy text
  static const Color secondaryText = Color(0xFF8E828A);    // Soft warm secondary text
  static const Color mutedText = Color(0xFFA59B9F);        // Muted gray/pink text

  // Status & Alarm Colors
  static const Color statusArmed = Color(0xFF2E7D32);      // Shield Green
  static const Color statusArmedBg = Color(0xFFE8F5E9);    // Soft Green tint
  static const Color statusWarning = Color(0xFFF59E0B);    // Amber Warning
  static const Color statusWarningBg = Color(0xFFFEF3C7);  // Soft Amber tint
  static const Color statusAlarm = Color(0xFFE53935);      // Crimson Alert
  static const Color statusAlarmBg = Color(0xFFFFEBEE);    // Soft Red tint
  static const Color statusOffline = Color(0xFF8E828A);    // Muted Offline

  // Gradient Presets
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [coralPink, royalPurple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF6B46C1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shieldGreenGradient = LinearGradient(
    colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Backward-compatibility aliases
  static const Color paleBlueBg = creamBg;
  static const Color white = cardWhite;
  static const Color softGray = Color(0xFFF7F4EF);
  static const Color borderGray = borderWarm;
  static const Color primaryBlue = primaryNavy;
  static const Color accentCyan = royalPurple;
  static const Color darkBackground = Color(0xFF1E1B24);
  static const Color surfaceCard = cardWhite;
  static const Color surfaceCardLight = cardWhite;
  static const Color textPrimary = headingDark;
  static const Color textSecondary = secondaryText;
  static ThemeData get darkTheme => lightTheme;

  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: coralPink,
      brightness: Brightness.light,
      primary: coralPink,
      secondary: royalPurple,
      surface: cardWhite,
      error: statusAlarm,
    ),
    scaffoldBackgroundColor: creamBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: creamBg,
      foregroundColor: headingDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: headingDark,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: headingDark),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: const BorderSide(color: borderWarm, width: 1.2),
      ),
      color: cardWhite,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: deepPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: deepPurple,
        side: const BorderSide(color: deepPurple, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFCFAF7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderWarm),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderWarm),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: royalPurple, width: 2),
      ),
      labelStyle: const TextStyle(color: secondaryText, fontSize: 14),
    ),
  );
}
