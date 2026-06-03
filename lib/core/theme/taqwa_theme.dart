import 'package:flutter/material.dart';
import 'taqwa_colors.dart';

class TaqwaTheme {
  TaqwaTheme._();

  static const _cairoText = TextStyle(fontFamily: 'Cairo');

  static TextTheme get _cairoTextTheme => TextTheme(
        displayLarge: _cairoText,
        displayMedium: _cairoText,
        displaySmall: _cairoText,
        headlineLarge: _cairoText,
        headlineMedium: _cairoText,
        headlineSmall: _cairoText,
        titleLarge: _cairoText,
        titleMedium: _cairoText,
        titleSmall: _cairoText,
        bodyLarge: _cairoText,
        bodyMedium: _cairoText,
        bodySmall: _cairoText,
        labelLarge: _cairoText,
        labelMedium: _cairoText,
        labelSmall: _cairoText,
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: TaqwaColors.domeBlue,
          primary: TaqwaColors.domeBlue,
          secondary: TaqwaColors.minaretGold,
          tertiary: TaqwaColors.skyBlue,
          surface: TaqwaColors.minaretWhite,
          error: TaqwaColors.alertRed,
        ),
        scaffoldBackgroundColor: TaqwaColors.background,
        textTheme: _cairoTextTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: TaqwaColors.domeBlue,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: TaqwaColors.domeBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: TaqwaColors.domeBlue,
            minimumSize: const Size(double.infinity, 52),
            side: const BorderSide(color: TaqwaColors.domeBlue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: TaqwaColors.lightGray),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: TaqwaColors.lightGray),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: TaqwaColors.domeBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: TaqwaColors.alertRed),
          ),
          hintStyle: const TextStyle(
            fontFamily: 'Cairo',
            color: TaqwaColors.gray,
            fontSize: 14,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: TaqwaColors.darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: TaqwaColors.skyBlue,
          secondary: TaqwaColors.minaretGold,
          surface: TaqwaColors.darkCard,
          error: TaqwaColors.alertRed,
        ),
        textTheme: _cairoTextTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: TaqwaColors.darkCard,
          foregroundColor: TaqwaColors.darkText,
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: TaqwaColors.darkCard,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
}