import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the B2B (designer / manufacturer) workspace.
///
/// A classic jewellery-house look built on the brand: deep emerald with an
/// antique-gold accent on warm ivory, PT Serif for headings and Poppins for
/// everything else, hairline borders and soft, low shadows.
class B2BColors {
  B2BColors._();

  // Brand
  static const Color primary = Color(0xFF0F5A45); // deep emerald
  static const Color primaryDeep = Color(0xFF0A3F31);
  static const Color primarySoft = Color(0xFFE7F0EC); // tinted fills
  static const Color primaryTint = Color(0xFFCFE2DA); // borders on tints
  static const Color gold = Color(0xFFB08D57); // antique gold
  static const Color goldSoft = Color(0xFFF6EFE3);

  // Neutrals (warm, not blue-grey)
  static const Color canvas = Color(0xFFFAF8F4); // page background
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF4F1EA); // subtle panels
  static const Color border = Color(0xFFE8E2D6); // hairlines
  static const Color ink = Color(0xFF1E2622); // headings / primary text
  static const Color inkSoft = Color(0xFF3F4A45);
  static const Color muted = Color(0xFF6E7872); // secondary text
  static const Color faint = Color(0xFFA3AAA5); // placeholders, icons

  // Status
  static const Color success = Color(0xFF2E7D5B);
  static const Color successSoft = Color(0xFFE6F2EC);
  static const Color warning = Color(0xFFB7791F);
  static const Color warningSoft = Color(0xFFFBF3E4);
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerSoft = Color(0xFFFBEAE9);
}

class B2BRadius {
  B2BRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
}

class B2BShadows {
  B2BShadows._();

  /// Resting card shadow: barely there, just lifts the card off the canvas.
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x0F1E2622), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x081E2622), blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// Hover / focus shadow.
  static const List<BoxShadow> lifted = [
    BoxShadow(color: Color(0x1A1E2622), blurRadius: 28, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0A1E2622), blurRadius: 6, offset: Offset(0, 2)),
  ];
}

class B2BText {
  B2BText._();

  static TextStyle serif({
    double size = 22,
    FontWeight weight = FontWeight.w700,
    Color color = B2BColors.ink,
    double? letterSpacing,
  }) =>
      GoogleFonts.ptSerif(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.2,
      );

  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = B2BColors.ink,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Small uppercase label, e.g. section eyebrows ("CATALOGUE").
  static TextStyle eyebrow({Color color = B2BColors.gold}) => GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: color,
      );
}

/// Card surface used across the B2B screens.
BoxDecoration b2bCardDecoration({
  bool lifted = false,
  Color color = B2BColors.surface,
  double radius = B2BRadius.lg,
}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: B2BColors.border),
      boxShadow: lifted ? B2BShadows.lifted : B2BShadows.soft,
    );

class B2BTheme {
  B2BTheme._();

