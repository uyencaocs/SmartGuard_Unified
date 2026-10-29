import 'package:flutter/material.dart';

class AppTheme {
  // --- Capybara Theme Colors ---
  static const Color primaryPurple = Color(0xFF6B4EE6);
  static const Color primaryCoral = Color(0xFFFF5E62);
  static const Color warmAmber = Color(0xFFF59E0B);
  static const Color warmCream = Color(0xFFFDF8F3);
  static const Color warmIvory = Color(0xFFFFF9F0);
  static const Color surfaceCard = Colors.white;

  // Capybara Fur & Earthy Tones
  static const Color capyBrownDark = Color(0xFF4A3423);
  static const Color capyBrown = Color(0xFF8B5A2B);
  static const Color capyBrownLight = Color(0xFFD49B6A);
  static const Color capyPeach = Color(0xFFFFE8D6);

  // Status & Security Colors
  static const Color statusGreen = Color(0xFF22C55E);     // Safe / Armed / Online
  static const Color statusGreenBg = Color(0xFFE8F8EE);
  static const Color statusWarning = Color(0xFFF59E0B);   // Motion / Noise
  static const Color statusWarningBg = Color(0xFFFEF3C7);
  static const Color statusDanger = Color(0xFFEF4444);    // Stranger / Intruder / Panic
  static const Color statusDangerBg = Color(0xFFFEE2E2);
  static const Color statusOffline = Color(0xFF94A3B8);   // Disconnected
  static const Color statusOfflineBg = Color(0xFFF1F5F9);

  // Text Colors
  static const Color textPrimary = Color(0xFF2C2420);
  static const Color textSecondary = Color(0xFF7C6F67);
  static const Color textMuted = Color(0xFFA89F98);

  // Gradient definitions matching design
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, primaryCoral],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient warmGuardGradient = LinearGradient(
    colors: [Color(0xFFFFF2E2), Color(0xFFFFE5CB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient nightGuardGradient = LinearGradient(
    colors: [Color(0xFF2E2640), Color(0xFF1B1626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenGuardGradient = LinearGradient(
    colors: [Color(0xFFEBFBF2), Color(0xFFD4F7E2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryPurple,
      primary: primaryPurple,
      secondary: primaryCoral,
      surface: surfaceCard,
      error: statusDanger,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: warmCream,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: Color(0xFFF1E7DD), width: 1),
      ),
      color: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEADBCE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEADBCE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryPurple, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: statusDanger),
      ),
    ),
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryPurple,
      primary: primaryPurple,
      secondary: primaryCoral,
      surface: const Color(0xFF261F1B),
      error: statusDanger,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF191412),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: Color(0xFF3D322B), width: 1),
      ),
      color: Color(0xFF261F1B),
    ),
  );
}
