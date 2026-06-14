import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color brandNavy = Color(0xFF202824);
  static const Color brandBlue = Color(0xFF167C68);
  static const Color brandSky = Color(0xFF42A88F);
  static const Color brandCyan = Color(0xFFA8E2D2);
  static const Color brandViolet = Color(0xFF9B7453);
  static const Color brandRed = Color(0xFFE05252);
  static const Color brandGold = Color(0xFFF2A93B);
  static const Color brandYellow = Color(0xFFF8D86A);

  static const Color background = Color(0xFFF7F7F3);
  static const Color surface = Colors.white;
  static const Color neutral50 = Color(0xFFFAFAF7);
  static const Color neutral100 = Color(0xFFF0F1EC);
  static const Color border = Color(0xFFE5E6DF);
  static const Color textPrimary = Color(0xFF1D2421);
  static const Color textSecondary = Color(0xFF69716D);
  static const Color success = Color(0xFF16866F);
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
      Color(0xFFE6F4EE),
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      brandBlue,
      brandSky,
      Color(0xFF80C9B7),
    ],
  );

  static const LinearGradient walletGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF1F6D5D),
      Color(0xFF28917A),
      Color(0xFF61BDA6),
    ],
  );
}
