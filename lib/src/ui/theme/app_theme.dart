import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- NEW LIGHT THEME COLORS ---
  static const Color lightBackground = Color.fromARGB(255, 213, 207, 199); // Navajo White
  static const Color lightSurface = Color(0xFFFFFFFF); // White for cards
  static const Color lightPrimary = Color(
    0xFFB69121,
  ); // Dark Goldenrod for buttons
  static const Color lightOnSurface = Color(0xFF000000); // Black for text

  // --- NEW DARK THEME COLORS ---
  static const Color darkBackground = Color(0xFF1A1A1A); // Very dark grey
  static const Color darkSurface = Color(0xFF2C2C2C); // Lighter grey for cards
  static const Color darkPrimary = Color(
    0xFFDAB766,
  ); // Gold (metallic) for buttons
  static const Color darkOnSurface = Color(0xFFF1F1F1); // Off-white for text

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: lightPrimary,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightPrimary, // Using primary color for secondary as well
        surface: lightSurface,
        onPrimary: Colors.white, // Text on top of buttons
        onSecondary: Colors.white,
        onSurface: lightOnSurface, // Main text color
      ),
      textTheme: _textTheme(lightOnSurface),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: lightOnSurface),
        titleTextStyle: TextStyle(
          color: lightOnSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // For light theme, buttons are Dark Goldenrod with white text
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
        onPrimary: Colors.black, // Text on top of buttons
        onSecondary: Colors.black,
        onSurface: darkOnSurface, // Main text color
      ),
      textTheme: _textTheme(darkOnSurface),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: darkOnSurface),
        titleTextStyle: TextStyle(
          color: darkOnSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(darkPrimary, Colors.black),
    );
  }

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
