import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final class CostaNorteBrand {
  static const Color royalBlue = Color(0xFF4F75B3);
  static const Color royalBlueDeep = Color(0xFF365A8E);
  static const Color royalBlueNight = Color(0xFF243449);
  static const Color gold = Color(0xFFF5B900);
  static const Color goldDeep = Color(0xFFD79F08);
  static const Color charcoal = Color(0xFF484848);
  static const Color ink = Color(0xFF273548);
  static const Color mutedInk = Color(0xFF5F6E7E);
  static const Color sand = Color(0xFFFFF7E1);
  static const Color mist = Color(0xFFF3F7FE);
  static const Color foam = Color(0xFFE7EFFC);
  static const Color line = Color(0x1F4F75B3);
  static const Color success = Color(0xFF2F7D32);
  static const Color error = Color(0xFFB3261E);

  static const LinearGradient ambientGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFFBF1), Color(0xFFF3F7FE), Color(0xFFFFF1C8)],
    stops: <double>[0.0, 0.58, 1.0],
  );

  static const LinearGradient sectionOverlay = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xF0243449), Color(0xD94F75B3), Color(0xC8F5B900)],
    stops: <double>[0.08, 0.58, 1.0],
  );

  static const LinearGradient goldAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[gold, Color(0xFFFFD65D)],
  );

  static ThemeData buildTheme() {
    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: royalBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: royalBlue,
          onPrimary: Colors.white,
          secondary: gold,
          onSecondary: charcoal,
          tertiary: goldDeep,
          surface: Colors.white,
          onSurface: ink,
          error: error,
          onError: Colors.white,
        );

    final ThemeData baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
    );

    final TextTheme montserratText = GoogleFonts.montserratTextTheme(
      baseTheme.textTheme,
    ).apply(bodyColor: ink, displayColor: ink);

    final TextTheme textTheme = montserratText.copyWith(
      displayLarge: GoogleFonts.cormorantGaramond(
        fontSize: 58,
        fontWeight: FontWeight.w700,
        height: 0.94,
        color: ink,
      ),
      displayMedium: GoogleFonts.cormorantGaramond(
        fontSize: 46,
        fontWeight: FontWeight.w700,
        height: 0.98,
        color: ink,
      ),
      headlineLarge: GoogleFonts.cormorantGaramond(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.0,
        color: ink,
      ),
      headlineMedium: GoogleFonts.cormorantGaramond(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.0,
        color: ink,
      ),
      headlineSmall: GoogleFonts.cormorantGaramond(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.02,
        color: ink,
      ),
      titleLarge: GoogleFonts.montserrat(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleMedium: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleSmall: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: mutedInk,
      ),
      bodyLarge: GoogleFonts.montserrat(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.55,
        color: mutedInk,
      ),
      bodyMedium: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.52,
        color: mutedInk,
      ),
      labelLarge: GoogleFonts.montserrat(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: ink,
      ),
      labelMedium: GoogleFonts.montserrat(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.28,
        color: mutedInk,
      ),
      bodySmall: GoogleFonts.montserrat(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: mutedInk,
      ),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: sand,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.94),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: line),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: gold.withValues(alpha: 0.22),
        selectedIconTheme: const IconThemeData(color: royalBlueDeep),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: royalBlueDeep,
        ),
        unselectedIconTheme: const IconThemeData(color: mutedInk),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: mutedInk,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: royalBlue,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: royalBlue,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: royalBlueDeep,
          backgroundColor: Colors.white.withValues(alpha: 0.72),
          side: const BorderSide(color: line),
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: gold.withValues(alpha: 0.22),
        secondarySelectedColor: gold.withValues(alpha: 0.22),
        side: const BorderSide(color: line),
        labelStyle: textTheme.labelLarge?.copyWith(color: ink),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return gold.withValues(alpha: 0.22);
            }
            return Colors.white.withValues(alpha: 0.16);
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white;
          }),
          side: const WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: Color(0x3DFFFFFF)),
          ),
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.labelLarge),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        prefixIconColor: royalBlue,
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium?.copyWith(color: mutedInk),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: goldDeep, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: line,
    );
  }
}
