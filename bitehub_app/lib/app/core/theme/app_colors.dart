import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color brandNavy = Color(0xFF172554);
  static const Color brandBlue = Color(0xFF2563EB);
  static const Color brandSky = Color(0xFF0EA5E9);
  static const Color brandRed = Color(0xFFE53935);
  static const Color brandGold = Color(0xFFD9A441);
  static const Color brandYellow = Color(0xFFF2C94C);

  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Colors.white;
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color neutral100 = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color success = Color(0xFF0F766E);
  static const Color warning = Color(0xFFB7791F);
  static const Color danger = Color(0xFFB91C1C);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      brandNavy,
      brandBlue,
      brandSky,
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      brandBlue,
      brandGold,
      brandYellow,
    ],
  );
}
