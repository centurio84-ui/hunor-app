import 'package:flutter/material.dart';
import '../models/theme_config.dart';

class HunorColors {
  static const red = Color(0xFFD71920);
  static const redDark = Color(0xFFA80F14);
  static const graphite = Color(0xFF121417);
  static const surface = Color(0xFF1B1F23);
  static const surface1 = Color(0xFF1B1F23);
  static const surface2 = Color(0xFF24292E);
  static const border = Color(0xFF30353B);
  static const text = Color(0xFFF5F7F9);
  static const muted = Color(0xFF9AA3AD);
  static const success = Color(0xFF39B86F);
  static const green = Color(0xFF39B86F);
  static const warning = Color(0xFFFF9F1C);
  static const exercise = Color(0xFF3B82F6);
  static const blue = Color(0xFF3B82F6);
}

class HunorTheme {
  /// Alapértelmezett Alpin (HUNOR vörös / grafit sötét) téma.
  static ThemeData get dark => themeForId(RescueThemeRegistry.defaultThemeId);

  /// Téma előállítása azonosító alapján (ha ismeretlen, Alpin sötét a biztonságos fallback).
  static ThemeData themeForId(String themeId) {
    final def = RescueThemeRegistry.findById(themeId);
    return themeForDefinition(def);
  }

  /// Téma előállítása témadefiníció alapján.
  static ThemeData themeForDefinition(RescueThemeDefinition def) {
    final scheme = ColorScheme.fromSeed(
      seedColor: def.primaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: def.primaryColor,
      onPrimary: Colors.white,
      secondary: def.accentColor,
      surface: HunorColors.surface,
      onSurface: HunorColors.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: HunorColors.graphite,
      appBarTheme: const AppBarTheme(
        backgroundColor: HunorColors.graphite,
        foregroundColor: HunorColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: HunorColors.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF30353B)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HunorColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF343A40)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF343A40)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: def.primaryColor, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: HunorColors.surface,
        indicatorColor: def.accentColor,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: def.primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HunorColors.text,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: Color(0xFF4A5158)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: HunorColors.surface2,
        side: BorderSide.none,
        labelStyle: const TextStyle(color: HunorColors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF30353B)),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        titleLarge: TextStyle(fontWeight: FontWeight.w800),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: HunorColors.text),
        bodyMedium: TextStyle(color: HunorColors.text),
        bodySmall: TextStyle(color: HunorColors.muted),
      ),
    );
  }
}
