import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const cream = Color(0xFFF8F5F0);
  static const creamDark = Color(0xFFEDE8E0);
  static const ink = Color(0xFF12121A);
  static const inkMuted = Color(0xFF6E6E7E);
  static const coral = Color(0xFFE85D4A);
  static const coralLight = Color(0xFFFF8A7A);
  static const violet = Color(0xFF7C3AED);
  static const gold = Color(0xFFC9A227);
  static const goldLight = Color(0xFFE8C872);
  static const white = Color(0xFFFFFFFF);
  static const cardShadow = Color(0x1A12121A);
  static const glass = Color(0xCCFFFFFF);
  static const glassBorder = Color(0x33FFFFFF);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [coral, violet],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, Color(0xFF9A7B1A)],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F0F14), Color(0xFF1E1A2E), Color(0xFF3D1F3A)],
  );

  static const meshGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8F5F0), Color(0xFFF3ECE4), Color(0xFFEDE4F5)],
  );

  static const warmGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x33E85D4A), Color(0x227C3AED)],
  );

  static List<BoxShadow> elevationShadow({double opacity = 0.12, double blur = 32, double y = 16}) => [
        BoxShadow(color: ink.withValues(alpha: opacity), blurRadius: blur, offset: Offset(0, y)),
      ];

  static List<BoxShadow> glowShadow(Color color, {double blur = 40}) => [
        BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: blur, spreadRadius: -4),
      ];
}

class AppDecor {
  static BoxDecoration glassCard({double radius = 20, Color? tint}) => BoxDecoration(
        color: tint ?? AppColors.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.65), width: 1.2),
        boxShadow: AppColors.elevationShadow(opacity: 0.06, blur: 24, y: 8),
      );

  static BoxDecoration pill({Color? color}) => BoxDecoration(
        color: color ?? AppColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.creamDark.withValues(alpha: 0.8)),
      );
}

class AppTheme {
  static ThemeData forLocale(Locale locale) {
    final isArabic = locale.languageCode == 'ar';
    return _applyFonts(_baseTheme, isArabic: isArabic);
  }

  static ThemeData get light => forLocale(const Locale('en'));

  static ThemeData get _baseTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.coral,
        brightness: Brightness.light,
        primary: AppColors.coral,
        secondary: AppColors.violet,
        surface: AppColors.white,
        onSurface: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.ink),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        hintStyle: const TextStyle(color: AppColors.inkMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.coral,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  static TextStyle bodyFont({required bool isArabic}) {
    // Web: bundled Google Fonts are not shipped; runtime fetch is disabled in main.dart.
    if (kIsWeb) {
      return TextStyle(
        fontFamily: isArabic ? 'Geeza Pro' : 'Segoe UI',
        fontFamilyFallback: isArabic
            ? const ['Cairo', 'Noto Naskh Arabic', 'Tahoma', 'Arial']
            : const ['system-ui', 'Roboto', 'Helvetica Neue', 'Arial'],
      );
    }
    return isArabic ? GoogleFonts.cairo() : GoogleFonts.outfit();
  }

  static ThemeData _applyFonts(ThemeData base, {required bool isArabic}) {
    if (kIsWeb) {
      final family = bodyFont(isArabic: isArabic);
      final textTheme = base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink, fontFamily: family.fontFamily);
      return base.copyWith(
        textTheme: textTheme,
        primaryTextTheme: textTheme,
        appBarTheme: base.appBarTheme.copyWith(
          titleTextStyle: textTheme.titleLarge?.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          labelStyle: textTheme.bodyMedium,
        ),
      );
    }

    final textTheme = isArabic
        ? GoogleFonts.cairoTextTheme(base.textTheme)
        : GoogleFonts.outfitTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
        labelStyle: textTheme.bodyMedium,
      ),
    );
  }
}
