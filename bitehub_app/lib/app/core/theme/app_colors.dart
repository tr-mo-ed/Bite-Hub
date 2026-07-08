import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color brandNavy = Color(0xFF0F172A);
  static const Color brandBlue = Color(0xFF2563EB);
  static const Color brandSky = Color(0xFF38BDF8);
  static const Color brandCyan = Color(0xFFDFF5FF);
  static const Color brandViolet = Color(0xFF7C3AED);
  static const Color brandRed = Color(0xFFE11D48);
  static const Color brandGold = Color(0xFFF59E0B);
  static const Color brandYellow = Color(0xFFFACC15);

  static const Color background = Color(0xFFF7F7F3);
  static const Color surface = Colors.white;
  static const Color neutral50 = Color(0xFFFAFAF7);
  static const Color neutral100 = Color(0xFFF0F1EC);
  static const Color border = Color(0xFFE5E6DF);
  static const Color textPrimary = Color(0xFF1D2421);
  static const Color textSecondary = Color(0xFF69716D);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD78A1D);
  static const Color danger = Color(0xFFC94444);
  static const Color glass = Color(0xE8FFFFFF);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      brandBlue,
      brandSky,
      brandCyan,
      brandYellow,
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      brandBlue,
      brandSky,
      brandRed,
    ],
  );

  static const LinearGradient walletGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF1D4ED8),
      Color(0xFFE11D48),
      Color(0xFFFACC15),
    ],
  );
}
