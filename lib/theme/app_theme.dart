import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

/// Design tokens for the Community app ("Night Patrol" palette).
///
/// Palette logic:
/// - [ink]     is body/heading text. [primary] is the brand indigo used for
///             primary buttons, selected states and the tab bar indicator.
/// - [hero]    is the deep navy used behind white text (headers, splash).
///             It stays dark in both themes.
/// - [alert]   is reserved exclusively for danger / SOS / destructive
///             actions, so it keeps its meaning and never gets diluted by
///             decorative use elsewhere in the app.
/// - [accent]  is streetlight amber: highlights on dark surfaces only.
/// - [watch]   is the secondary "keeping an eye on it" color, used for
///             links, badges and the vacation-watch feature.
/// - [safe]    communicates a resolved or safe state.
/// - [sevLow]..[sevCritical] colour incident severity everywhere.
///
/// Values switch with the platform brightness via [AppColors.apply], which
/// [CommunityApp] calls before building the widget tree.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.ink,
    required this.primary,
    required this.onPrimary,
    required this.canvas,
    required this.card,
    required this.border,
    required this.mutedText,
    required this.hero,
    required this.heroAlt,
    required this.heroMuted,
    required this.accent,
    required this.onAccent,
    required this.amber,
    required this.alert,
    required this.alertDim,
    required this.watch,
    required this.watchDim,
    required this.safe,
    required this.safeDim,
    required this.sevLow,
    required this.sevMedium,
    required this.sevHigh,
    required this.sevCritical,
    required this.flaggedCard,
  });

  final Brightness brightness;
  final Color ink;
  final Color primary;
  final Color onPrimary;
  final Color canvas;
  final Color card;
  final Color border;
  final Color mutedText;
  final Color hero;
  final Color heroAlt;
  final Color heroMuted;
  final Color accent;
  final Color onAccent;
  final Color amber;
  final Color alert;
  final Color alertDim;
  final Color watch;
  final Color watchDim;
  final Color safe;
  final Color safeDim;
  final Color sevLow;
  final Color sevMedium;
  final Color sevHigh;
  final Color sevCritical;
  final Color flaggedCard;

  static const light = AppPalette(
    brightness: Brightness.light,
    ink: Color(0xFF161C3A),
    primary: Color(0xFF24306B),
    onPrimary: Color(0xFFFFFFFF),
    canvas: Color(0xFFF3F4F8),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE1E4EE),
    mutedText: Color(0xFF5F6782),
    hero: Color(0xFF151B3D),
    heroAlt: Color(0xFF26316A),
    heroMuted: Color(0xFFB4BBDA),
    accent: Color(0xFFF4B740),
    onAccent: Color(0xFF1A1A1A),
    amber: Color(0xFFA86E06),
    alert: Color(0xFFD93228),
    alertDim: Color(0xFFFCE9E7),
    watch: Color(0xFF3447A8),
    watchDim: Color(0xFFE6E9F8),
    safe: Color(0xFF23825F),
    safeDim: Color(0xFFE2F2EA),
    sevLow: Color(0xFF3E7DD6),
    sevMedium: Color(0xFFD98A0B),
    sevHigh: Color(0xFFE0362C),
    sevCritical: Color(0xFF9E1C3F),
    flaggedCard: Color(0xFFFFF6F4),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    ink: Color(0xFFE7EAF7),
    primary: Color(0xFFA9B6FF),
    onPrimary: Color(0xFF0C0F1E),
    canvas: Color(0xFF0C0F1E),
    card: Color(0xFF151A30),
    border: Color(0xFF262D4B),
    mutedText: Color(0xFF9AA1BF),
    hero: Color(0xFF1A2148),
    heroAlt: Color(0xFF2A3570),
    heroMuted: Color(0xFFA7AED0),
    accent: Color(0xFFF4B740),
    onAccent: Color(0xFF1A1A1A),
    amber: Color(0xFFF4B740),
    alert: Color(0xFFF2493E),
    alertDim: Color(0xFF3B1A20),
    watch: Color(0xFFA9B6FF),
    watchDim: Color(0xFF232C57),
    safe: Color(0xFF6CC29C),
    safeDim: Color(0xFF173A2E),
    sevLow: Color(0xFF6FA6F2),
    sevMedium: Color(0xFFF4B740),
    sevHigh: Color(0xFFF2493E),
    sevCritical: Color(0xFFFF6B8A),
    flaggedCard: Color(0xFF2A1A24),
  );
}