  /// The B2B theme, derived from the app theme so anything not overridden
  /// here still follows the rest of the app.
  static ThemeData build(ThemeData base) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: B2BColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: B2BColors.primary,
      onPrimary: Colors.white,
      primaryContainer: B2BColors.primarySoft,
      onPrimaryContainer: B2BColors.primaryDeep,
      secondary: B2BColors.gold,
      onSecondary: Colors.white,
      secondaryContainer: B2BColors.goldSoft,
      surface: B2BColors.surface,
      onSurface: B2BColors.ink,
      onSurfaceVariant: B2BColors.muted,
      surfaceContainerLowest: B2BColors.surface,
      surfaceContainerLow: B2BColors.canvas,
      surfaceContainer: B2BColors.surfaceAlt,
      surfaceContainerHigh: B2BColors.surfaceAlt,
      outline: B2BColors.border,
      outlineVariant: B2BColors.border,
      error: B2BColors.danger,
    );

    final sans = GoogleFonts.poppinsTextTheme(base.textTheme);
    final textTheme = sans
        .copyWith(
          displayLarge: B2BText.serif(size: 48),
          displayMedium: B2BText.serif(size: 38),
          displaySmall: B2BText.serif(size: 30),
          headlineLarge: B2BText.serif(size: 28),
          headlineMedium: B2BText.serif(size: 24),
          headlineSmall: B2BText.serif(size: 22),
          titleLarge: B2BText.serif(size: 19),
          titleMedium: B2BText.sans(size: 15, weight: FontWeight.w600),
          titleSmall: B2BText.sans(size: 13.5, weight: FontWeight.w600),
          bodyLarge: B2BText.sans(size: 15, height: 1.5),
          bodyMedium: B2BText.sans(size: 14, height: 1.5),
          bodySmall: B2BText.sans(size: 12, color: B2BColors.muted, height: 1.45),
          labelLarge: B2BText.sans(size: 14, weight: FontWeight.w600),
          labelMedium: B2BText.sans(size: 12.5, weight: FontWeight.w500),
          labelSmall: B2BText.sans(size: 11, weight: FontWeight.w500),
        )
        .apply(bodyColor: B2BColors.ink, displayColor: B2BColors.ink);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(B2BRadius.md),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(B2BRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      colorScheme: colorScheme,
      primaryColor: B2BColors.primary,
      scaffoldBackgroundColor: B2BColors.canvas,
      canvasColor: B2BColors.canvas,
      textTheme: textTheme,
      dividerColor: B2BColors.border,
      splashFactory: InkSparkle.splashFactory,
      // Smooth fade-through between routes on every platform.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: B2BColors.surface,
        foregroundColor: B2BColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: B2BText.serif(size: 20),
        iconTheme: const IconThemeData(color: B2BColors.inkSoft),
        actionsIconTheme: const IconThemeData(color: B2BColors.primary),
        shape: const Border(bottom: BorderSide(color: B2BColors.border)),
      ),
      cardTheme: CardThemeData(
        color: B2BColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(B2BRadius.lg),
          side: const BorderSide(color: B2BColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: B2BColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: B2BColors.primaryTint,
          padding: buttonPadding,
          shape: shape,
          textStyle: B2BText.sans(size: 14, weight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: B2BColors.primary,
          foregroundColor: Colors.white,
          padding: buttonPadding,
          shape: shape,
          elevation: 0,
          textStyle: B2BText.sans(size: 14, weight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: B2BColors.primary,
          side: const BorderSide(color: B2BColors.primaryTint),
          padding: buttonPadding,
          shape: shape,
          textStyle: B2BText.sans(size: 14, weight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: B2BColors.primary,
          shape: shape,
          textStyle: B2BText.sans(size: 14, weight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: B2BColors.inkSoft),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: B2BColors.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: B2BText.sans(size: 14, color: B2BColors.faint),
        labelStyle: B2BText.sans(size: 14, color: B2BColors.muted),
        floatingLabelStyle:
            B2BText.sans(size: 13, color: B2BColors.primary, weight: FontWeight.w500),
        prefixIconColor: B2BColors.faint,
        suffixIconColor: B2BColors.faint,
        border: inputBorder(B2BColors.border),
        enabledBorder: inputBorder(B2BColors.border),
        focusedBorder: inputBorder(B2BColors.primary, 1.4),
        errorBorder: inputBorder(B2BColors.danger),
        focusedErrorBorder: inputBorder(B2BColors.danger, 1.4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: B2BColors.surface,
        selectedColor: B2BColors.primarySoft,
        disabledColor: B2BColors.surfaceAlt,
        side: const BorderSide(color: B2BColors.border),
        labelStyle: B2BText.sans(size: 13, weight: FontWeight.w500),
        secondaryLabelStyle:
            B2BText.sans(size: 13, weight: FontWeight.w600, color: B2BColors.primaryDeep),
        checkmarkColor: B2BColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(B2BRadius.xl),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: B2BColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: B2BColors.primarySoft,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(B2BRadius.md),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected)
                  ? B2BColors.primary
                  : B2BColors.faint,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => B2BText.sans(
              size: 11.5,
              weight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? B2BColors.primary
                  : B2BColors.muted,
            )),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: B2BColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(B2BRadius.xl),
        ),
        titleTextStyle: B2BText.serif(size: 20),
        contentTextStyle: B2BText.sans(size: 14, color: B2BColors.inkSoft, height: 1.5),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: B2BColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: B2BColors.surface,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: B2BColors.ink,
        contentTextStyle: B2BText.sans(size: 13.5, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(B2BRadius.md),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: B2BColors.border,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? B2BColors.primary : null),
        side: const BorderSide(color: B2BColors.faint, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? B2BColors.primary : null),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: B2BColors.primary,
        inactiveTrackColor: B2BColors.primaryTint,
        thumbColor: B2BColors.primary,
        overlayColor: Color(0x1F0F5A45),
        valueIndicatorColor: B2BColors.primaryDeep,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: B2BColors.primary,
        linearTrackColor: B2BColors.primarySoft,
        circularTrackColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: B2BColors.primary,
        unselectedLabelColor: B2BColors.muted,
        indicatorColor: B2BColors.primary,
        dividerColor: B2BColors.border,
        labelStyle: B2BText.sans(size: 14, weight: FontWeight.w600),
        unselectedLabelStyle: B2BText.sans(size: 14, weight: FontWeight.w500),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: B2BColors.primary,
        titleTextStyle: B2BText.sans(size: 14.5, weight: FontWeight.w500),
        subtitleTextStyle: B2BText.sans(size: 12.5, color: B2BColors.muted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(B2BRadius.md),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: B2BColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(B2BRadius.md),
          side: const BorderSide(color: B2BColors.border),
        ),
        textStyle: B2BText.sans(size: 14),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: B2BColors.ink,
          borderRadius: BorderRadius.circular(B2BRadius.sm),
        ),
        textStyle: B2BText.sans(size: 12, color: Colors.white),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle:
            B2BText.sans(size: 12.5, weight: FontWeight.w600, color: B2BColors.muted),
        dataTextStyle: B2BText.sans(size: 13.5),
        dividerThickness: 1,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: B2BColors.primarySoft,
          selectedForegroundColor: B2BColors.primaryDeep,
          side: const BorderSide(color: B2BColors.border),
        ),
      ),
    );
  }
}
