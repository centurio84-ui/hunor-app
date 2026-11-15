import 'package:flutter/material.dart';
import '../models/theme_config.dart';

class HunorColors {
  // Webportál hivatalos HUNOR Navy & Gold paletta (portal/theme.css)
  static const navy = Color(0xFF0B132B);       // --bg: #0B132B
  static const navyDark = Color(0xFF070C1B);   // Mélysötét navy
  static const navyCard = Color(0xFF1C2541);   // --paper: #1C2541
  static const navyLight = Color(0xFF253358);  // Másodlagos kártya & kiemelés
  static const gold = Color(0xFFFFB703);       // --accent: #FFB703
  static const goldLight = Color(0xFFFFD166);  // Lágy arany
  static const line = Color(0x358D99AE);       // --line: #8D99AE35

  // Klasszikus HUNOR piros
  static const red = Color(0xFFD71920);
  static const redDark = Color(0xFFA80F14);
  static const orange = Color(0xFFFB8500); // Műveleti narancs

  // Kompatibilitási aliasok a meglévő kódhoz
  static const graphite = navy;
  static const surface = navyCard;
  static const surface1 = navyCard;
  static const surface2 = navyLight;
  static const border = line;
  static const text = Colors.white;
  static const muted = Color(0xFF8D99AE);       // --muted: #8D99AE
  static const success = Color(0xFF39B86F);
  static const green = Color(0xFF39B86F);
  static const warning = Color(0xFFFFB703);
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
      surface: HunorColors.navyCard,
      onSurface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: HunorColors.navy,
      appBarTheme: const AppBarTheme(
        backgroundColor: HunorColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: HunorColors.navyCard,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: HunorColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HunorColors.navy,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HunorColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HunorColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HunorColors.gold, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: HunorColors.navyCard,
        indicatorColor: HunorColors.gold.withOpacity(0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: HunorColors.gold);
          }
          return const IconThemeData(color: HunorColors.muted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: HunorColors.gold, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return const TextStyle(color: HunorColors.muted, fontWeight: FontWeight.w600, fontSize: 12);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HunorColors.gold,
          foregroundColor: HunorColors.navy,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: HunorColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: HunorColors.navyLight,
        side: BorderSide.none,
        labelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(color: HunorColors.line),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4, color: Colors.white),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: HunorColors.muted),
      ),
    );
  }
}
