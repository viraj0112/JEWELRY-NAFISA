import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- YOUR GOLDEN PRIMARY COLORS (PRESERVED) ---
  static const Color lightPrimary = Color(0xFFB69121); // Dark Goldenrod
  static const Color darkPrimary = Color(0xFFDAB766);  // Gold (metallic)

  // --- PINTEREST-INSPIRED LIGHT THEME COLORS ---
  static const Color lightBackground = Color(0xFFEFEFEF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF111111);

  // --- PINTEREST-INSPIRED DARK THEME COLORS ---
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkOnSurface = Color(0xFFF1F1F1);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: lightPrimary,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightPrimary,
        surface: lightSurface,
        background: lightBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightOnSurface,
        onBackground: lightOnSurface,
      ),
      textTheme: _textTheme(lightOnSurface),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 1,
        iconTheme: IconThemeData(color: lightOnSurface),
        titleTextStyle: TextStyle(
          color: lightOnSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      // FIX: Changed CardTheme to CardThemeData
      cardTheme: CardThemeData(
        elevation: 1,
        color: lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(lightPrimary, Colors.white),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: darkPrimary,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkPrimary,
        surface: darkSurface,
        background: darkBackground,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: darkOnSurface,
        onBackground: darkOnSurface,
      ),
      textTheme: _textTheme(darkOnSurface),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 1,
        iconTheme: IconThemeData(color: darkOnSurface),
        titleTextStyle: TextStyle(
          color: darkOnSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      // FIX: Changed CardTheme to CardThemeData
      cardTheme: CardThemeData(
        elevation: 1,
        color: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(darkPrimary, Colors.black),
    );
  }

  // --- HELPER METHODS (UNCHANGED) ---
  static TextTheme _textTheme(Color color) {
    return TextTheme(
      displayLarge: GoogleFonts.ptSerif(
        color: color,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: GoogleFonts.ptSerif(
        color: color,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.poppins(
        color: color,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.poppins(color: color, fontSize: 16),
      bodyMedium: GoogleFonts.poppins(color: color, fontSize: 14),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(
    Color background,
    Color foreground,
  ) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}