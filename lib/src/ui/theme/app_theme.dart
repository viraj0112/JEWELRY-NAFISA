import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color navajoWhite = Color(0xFFFDDDAA);
  static const Color gold = Color(0xFFDAB766);
  static const Color darkGoldenrod = Color(0xFFB69121);
  static const Color goldenBrown = Color(0xFF8E6015);
  static const Color black = Color(0xFF000000);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: darkGoldenrod,
      scaffoldBackgroundColor: navajoWhite,
      colorScheme: const ColorScheme.light(
        primary: darkGoldenrod,
        secondary: gold,
        surface: navajoWhite,
        onSurface: black,
        primaryContainer: gold,
        secondaryContainer: goldenBrown,
      ),
      textTheme: _textTheme(goldenBrown),
      appBarTheme: AppBarTheme(
        backgroundColor: navajoWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: goldenBrown),
        titleTextStyle: GoogleFonts.ptSerif(
          color: goldenBrown,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(darkGoldenrod, navajoWhite),
      // Other theme properties...
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: gold,
      scaffoldBackgroundColor: black,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: darkGoldenrod,
        surface: black,
        onSurface: navajoWhite,
        primaryContainer: goldenBrown,
        secondaryContainer: gold,
      ),
      textTheme: _textTheme(navajoWhite),
      appBarTheme: AppBarTheme(
        backgroundColor: black,
        elevation: 0,
        iconTheme: const IconThemeData(color: navajoWhite),
        titleTextStyle: GoogleFonts.ptSerif(
          color: navajoWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(gold, black),
      // Other theme properties...
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
      titleLarge: GoogleFonts.ptSerif(
        color: color,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: GoogleFonts.poppins(color: color),
      bodyMedium: GoogleFonts.poppins(color: color),
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
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
    );
  }
}
