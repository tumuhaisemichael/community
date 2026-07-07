import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the Community app.
///
/// Palette logic:
/// - [ink]    is the primary trust/authority color used for text, the app
///            bar, and primary buttons that are NOT emergency actions.
/// - [alert]  is reserved exclusively for danger / SOS / destructive
///            actions, so it keeps its meaning and never gets diluted by
///            decorative use elsewhere in the app.
/// - [watch]  is the secondary "in progress / keeping an eye on it" color,
///            used for links, badges, and the vacation-watch feature.
/// - [safe]   communicates a resolved or safe state.
class AppColors {
  AppColors._();

  static const Color ink = Color(0xFF14213D); // deep navy
  static const Color canvas = Color(0xFFF6F4EF); // warm off-white
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E1D8);
  static const Color mutedText = Color(0xFF6B7280);

  static const Color alert = Color(0xFFE4572E); // SOS / danger only
  static const Color alertDim = Color(0xFFF7D9CE);

  static const Color watch = Color(0xFF2F6690); // secondary / links
  static const Color watchDim = Color(0xFFDCE8EF);

  static const Color safe = Color(0xFF3A8659); // resolved / positive
  static const Color safeDim = Color(0xFFDBEBE1);
}

class AppTheme {
  AppTheme._();

  static TextTheme get _textTheme {
    final display = GoogleFonts.spaceGrotesk;
    final body = GoogleFonts.inter;

    return TextTheme(
      displayLarge: display(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: -0.5,
      ),
      headlineMedium: display(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: -0.3,
      ),
      titleMedium: display(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: body(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        height: 1.4,
      ),
      bodyMedium: body(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.mutedText,
        height: 1.4,
      ),
      labelLarge: body(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelSmall: body(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.mutedText,
        letterSpacing: 0.3,
      ),
    );
  }

  static ThemeData get light {
    final textTheme = _textTheme;

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.ink,
        brightness: Brightness.light,
        primary: AppColors.ink,
        secondary: AppColors.watch,
        error: AppColors.alert,
        surface: AppColors.card,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.ink,
        titleTextStyle: textTheme.titleMedium,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.border, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.watch,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.alert, width: 1.4),
        ),
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
    );
  }
}