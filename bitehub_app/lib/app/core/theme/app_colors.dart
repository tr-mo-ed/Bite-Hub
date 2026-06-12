import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color brandNavy = Color(0xFF091C4B);
  static const Color brandBlue = Color(0xFF3157F5);
  static const Color brandSky = Color(0xFF22B8F4);
  static const Color brandCyan = Color(0xFF5EE7F7);
  static const Color brandViolet = Color(0xFF7657FF);
  static const Color brandRed = Color(0xFFFF496A);
  static const Color brandGold = Color(0xFFFFB84D);
  static const Color brandYellow = Color(0xFFFFDD57);

  static const Color background = Color(0xFFF4F7FF);
  static const Color surface = Colors.white;
  static const Color neutral50 = Color(0xFFF8FAFF);
  static const Color neutral100 = Color(0xFFEDF2FF);
  static const Color border = Color(0xFFDDE6FA);
  static const Color textPrimary = Color(0xFF101B3C);
  static const Color textSecondary = Color(0xFF667397);
  static const Color success = Color(0xFF0AA77F);
  static const Color warning = Color(0xFFE59522);
  static const Color danger = Color(0xFFD92D4F);
  static const Color glass = Color(0xCCFFFFFF);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      brandNavy,
      brandBlue,
      brandSky,
      brandCyan,
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      brandViolet,
      brandBlue,
      brandSky,
    ],
  );

  static const LinearGradient walletGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF101E50),
      Color(0xFF3157F5),
      Color(0xFF24C5EE),
    ],
  );
}
