import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual language for the app: a blue accent, warm amber for XP, built on
/// Material 3 so system dark mode works from a single definition.
///
/// Two deliberate departures from the Material default, both aimed at an
/// iOS-flavoured feel:
///
/// * **Grouped, not bordered.** Cards are flat and separated by inset gutters
///   rather than outlined. Apple's grouped tables read as stacked surfaces on a
///   tinted background, never as bordered boxes.
/// * **Semantic colour roles.** XP, streak and success are exposed through
///   [AppColors] and a [ColorScheme] extension rather than raw literals, so a
///   palette change retints every call site at once.
class AppTheme {
  const AppTheme._();

  static const Color seed = Color(0xFF007AFF);

  /// Corner radius shared by cards, sheets and grouped rows.
  static const double radius = 14;

  // Convenience forwarders for the semantic accents. These are the same values
  // [AppColors] exposes, resolved against the light scheme, so existing call
  // sites read the single palette source rather than hardcoding their own.
  static final Color xp = AppColors.of(const ColorScheme.light()).xp;
  static final Color streak = AppColors.of(const ColorScheme.light()).streak;
  static final Color success = AppColors.of(const ColorScheme.light()).success;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;
    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    // Apple's system greys are very slightly blue-tinted; Material's default
    // surface is a touch warm. This is the background cards sit on.
    final Color groupedBackground = isLight ? const Color(0xFFF2F2F7) : scheme.surface;
    final Color cardSurface = isLight ? Colors.white : scheme.surfaceContainerLow;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: groupedBackground,
      textTheme: _textTheme(scheme),
      appBarTheme: AppBarTheme(
        backgroundColor: groupedBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: scheme.onSurface,
        ),
      ),
      // Flat, no border: the gutter does the separating, which is what makes a
      // list of cards read as a single grouped surface instead of stacked boxes.
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardSurface,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        // A hairline that starts at the text edge, as in a grouped table.
        color: scheme.outlineVariant.withValues(alpha: isLight ? 0.5 : 0.6),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 10,
        iconColor: AppColors.of(scheme).neutral,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 13,
          color: scheme.onSurfaceVariant,
          letterSpacing: -0.1,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: _inputBorder(scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.primary, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: scheme.outlineVariant),
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? const Color(0xFF1C1C1E) : const Color(0xFF2C2C2E),
        contentTextStyle: GoogleFonts.inter(fontSize: 15, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // Bottom sheet: the iOS-idiomatic replacement for a Material dialog.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
        contentTextStyle: GoogleFonts.inter(fontSize: 15, color: scheme.onSurfaceVariant, height: 1.35),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: isLight ? const Color(0xFFE5E5EA) : scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      // iOS-flavoured navigation everywhere: Cupertino slide/fade on both
      // platforms so Android never gets the Material zoom-in. Tab switches
      // stay instant (go_router's shell handles those) — this only affects
      // pushed pages (exam flow, chat thread).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Apple's type ramp is tighter than Material's: negative tracking as size
  /// grows, and a `height` under 1.2 so dense lists stay legible.
  static TextTheme _textTheme(ColorScheme scheme) {
    final TextTheme base = GoogleFonts.interTextTheme();

    TextStyle? style(TextStyle? original, {double? size, double? height, double? spacing, FontWeight? weight}) {
      return original?.copyWith(
        fontSize: size,
        height: height,
        letterSpacing: spacing,
        fontWeight: weight,
        color: original.color ?? scheme.onSurface,
      );
    }

    return base.copyWith(
      displaySmall: style(base.displaySmall, size: 34, height: 1.1, spacing: -0.9, weight: FontWeight.w700),
      headlineLarge: style(base.headlineLarge, size: 30, height: 1.15, spacing: -0.8, weight: FontWeight.w700),
      headlineMedium: style(base.headlineMedium, size: 26, height: 1.2, spacing: -0.6, weight: FontWeight.w700),
      headlineSmall: style(base.headlineSmall, size: 22, height: 1.25, spacing: -0.4, weight: FontWeight.w700),
      titleLarge: style(base.titleLarge, size: 19, height: 1.3, spacing: -0.4, weight: FontWeight.w700),
      titleMedium: style(base.titleMedium, size: 16, height: 1.35, spacing: -0.2, weight: FontWeight.w600),
      titleSmall: style(base.titleSmall, size: 14, height: 1.35, spacing: -0.1, weight: FontWeight.w600),
      bodyLarge: style(base.bodyLarge, size: 16, height: 1.4, spacing: -0.2),
      bodyMedium: style(base.bodyMedium, size: 14, height: 1.4, spacing: -0.1),
      bodySmall: style(base.bodySmall, size: 12, height: 1.35),
      labelLarge: style(base.labelLarge, size: 14, weight: FontWeight.w600, spacing: -0.1),
      labelMedium: style(base.labelMedium, size: 12, weight: FontWeight.w600, spacing: 0),
      labelSmall: style(base.labelSmall, size: 11, weight: FontWeight.w600, spacing: 0.1),
    );
  }
}

/// Semantic accents that sit outside the generated [ColorScheme].
///
/// Exposed through a [ColorScheme] extension so widgets read
/// `scheme.xpAmber` rather than importing a constant. That keeps every
/// status colour in one place and makes the palette retintable in a single edit.
class AppColors {
  const AppColors._(this.scheme);

  factory AppColors.of(ColorScheme scheme) => AppColors._(scheme);

  final ColorScheme scheme;

  bool get isLight => scheme.brightness == Brightness.light;

  /// Experience points.
  Color get xp => isLight ? const Color(0xFFF59E0B) : const Color(0xFFFBBF24);

  /// Day streak — distinct from [error] so a streak never reads as a failure.
  Color get streak => isLight ? const Color(0xFFEF4444) : const Color(0xFFF87171);

  Color get success => isLight ? const Color(0xFF10B981) : const Color(0xFF34D399);

  /// Countdown urgency: used when a deadline is under five minutes away.
  Color get warning => isLight ? const Color(0xFFF59E0B) : const Color(0xFFFBBF24);

  /// Secondary text and inactive icons.
  Color get neutral => isLight ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);

  /// Tint behind a group of related rows.
  Color get fill => isLight ? const Color(0xFFE5E5EA) : const Color(0xFF2C2C2E);

  /// The surface a grouped list sits on.
  Color get background => isLight ? const Color(0xFFF2F2F7) : const Color(0xFF000000);

  /// Raised card surface.
  Color get surface => isLight ? Colors.white : const Color(0xFF1C1C1E);

  /// Hairline separator between rows inside a group.
  Color get separator => isLight ? const Color(0xFFC6C6C8) : const Color(0xFF38383A);
}

extension AppColorsScheme on ColorScheme {
  /// Shorthand so widgets can write `context.scheme.xp`.
  AppColors get accents => AppColors.of(this);
}

extension AppThemeContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;

  AppColors get accents => AppColors.of(scheme);
}
