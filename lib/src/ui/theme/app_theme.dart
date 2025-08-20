import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Two primary fonts used across the app: PT Serif (headings) and Poppins (body)
  static ThemeData get theme {
    final base = ThemeData.light();

    final textTheme = TextTheme(
      displayLarge: GoogleFonts.ptSerif(
        fontSize: 48,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: GoogleFonts.ptSerif(
        fontSize: 36,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: GoogleFonts.ptSerif(
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.ptSerif(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: GoogleFonts.poppins(fontSize: 16),
      bodyMedium: GoogleFonts.poppins(fontSize: 14),
      bodySmall: GoogleFonts.poppins(fontSize: 12),
    );

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: const Color(0xFF2B2B2B),
        secondary: const Color(0xFFD4AF37), // subtle gold accent
      ),
      scaffoldBackgroundColor: Colors.white,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      // Keep default CardTheme or customize where needed to avoid SDK mismatch
    );
  }
}
