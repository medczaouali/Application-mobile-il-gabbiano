import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color _primary = Color(0xFF42A5F5); // bleu ciel
  static const Color _secondary = Color(0xFF90CAF9); // bleu clair
  static const Color _accent = Color(0xFFFBC02D); // doré
  static const Color _background = Color(0xFFF5F9FF); // bleu très pâle
  static const Color _surface = Color(0xFFFFFFFF); // blanc pur
  static const Color _title = Color(0xFF0D47A1); // bleu profond
  static const Color _text = Color(0xFF1E3A5F); // bleu gris
  static const Color _error = Color(0xFFD32F2F);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: _background,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: _primary,
      onPrimary: Colors.white,
      secondary: _secondary,
      onSecondary: Colors.white,
      background: _background,
      onBackground: _text,
      surface: _surface,
      onSurface: _text,
      error: _error,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 2,
      titleTextStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
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
      labelLarge: GoogleFonts.poppins(
        color: _accent,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 2,
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
      style: TextButton.styleFrom(foregroundColor: _primary, textStyle: GoogleFonts.poppins()),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _secondary, width: 2)),
      labelStyle: GoogleFonts.poppins(color: _text),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _accent,
      foregroundColor: _title,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: _surface),
    iconTheme: const IconThemeData(color: _primary),
  // scaffoldBackgroundColor already set above via ThemeData property
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
