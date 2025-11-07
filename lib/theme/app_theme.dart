import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilgabbiano/theme/brand_palette.dart';

class AppTheme {
  // Light brand mapping (keeps light background for readability, with violet accents)
  static const Color _primary = BrandPalette.brandViolet; // neon violet
  static const Color _secondary = BrandPalette.brandVioletDeep; // deep violet
  static const Color _accent = BrandPalette.brandElectric; // electric cyan accent
  static const Color _background = Color(0xFFF6F7FB); // soft cool light
  static const Color _surface = Color(0xFFFFFFFF); // white
  static const Color _title = Color(0xFF14213D); // deep blue-ish title
  static const Color _text = Color(0xFF24324D); // cool gray-blue text
  static const Color _error = Color(0xFFD32F2F);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: _background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
      primary: _primary,
      secondary: _secondary,
      surface: _surface,
      error: _error,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _surface,
      foregroundColor: _title,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w800,
        fontSize: 20,
        color: _title,
      ),
      iconTheme: IconThemeData(color: _title),
    ),
    textTheme: TextTheme(
      titleLarge: GoogleFonts.poppins(
        color: _title,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: GoogleFonts.poppins(
        color: _title,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: GoogleFonts.poppins(
        color: _text,
      ),
      labelLarge: GoogleFonts.poppins(color: _accent, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _primary, textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _secondary, width: 2)),
      labelStyle: GoogleFonts.poppins(color: _text),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: _accent, foregroundColor: _title),
    drawerTheme: const DrawerThemeData(backgroundColor: _surface),
    iconTheme: const IconThemeData(color: _primary),
  // scaffoldBackgroundColor already set above via ThemeData property
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  // Dark Theme
  // Dark brand mapping (bleu nuit focus)
  static const Color _darkPrimary = BrandPalette.brandViolet;
  static const Color _darkSecondary = BrandPalette.brandVioletDeep;
  static const Color _darkAccent = BrandPalette.brandElectric;
  static const Color _darkBackground = BrandPalette.brandNavy;
  static const Color _darkSurface = BrandPalette.brandNavyDeep;
  static const Color _darkTitle = Colors.white;
  static const Color _darkText = Color(0xFFDFE7F1);

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: _darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _darkPrimary,
      brightness: Brightness.dark,
      primary: _darkPrimary,
      secondary: _darkSecondary,
      surface: _darkSurface,
      error: Colors.redAccent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _darkSurface,
      foregroundColor: _darkText,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w800,
        fontSize: 20,
        color: _darkText,
      ),
      iconTheme: IconThemeData(color: _darkText),
    ),
    textTheme: TextTheme(
      titleLarge: GoogleFonts.poppins(
        color: _darkTitle,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: GoogleFonts.poppins(
        color: _darkTitle,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: GoogleFonts.poppins(
        color: _darkText,
      ),
      labelLarge: GoogleFonts.poppins(color: _darkAccent, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: _darkSurface,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkPrimary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _darkPrimary,
        textStyle: GoogleFonts.poppins(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _darkSecondary, width: 2),
      ),
      labelStyle: GoogleFonts.poppins(color: _darkText),
  hintStyle: GoogleFonts.poppins(color: _darkText.withValues(alpha: 0.7)),
      prefixIconColor: _darkPrimary,
      suffixIconColor: _darkPrimary,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _darkAccent,
      foregroundColor: Colors.black,
    ),
    drawerTheme: DrawerThemeData(backgroundColor: _darkSurface),
    iconTheme: IconThemeData(color: _darkPrimary),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
