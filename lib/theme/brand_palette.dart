import 'package:flutter/material.dart';

/// Centralized brand gradients and surface accents for a cohesive, modern look.
/// Adjust these colors to match your brand. All dashboards and pro cards should
/// consume this palette to keep styling consistent.
class BrandPalette {
  // Base brand colors: bleu nuit + violet néon
  static const Color brandNavy = Color(0xFF0B1020); // night blue
  static const Color brandNavyDeep = Color(0xFF121733);
  static const Color brandViolet = Color(0xFF7B2FF7); // neon violet
  static const Color brandVioletDeep = Color(0xFF5A1FEA);
  static const Color brandElectric = Color(0xFF00E5FF); // accent electric cyan

  // Header gradient (night blue -> neon violet)
  static const List<Color> headerGradient = [brandNavy, brandViolet];

  // Action card gradients (harmonized blues/purples)
  static const List<Color> menuGradient = [Color(0xFF3A0CA3), Color(0xFF7209B7)];
  static const List<Color> reservationsGradient = [Color(0xFF0F2027), Color(0xFF203A43)];
  static const List<Color> usersGradient = [Color(0xFF240046), Color(0xFF5A189A)];
  static const List<Color> ordersGradient = [Color(0xFF1B2A49), brandViolet];
  static const List<Color> reviewsGradient = [Color(0xFF5A1FEA), Color(0xFF9D4EDD)];
  static const List<Color> complaintsGradient = [Color(0xFF2C0E5B), Color(0xFF7B2FF7)];
  static const List<Color> profileGradient = [Color(0xFF173057), brandViolet];

  // Subtle glass effect overlay color for icons/containers on gradients
  static Color glassOnPrimary = Colors.white.withValues(alpha: 0.2);

  // Elevation shadow for modern depth
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
  ];
}
