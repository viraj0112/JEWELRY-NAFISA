import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- LIGHT THEME COLORS ---
  static const Color lightBackground = Color(0xFFF9F5EF);
  static const Color lightSurface = Colors.white;
  static const Color lightPrimary = Color(0xFFC8A36A);
  static const Color lightOnSurface = Color(0xFF333333);
  static const Color lightGrey = Colors.grey;

  // --- DARK THEME COLORS ---
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkPrimary = Color(0xFFDAB766);
  static const Color darkOnSurface = Color(0xFFE0E0E0);
  static const Color darkGrey = Colors.grey;

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
        error: Colors.redAccent,
        onError: Colors.white,
      ),
      textTheme: _textTheme(lightOnSurface),
      appBarTheme: _appBarTheme(lightBackground, lightOnSurface),
      cardTheme: _cardTheme(lightSurface),
      elevatedButtonTheme: _elevatedButtonTheme(lightPrimary, Colors.white),
      navigationRailTheme: _navigationRailThemeData(lightSurface, lightPrimary),
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
        error: Colors.red,
        onError: Colors.white,
      ),
      textTheme: _textTheme(darkOnSurface),
      appBarTheme: _appBarTheme(darkSurface, darkOnSurface),
      cardTheme: _cardTheme(darkSurface),
      elevatedButtonTheme: _elevatedButtonTheme(darkPrimary, Colors.black),
      navigationRailTheme: _navigationRailThemeData(darkSurface, darkPrimary),
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

  static AppBarTheme _appBarTheme(
    Color backgroundColor,
    Color foregroundColor,
  ) {
    return AppBarTheme(
      backgroundColor: backgroundColor,
      elevation: 0,
      iconTheme: IconThemeData(color: foregroundColor),
      titleTextStyle: TextStyle(
        color: foregroundColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  static CardThemeData _cardTheme(Color cardColor) {
    return CardThemeData(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  static NavigationRailThemeData _navigationRailThemeData(
    Color backgroundColor,
    Color selectedColor,
  ) {
    return NavigationRailThemeData(
      backgroundColor: backgroundColor,
      selectedIconTheme: IconThemeData(color: selectedColor),
      unselectedIconTheme: IconThemeData(color: Colors.grey[600]),
      selectedLabelTextStyle: TextStyle(color: selectedColor),
    );
  }
}
