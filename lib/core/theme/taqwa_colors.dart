import 'package:flutter/material.dart';

class TaqwaColors {
  TaqwaColors._();

  // الألوان الأساسية
  static const Color domeBlue = Color(0xFF1B4F72);
  static const Color minaretGold = Color(0xFFD4AC0D);
  static const Color skyBlue = Color(0xFF2E86C1);
  static const Color minaretWhite = Color(0xFFF8F9F9);
  static const Color nightSky = Color(0xFF1A1A2E);
  static const Color islamicGreen = Color(0xFF1E8449);
  static const Color alertRed = Color(0xFFC0392B);

  // الألوان الممتدة
  static const Color lightBlue = Color(0xFFEBF5FB);
  static const Color lightGold = Color(0xFFFEF9E7);
  static const Color lightGreen = Color(0xFFEAFAF1);
  static const Color lightRed = Color(0xFFFDEDEC);
  static const Color gray = Color(0xFF5D6D7E);
  static const Color lightGray = Color(0xFFD5D8DC);
  static const Color dividerColor = Color(0xFFE8ECF0);
  static const Color background = Color(0xFFF0F3F7);

  // الوضع الداكن
  static const Color darkBackground = Color(0xFF0D2F45);
  static const Color darkCard = Color(0xFF162447);
  static const Color darkText = Color(0xFFE8E8E8);

  // تدرجات
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [domeBlue, skyBlue],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [nightSky, domeBlue],
  );
}