class AppColors {
  AppColors._();

  static AppPalette _p = AppPalette.light;

  static void apply(Brightness brightness) {
    _p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  }

  static bool get isDark => _p.brightness == Brightness.dark;

  static Color get ink => _p.ink;
  static Color get primary => _p.primary;
  static Color get onPrimary => _p.onPrimary;
  static Color get canvas => _p.canvas;
  static Color get card => _p.card;
  static Color get border => _p.border;
  static Color get mutedText => _p.mutedText;
  static Color get hero => _p.hero;
  static Color get heroAlt => _p.heroAlt;
  static Color get heroMuted => _p.heroMuted;
  static Color get accent => _p.accent;
  static Color get onAccent => _p.onAccent;
  static Color get amber => _p.amber;
  static Color get alert => _p.alert; // SOS / danger only
  static Color get alertDim => _p.alertDim;
  static Color get watch => _p.watch; // secondary / links
  static Color get watchDim => _p.watchDim;
  static Color get safe => _p.safe; // resolved / positive
  static Color get safeDim => _p.safeDim;
  static Color get sevLow => _p.sevLow;
  static Color get sevMedium => _p.sevMedium;
  static Color get sevHigh => _p.sevHigh;
  static Color get sevCritical => _p.sevCritical;
  static Color get flaggedCard => _p.flaggedCard;

  /// Kept for older call sites; the palette no longer has a lime.
  static Color get lime => _p.accent;
}

class AppTheme {
  AppTheme._();

  static TextStyle _display(TextStyle style) =>
      GoogleFonts.bricolageGrotesque(textStyle: style);

  static TextTheme get _textTheme {
    final base = TextTheme(
      displayLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: -0.8,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -.5,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        color: AppColors.mutedText,
        height: 1.45,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.mutedText,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.mutedText,
        letterSpacing: 0.3,
      ),
    );
    final body = GoogleFonts.figtreeTextTheme(base);
    return body.copyWith(
      displayLarge: _display(base.displayLarge!),
      headlineMedium: _display(base.headlineMedium!),
      headlineSmall: _display(
        TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          letterSpacing: -.5,
        ),
      ),
      titleLarge: _display(base.titleLarge!),
    );
  }

  /// Theme for the palette most recently selected by [AppColors.apply].
  static ThemeData get current {
    final textTheme = _textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: AppColors.isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: AppColors.isDark ? Brightness.dark : Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.watch,
        tertiary: AppColors.accent,
        error: AppColors.alert,
        surface: AppColors.card,
        onSurface: AppColors.ink,
        outline: AppColors.border,
      ),
      iconTheme: IconThemeData(color: AppColors.ink),
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _CommunityPageTransition(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: _CommunityPageTransition(),
          TargetPlatform.windows: _CommunityPageTransition(),
          TargetPlatform.linux: _CommunityPageTransition(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        toolbarHeight: 72,
        centerTitle: false,
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
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.mutedText,
          ),
        ),
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.watchDim,
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.mutedText,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.mutedText,
        labelStyle: textTheme.labelLarge,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.border,
        indicatorColor: AppColors.watch,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.watch,
        textColor: AppColors.ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.watchDim,
        checkmarkColor: AppColors.primary,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        labelStyle: textTheme.labelSmall?.copyWith(color: AppColors.ink),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.canvas,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.hero,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.watchDim,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
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
          side: BorderSide(color: AppColors.border, width: 1.4),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.alert, width: 1.4),
        ),
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.onPrimary
              : AppColors.mutedText,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.canvas,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.mutedText,
        ),
      ),
      dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}

class _CommunityPageTransition extends PageTransitionsBuilder {
  const _CommunityPageTransition();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .025),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}
