import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Minimum touch target size for accessibility (48x48dp, per Material and
/// WCAG guidance).
const double kMinTouchTarget = 48.0;

/// App color palette with WCAG AA contrast compliance
///
/// Color contrast ratios (light theme, against white):
/// - Primary: 4.8:1 (AA for normal text, incl. white button labels)
/// - Secondary: 4.9:1
/// - Success / warning: 5.1:1 / 4.9:1
/// - Text on background: 11.6:1 (passes AA and AAA)
/// - Secondary text: 4.85:1 (passes AA)
class AppColors {
  // Light theme - Enhanced for better contrast
  static const Color primaryLight = Color(0xFF1E8078);
  static const Color secondaryLight = Color(0xFFC94040);
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textLight =
      Color(0xFF1A1A1A); // Darker for better contrast (was 2D3436)
  static const Color textSecondaryLight =
      Color(0xFF555555); // Darker secondary text (was 636E72)
  static const Color successLight = Color(0xFF2E7D32);
  static const Color warningLight = Color(0xFFA65F00);
  static const Color errorLight = Color(0xFFD32F2F); // Standard error red

  // Dark theme - Enhanced for better contrast
  static const Color primaryDark =
      Color(0xFF5CE1D6); // Brighter teal for dark mode (was 4ECDC4)
  static const Color secondaryDark =
      Color(0xFFFF7A7A); // Brighter coral for dark mode (was FF6B6B)
  static const Color backgroundDark =
      Color(0xFF121220); // Darker background (was 1A1A2E)
  static const Color surfaceDark =
      Color(0xFF1E1E32); // Slightly lighter surface (was 16213E)
  static const Color textDark = Color(0xFFF8F8F8); // Brighter text (was F5F5F5)
  static const Color textSecondaryDark =
      Color(0xFFCCCCCC); // Brighter secondary (was B2BEC3)
  static const Color successDark = Color(0xFF81C784);
  static const Color warningDark = Color(0xFFFFCA28);
  static const Color errorDark = Color(0xFFEF5350);

  // Focus indicator colors (for visible keyboard navigation)
  static const Color focusLight = Color(0xFF1565C0); // Blue focus ring
  static const Color focusDark = Color(0xFF64B5F6);
}

class AppTheme {
  /// Minimum touch target size for accessibility (WCAG 2.1 AA: 44x44, enhanced: 48x48)
  static const double minTouchTarget = 48.0;

  /// Default line height for body text (improved readability for dyslexia)
  static const double bodyLineHeight = 1.5;

  /// Default letter spacing (slightly increased for readability)
  static const double bodyLetterSpacing = 0.15;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryLight,
      onPrimary: Colors.white,
      secondary: AppColors.secondaryLight,
      onSecondary: Colors.white,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textLight,
      error: AppColors.errorLight,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.backgroundLight,
    textTheme: _textTheme(AppColors.textLight, AppColors.textSecondaryLight),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.backgroundLight,
      foregroundColor: AppColors.textLight,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textLight,
        height: 1.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceLight,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        minimumSize: const Size(minTouchTarget, minTouchTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: bodyLetterSpacing,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        minimumSize: const Size(minTouchTarget, minTouchTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(minTouchTarget, minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(minTouchTarget, minTouchTarget),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.textSecondaryLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: AppColors.textSecondaryLight.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.focusLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorLight, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    // Focus/highlight for keyboard navigation
    focusColor: AppColors.focusLight.withValues(alpha: 0.3),
    hoverColor: AppColors.primaryLight.withValues(alpha: 0.1),
    splashColor: AppColors.primaryLight.withValues(alpha: 0.2),
    // Checkbox/Radio with proper touch targets
    checkboxTheme: const CheckboxThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    ),
    radioTheme: const RadioThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    ),
    switchTheme: const SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
    ),
    chipTheme: const ChipThemeData(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    extensions: const [StatusColors.light],
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryDark,
      onPrimary: Colors.black,
      secondary: AppColors.secondaryDark,
      onSecondary: Colors.black,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textDark,
      error: AppColors.errorDark,
      onError: Colors.black,
    ),
    scaffoldBackgroundColor: AppColors.backgroundDark,
    textTheme: _textTheme(AppColors.textDark, AppColors.textSecondaryDark),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.backgroundDark,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
        height: 1.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceDark,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        minimumSize: const Size(minTouchTarget, minTouchTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: bodyLetterSpacing,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        minimumSize: const Size(minTouchTarget, minTouchTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: AppColors.primaryDark, width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(minTouchTarget, minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(minTouchTarget, minTouchTarget),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.textSecondaryDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: AppColors.textSecondaryDark.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.focusDark, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorDark, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    // Focus/highlight for keyboard navigation
    focusColor: AppColors.focusDark.withValues(alpha: 0.3),
    hoverColor: AppColors.primaryDark.withValues(alpha: 0.1),
    splashColor: AppColors.primaryDark.withValues(alpha: 0.2),
    // Checkbox/Radio with proper touch targets
    checkboxTheme: const CheckboxThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    ),
    radioTheme: const RadioThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    ),
    switchTheme: const SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
    ),
    chipTheme: const ChipThemeData(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    extensions: const [StatusColors.dark],
  );

  static ThemeData lightThemeFor(String rewardThemeId) {
    return _applyRewardPalette(lightTheme, rewardThemeId);
  }

  static ThemeData darkThemeFor(String rewardThemeId) {
    return _applyRewardPalette(darkTheme, rewardThemeId);
  }

  static ThemeData _applyRewardPalette(
    ThemeData base,
    String rewardThemeId,
  ) {
    final palette = _rewardPalette(rewardThemeId, base.brightness);
    if (palette == null) return base;

    final colorScheme = base.colorScheme.copyWith(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      secondary: palette.secondary,
      onSecondary: palette.onSecondary,
      surface: palette.surface,
      onSurface: palette.onSurface,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: palette.background,
        foregroundColor: palette.onSurface,
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
          color: palette.onSurface,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(color: palette.surface),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: base.elevatedButtonTheme.style?.copyWith(
          backgroundColor: WidgetStatePropertyAll(palette.primary),
          foregroundColor: WidgetStatePropertyAll(palette.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style?.copyWith(
          foregroundColor: WidgetStatePropertyAll(palette.primary),
          side: WidgetStatePropertyAll(
            BorderSide(color: palette.primary, width: 2),
          ),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: palette.surface,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.primary, width: 2),
        ),
      ),
      focusColor: palette.primary.withValues(alpha: 0.3),
      hoverColor: palette.primary.withValues(alpha: 0.1),
      splashColor: palette.primary.withValues(alpha: 0.2),
    );
  }

  static _RewardPalette? _rewardPalette(
    String rewardThemeId,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    switch (rewardThemeId) {
      case 'sunset_coral':
        return isDark
            ? const _RewardPalette(
                primary: Color(0xFFFF8A80),
                onPrimary: Colors.black,
                secondary: Color(0xFF5CE1D6),
                onSecondary: Colors.black,
                background: Color(0xFF201416),
                surface: Color(0xFF322124),
                onSurface: AppColors.textDark,
              )
            : const _RewardPalette(
                primary: Color(0xFFC94040),
                onPrimary: Colors.white,
                secondary: Color(0xFF1E8078),
                onSecondary: Colors.white,
                background: Color(0xFFFFF8F6),
                surface: Colors.white,
                onSurface: AppColors.textLight,
              );
      case 'deep_ocean':
        return isDark
            ? const _RewardPalette(
                primary: Color(0xFF57C7E3),
                onPrimary: Colors.black,
                secondary: Color(0xFFFF9B7A),
                onSecondary: Colors.black,
                background: Color(0xFF0C1820),
                surface: Color(0xFF142832),
                onSurface: AppColors.textDark,
              )
            : const _RewardPalette(
                primary: Color(0xFF147D92),
                onPrimary: Colors.white,
                secondary: Color(0xFFBF4530),
                onSecondary: Colors.white,
                background: Color(0xFFF4FAFC),
                surface: Colors.white,
                onSurface: AppColors.textLight,
              );
      case 'forest_calm':
        return isDark
            ? const _RewardPalette(
                primary: Color(0xFF79C995),
                onPrimary: Colors.black,
                secondary: Color(0xFFF0A06B),
                onSecondary: Colors.black,
                background: Color(0xFF101A14),
                surface: Color(0xFF1C2B21),
                onSurface: AppColors.textDark,
              )
            : const _RewardPalette(
                primary: Color(0xFF3D7A57),
                onPrimary: Colors.white,
                secondary: Color(0xFFAD572F),
                onSecondary: Colors.white,
                background: Color(0xFFF6FAF7),
                surface: Colors.white,
                onSurface: AppColors.textLight,
              );
      case 'midnight':
        return isDark
            ? const _RewardPalette(
                primary: Color(0xFF9FA8DA),
                onPrimary: Colors.black,
                secondary: Color(0xFFF48FB1),
                onSecondary: Colors.black,
                background: Color(0xFF0E1020),
                surface: Color(0xFF1B1E35),
                onSurface: AppColors.textDark,
              )
            : const _RewardPalette(
                primary: Color(0xFF4F5D95),
                onPrimary: Colors.white,
                secondary: Color(0xFFB84F7A),
                onSecondary: Colors.white,
                background: Color(0xFFF6F7FC),
                surface: Colors.white,
                onSurface: AppColors.textLight,
              );
      default:
        return null;
    }
  }

  /// Text theme optimized for accessibility and dyslexia-friendly reading
  ///
  /// - Nunito: Rounded, friendly font for headings (good for dyslexia)
  /// - Inter: Clean, legible font for body text
  /// - Line heights: 1.3-1.5 for improved readability
  /// - Left-aligned text (RTL support via Flutter defaults)
  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: GoogleFonts.nunito(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: primary,
        height: 1.3,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.nunito(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.3,
        letterSpacing: -0.25,
      ),
      displaySmall: GoogleFonts.nunito(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.3,
      ),
      headlineMedium: GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.4,
      ),
      titleLarge: GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.4,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primary,
        height: 1.4,
        letterSpacing: bodyLetterSpacing,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
        height: bodyLineHeight,
        letterSpacing: bodyLetterSpacing,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: bodyLineHeight,
        letterSpacing: bodyLetterSpacing,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: bodyLineHeight,
        letterSpacing: 0.2,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.4,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _RewardPalette {
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color background;
  final Color surface;
  final Color onSurface;

  const _RewardPalette({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.background,
    required this.surface,
    required this.onSurface,
  });
}

/// Semantic status colours that follow the active light/dark theme.
///
/// Use `StatusColors.of(context)` instead of hard-coded `Colors.green` /
/// `Colors.orange`, which have poor contrast on light surfaces.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;

  const StatusColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
  });

  static const light = StatusColors(
    success: AppColors.successLight,
    onSuccess: Colors.white,
    warning: AppColors.warningLight,
    onWarning: Colors.white,
  );

  static const dark = StatusColors(
    success: AppColors.successDark,
    onSuccess: Colors.black,
    warning: AppColors.warningDark,
    onWarning: Colors.black,
  );

  static StatusColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<StatusColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  StatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
  }) {
    return StatusColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
    );
  }
}
