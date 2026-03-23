import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_controller.dart';

class AppTheme {
  static ThemeData dark([AppThemeVariant variant = AppThemeVariant.earthy]) {
    final colorScheme = switch (variant) {
      AppThemeVariant.classic => _classicDarkScheme(),
      AppThemeVariant.earthy => _earthyDarkScheme(),
      AppThemeVariant.blush => _blushDarkScheme(),
      AppThemeVariant.moss => _mossDarkScheme(),
      AppThemeVariant.violet => _violetDarkScheme(),
      AppThemeVariant.slate => _slateDarkScheme(),
      AppThemeVariant.ocean => _oceanDarkScheme(),
    };
    final textTheme = _textTheme(
      base: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme),
      ink: colorScheme.onSurface,
      muted: colorScheme.onSurfaceVariant,
    );

    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      inputFillColor: colorScheme.surfaceContainerHigh,
    );
  }

  static ThemeData light([AppThemeVariant variant = AppThemeVariant.earthy]) {
    final colorScheme = switch (variant) {
      AppThemeVariant.classic => _classicLightScheme(),
      AppThemeVariant.earthy => _earthyLightScheme(),
      AppThemeVariant.blush => _blushLightScheme(),
      AppThemeVariant.moss => _mossLightScheme(),
      AppThemeVariant.violet => _violetLightScheme(),
      AppThemeVariant.slate => _slateLightScheme(),
      AppThemeVariant.ocean => _oceanLightScheme(),
    };
    final textTheme = _textTheme(
      base: GoogleFonts.robotoTextTheme(ThemeData.light().textTheme),
      ink: colorScheme.onSurface,
      muted: colorScheme.onSurfaceVariant,
    );

    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme,
      inputFillColor: colorScheme.surfaceContainerHighest,
    );
  }

  static ColorScheme _earthyDarkScheme() {
    const seed = Color(0xFF8A7650);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFDBCEA5),
      onPrimary: const Color(0xFF2D2616),
      primaryContainer: const Color(0xFF8A7650),
      onPrimaryContainer: const Color(0xFFF7F2E1),
      secondary: const Color(0xFF8E977D),
      onSecondary: const Color(0xFF1E2418),
      secondaryContainer: const Color(0xFF4B5341),
      onSecondaryContainer: const Color(0xFFE8ECD9),
      tertiary: const Color(0xFFB79D72),
      onTertiary: const Color(0xFF21180C),
      tertiaryContainer: const Color(0xFF6A5737),
      onTertiaryContainer: const Color(0xFFF5E8CF),
      surface: const Color(0xFF171510),
      onSurface: const Color(0xFFECE7D1),
      surfaceDim: const Color(0xFF12100C),
      surfaceBright: const Color(0xFF343027),
      surfaceContainerLowest: const Color(0xFF0F0D09),
      surfaceContainerLow: const Color(0xFF211D16),
      surfaceContainer: const Color(0xFF28231B),
      surfaceContainerHigh: const Color(0xFF302A21),
      surfaceContainerHighest: const Color(0xFF3A3328),
      outline: const Color(0xFF9C9276),
      outlineVariant: const Color(0xFF5C5342),
    );
    return colorScheme;
  }

  static ColorScheme _earthyLightScheme() {
    const seed = Color(0xFF8A7650);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF8A7650),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFDBCEA5),
      onPrimaryContainer: const Color(0xFF332A18),
      secondary: const Color(0xFF8E977D),
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: const Color(0xFFDCE3CB),
      onSecondaryContainer: const Color(0xFF2C3323),
      tertiary: const Color(0xFFB79D72),
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: const Color(0xFFF0E2C8),
      onTertiaryContainer: const Color(0xFF3E2F18),
      surface: const Color(0xFFECE7D1),
      onSurface: const Color(0xFF262117),
      surfaceDim: const Color(0xFFD8D0B4),
      surfaceBright: const Color(0xFFFBF8EE),
      surfaceContainerLowest: const Color(0xFFFFFCF5),
      surfaceContainerLow: const Color(0xFFF4EFDD),
      surfaceContainer: const Color(0xFFEEE7D0),
      surfaceContainerHigh: const Color(0xFFE7DFC5),
      surfaceContainerHighest: const Color(0xFFDBCEA5),
      outline: const Color(0xFF8F8468),
      outlineVariant: const Color(0xFFC8BEA2),
    );
    return colorScheme;
  }

  static ColorScheme _classicDarkScheme() {
    const seed = Color(0xFF8FA8E8);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF1C1B1F),
      onSurface: const Color(0xFFE6E1E5),
      surfaceDim: const Color(0xFF141218),
      surfaceBright: const Color(0xFF35343A),
      surfaceContainerLowest: const Color(0xFF0F0D13),
      surfaceContainerLow: const Color(0xFF222127),
      surfaceContainer: const Color(0xFF28262D),
      surfaceContainerHigh: const Color(0xFF302D35),
      surfaceContainerHighest: const Color(0xFF39363E),
      outline: const Color(0xFF938F99),
      outlineVariant: const Color(0xFF5A5560),
      secondaryContainer: const Color(0xFF3A4559),
      onSecondaryContainer: const Color(0xFFDCE3F9),
      primaryContainer: const Color(0xFF324670),
      onPrimaryContainer: const Color(0xFFD8E2FF),
    );
    return colorScheme;
  }

  static ColorScheme _classicLightScheme() {
    const seed = Color(0xFF324670);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF324670),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFD8E2FF),
      onPrimaryContainer: const Color(0xFF1A2D4D),
      secondary: const Color(0xFF53627F),
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: const Color(0xFFDCE3F9),
      onSecondaryContainer: const Color(0xFF25324A),
      tertiary: const Color(0xFF5D5D72),
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: const Color(0xFFE3E1F2),
      onTertiaryContainer: const Color(0xFF2B2938),
      surface: const Color(0xFFF4F6FA),
      onSurface: const Color(0xFF1A1C22),
      surfaceDim: const Color(0xFFD1D6E0),
      surfaceBright: const Color(0xFFFFFFFF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFEAEFF7),
      surfaceContainer: const Color(0xFFE2E8F1),
      surfaceContainerHigh: const Color(0xFFDAE1EC),
      surfaceContainerHighest: const Color(0xFFD1D9E6),
      outline: const Color(0xFF727887),
      outlineVariant: const Color(0xFFB5BECC),
    );
    return colorScheme;
  }

  static ColorScheme _blushDarkScheme() {
    const seed = Color(0xFFF5AFAF);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFF9DFDF),
      onPrimary: const Color(0xFF4B2327),
      primaryContainer: const Color(0xFFF5AFAF),
      onPrimaryContainer: const Color(0xFFFFFAFA),
      secondary: const Color(0xFFFBEFEF),
      onSecondary: const Color(0xFF352A2C),
      secondaryContainer: const Color(0xFF6B575A),
      onSecondaryContainer: const Color(0xFFFFF8F8),
      tertiary: const Color(0xFFFCF8F8),
      onTertiary: const Color(0xFF3A3133),
      tertiaryContainer: const Color(0xFF706163),
      onTertiaryContainer: const Color(0xFFFFFAFA),
      surface: const Color(0xFF181315),
      onSurface: const Color(0xFFFCF6F6),
      surfaceDim: const Color(0xFF120D0F),
      surfaceBright: const Color(0xFF393032),
      surfaceContainerLowest: const Color(0xFF0E090A),
      surfaceContainerLow: const Color(0xFF211A1C),
      surfaceContainer: const Color(0xFF292123),
      surfaceContainerHigh: const Color(0xFF332A2C),
      surfaceContainerHighest: const Color(0xFF3D3336),
      outline: const Color(0xFFC8ABAE),
      outlineVariant: const Color(0xFF69575A),
    );
    return colorScheme;
  }

  static ColorScheme _blushLightScheme() {
    const seed = Color(0xFFF5AFAF);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFFF5AFAF),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFF9DFDF),
      onPrimaryContainer: const Color(0xFF6A3B40),
      secondary: const Color(0xFFFBEFEF),
      onSecondary: const Color(0xFF4F4143),
      secondaryContainer: const Color(0xFFF7E4E4),
      onSecondaryContainer: const Color(0xFF5D4D50),
      tertiary: const Color(0xFFFCF8F8),
      onTertiary: const Color(0xFF5A4D50),
      tertiaryContainer: const Color(0xFFF8EFEF),
      onTertiaryContainer: const Color(0xFF68595C),
      surface: const Color(0xFFFCF8F8),
      onSurface: const Color(0xFF2D2527),
      surfaceDim: const Color(0xFFE9DEDE),
      surfaceBright: const Color(0xFFFFFFFF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFBF4F4),
      surfaceContainer: const Color(0xFFF8F0F0),
      surfaceContainerHigh: const Color(0xFFF4EAEA),
      surfaceContainerHighest: const Color(0xFFEEE3E3),
      outline: const Color(0xFFC6B0B3),
      outlineVariant: const Color(0xFFE7D5D8),
    );
    return colorScheme;
  }

  static ColorScheme _mossDarkScheme() {
    const seed = Color(0xFF84B179);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFC7EABB),
      onPrimary: const Color(0xFF16301A),
      primaryContainer: const Color(0xFF84B179),
      onPrimaryContainer: const Color(0xFFF5FFF1),
      secondary: const Color(0xFFA2CB8B),
      onSecondary: const Color(0xFF203117),
      secondaryContainer: const Color(0xFF4D6940),
      onSecondaryContainer: const Color(0xFFEAF6E2),
      tertiary: const Color(0xFFE8F5BD),
      onTertiary: const Color(0xFF2E3312),
      tertiaryContainer: const Color(0xFF687238),
      onTertiaryContainer: const Color(0xFFFFFDE7),
      surface: const Color(0xFF131711),
      onSurface: const Color(0xFFF1F6EA),
      surfaceDim: const Color(0xFF0E120D),
      surfaceBright: const Color(0xFF2C3528),
      surfaceContainerLowest: const Color(0xFF0A0E09),
      surfaceContainerLow: const Color(0xFF1A2118),
      surfaceContainer: const Color(0xFF212A1F),
      surfaceContainerHigh: const Color(0xFF293326),
      surfaceContainerHighest: const Color(0xFF333D2F),
      outline: const Color(0xFF9CB595),
      outlineVariant: const Color(0xFF4E5F49),
    );
    return colorScheme;
  }

  static ColorScheme _mossLightScheme() {
    const seed = Color(0xFF84B179);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF84B179),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFC7EABB),
      onPrimaryContainer: const Color(0xFF244121),
      secondary: const Color(0xFFA2CB8B),
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: const Color(0xFFD9F0CB),
      onSecondaryContainer: const Color(0xFF2E4824),
      tertiary: const Color(0xFFE8F5BD),
      onTertiary: const Color(0xFF4C521B),
      tertiaryContainer: const Color(0xFFF3F9D4),
      onTertiaryContainer: const Color(0xFF5F6626),
      surface: const Color(0xFFFAFDF5),
      onSurface: const Color(0xFF243021),
      surfaceDim: const Color(0xFFE1E9D9),
      surfaceBright: const Color(0xFFFFFFFF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF3F8EC),
      surfaceContainer: const Color(0xFFEDF4E4),
      surfaceContainerHigh: const Color(0xFFE6EEDB),
      surfaceContainerHighest: const Color(0xFFDFE9D1),
      outline: const Color(0xFF88A07E),
      outlineVariant: const Color(0xFFC7D8BF),
    );
    return colorScheme;
  }

  static ColorScheme _violetDarkScheme() {
    const seed = Color(0xFF982598);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFE491C9),
      onPrimary: const Color(0xFF3D163D),
      primaryContainer: const Color(0xFF982598),
      onPrimaryContainer: const Color(0xFFFFF1FC),
      secondary: const Color(0xFFF1E9E9),
      onSecondary: const Color(0xFF2B242B),
      secondaryContainer: const Color(0xFF6A5B66),
      onSecondaryContainer: const Color(0xFFFFF6F8),
      tertiary: const Color(0xFF15173D),
      onTertiary: const Color(0xFFE4E6FF),
      tertiaryContainer: const Color(0xFF2B2D62),
      onTertiaryContainer: const Color(0xFFF0F1FF),
      surface: const Color(0xFF15131A),
      onSurface: const Color(0xFFF1E9EF),
      surfaceDim: const Color(0xFF100D14),
      surfaceBright: const Color(0xFF312A35),
      surfaceContainerLowest: const Color(0xFF0C0910),
      surfaceContainerLow: const Color(0xFF1B1720),
      surfaceContainer: const Color(0xFF221D28),
      surfaceContainerHigh: const Color(0xFF2A2430),
      surfaceContainerHighest: const Color(0xFF352E3B),
      outline: const Color(0xFFB7A5B5),
      outlineVariant: const Color(0xFF5E505D),
    );
    return colorScheme;
  }

  static ColorScheme _violetLightScheme() {
    const seed = Color(0xFF982598);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF982598),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFE491C9),
      onPrimaryContainer: const Color(0xFF4E1C4E),
      secondary: const Color(0xFFF1E9E9),
      onSecondary: const Color(0xFF4B3E49),
      secondaryContainer: const Color(0xFFF6F0F2),
      onSecondaryContainer: const Color(0xFF584A55),
      tertiary: const Color(0xFF15173D),
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: const Color(0xFFC9CDFC),
      onTertiaryContainer: const Color(0xFF26285B),
      surface: const Color(0xFFF1E9E9),
      onSurface: const Color(0xFF241E25),
      surfaceDim: const Color(0xFFE0D4D9),
      surfaceBright: const Color(0xFFFFFFFF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF8F1F3),
      surfaceContainer: const Color(0xFFF3EBED),
      surfaceContainerHigh: const Color(0xFFECE2E6),
      surfaceContainerHighest: const Color(0xFFE6DADF),
      outline: const Color(0xFFB9A7B0),
      outlineVariant: const Color(0xFFDCCFD5),
    );
    return colorScheme;
  }

  static ColorScheme _slateDarkScheme() {
    const seed = Color(0xFF30364F);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFACBAC4),
      onPrimary: const Color(0xFF25313B),
      primaryContainer: const Color(0xFF4D5968),
      onPrimaryContainer: const Color(0xFFF2F6F8),
      secondary: const Color(0xFFE1D9BC),
      onSecondary: const Color(0xFF3E392A),
      secondaryContainer: const Color(0xFF6A634E),
      onSecondaryContainer: const Color(0xFFFDF7E6),
      tertiary: const Color(0xFFF0F0DB),
      onTertiary: const Color(0xFF353528),
      tertiaryContainer: const Color(0xFF676653),
      onTertiaryContainer: const Color(0xFFFFFEEA),
      surface: const Color(0xFF171B25),
      onSurface: const Color(0xFFF1F1EA),
      surfaceDim: const Color(0xFF10131A),
      surfaceBright: const Color(0xFF313745),
      surfaceContainerLowest: const Color(0xFF0B0E14),
      surfaceContainerLow: const Color(0xFF1A1F2A),
      surfaceContainer: const Color(0xFF222836),
      surfaceContainerHigh: const Color(0xFF2A3140),
      surfaceContainerHighest: const Color(0xFF363E4E),
      outline: const Color(0xFFAFB4B5),
      outlineVariant: const Color(0xFF5E6470),
    );
    return colorScheme;
  }

  static ColorScheme _slateLightScheme() {
    const seed = Color(0xFF30364F);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF30364F),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFACBAC4),
      onPrimaryContainer: const Color(0xFF20263B),
      secondary: const Color(0xFFE1D9BC),
      onSecondary: const Color(0xFF4A4333),
      secondaryContainer: const Color(0xFFF2ECD6),
      onSecondaryContainer: const Color(0xFF5B533F),
      tertiary: const Color(0xFFF0F0DB),
      onTertiary: const Color(0xFF4B4B3A),
      tertiaryContainer: const Color(0xFFF7F7E8),
      onTertiaryContainer: const Color(0xFF5D5D48),
      surface: const Color(0xFFF0F0DB),
      onSurface: const Color(0xFF242831),
      surfaceDim: const Color(0xFFD9DCCE),
      surfaceBright: const Color(0xFFFFFFFF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF7F7F0),
      surfaceContainer: const Color(0xFFF2F2E7),
      surfaceContainerHigh: const Color(0xFFE9ECE4),
      surfaceContainerHighest: const Color(0xFFE2E5E0),
      outline: const Color(0xFFB5B8B9),
      outlineVariant: const Color(0xFFD6D9D8),
    );
    return colorScheme;
  }

  static ColorScheme _oceanDarkScheme() {
    const seed = Color(0xFF1C4D8D);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF4988C4),
      onPrimary: const Color(0xFF062A57),
      primaryContainer: const Color(0xFF1C4D8D),
      onPrimaryContainer: const Color(0xFFEAF4FF),
      secondary: const Color(0xFFBDE8F5),
      onSecondary: const Color(0xFF173A47),
      secondaryContainer: const Color(0xFF426976),
      onSecondaryContainer: const Color(0xFFF0FCFF),
      tertiary: const Color(0xFF0F2854),
      onTertiary: const Color(0xFFDDE8FF),
      tertiaryContainer: const Color(0xFF274170),
      onTertiaryContainer: const Color(0xFFF0F4FF),
      surface: const Color(0xFF0F1724),
      onSurface: const Color(0xFFE8EDF5),
      surfaceDim: const Color(0xFF0A111B),
      surfaceBright: const Color(0xFF2A3646),
      surfaceContainerLowest: const Color(0xFF060B13),
      surfaceContainerLow: const Color(0xFF121B29),
      surfaceContainer: const Color(0xFF182231),
      surfaceContainerHigh: const Color(0xFF202B3B),
      surfaceContainerHighest: const Color(0xFF2A3546),
      outline: const Color(0xFF92A8BF),
      outlineVariant: const Color(0xFF4A5C71),
    );
    return colorScheme;
  }

  static ColorScheme _oceanLightScheme() {
    const seed = Color(0xFF1C4D8D);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF1C4D8D),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFF4988C4),
      onPrimaryContainer: const Color(0xFFFFFFFF),
      secondary: const Color(0xFFBDE8F5),
      onSecondary: const Color(0xFF244554),
      secondaryContainer: const Color(0xFFD9F2FA),
      onSecondaryContainer: const Color(0xFF315463),
      tertiary: const Color(0xFF0F2854),
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: const Color(0xFFC8DCF8),
      onTertiaryContainer: const Color(0xFF1D3862),
      surface: const Color(0xFFF4FAFD),
      onSurface: const Color(0xFF1C2A39),
      surfaceDim: const Color(0xFFDCE8F0),
      surfaceBright: const Color(0xFFFFFFFF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF1F7FB),
      surfaceContainer: const Color(0xFFEBF3F8),
      surfaceContainerHigh: const Color(0xFFE5EEF5),
      surfaceContainerHighest: const Color(0xFFDDE8F1),
      outline: const Color(0xFF90AAC0),
      outlineVariant: const Color(0xFFC7D8E6),
    );
    return colorScheme;
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required Color inputFillColor,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardColor: colorScheme.surfaceContainerLow,
      dividerColor: colorScheme.outlineVariant,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      pageTransitionsTheme: _pageTransitionsTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.secondaryContainer,
        secondarySelectedColor: colorScheme.secondaryContainer,
        disabledColor: colorScheme.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: textTheme.bodyMedium!,
        secondaryLabelStyle: textTheme.bodyMedium!.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: _inputDecorationTheme(
        fillColor: inputFillColor,
        hintColor: colorScheme.onSurfaceVariant,
        focusColor: colorScheme.primary,
        enabledBorderColor: colorScheme.outlineVariant,
        textColor: colorScheme.onSurface,
      ),
    );
  }

  static TextTheme _textTheme({
    required TextTheme base,
    required Color ink,
    required Color muted,
  }) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: ink,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: ink,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme({
    required Color fillColor,
    required Color hintColor,
    required Color focusColor,
    required Color enabledBorderColor,
    required Color textColor,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      labelStyle: GoogleFonts.roboto(
        color: hintColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: GoogleFonts.roboto(
        color: hintColor,
        fontSize: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: enabledBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: enabledBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: focusColor, width: 1.6),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Color(0xFFBA1A1A), width: 1.2),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Color(0xFFBA1A1A), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      prefixIconColor: textColor,
    );
  }

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color shellStart(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color shellEnd(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color cardBackground(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerLow;

  static Color cardBorder(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static Color actionSurface(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainer;

  static Color dockDivider(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static Color dockInactive(BuildContext context) => Colors.transparent;

  static Color dockActive(BuildContext context) =>
      Theme.of(context).colorScheme.secondaryContainer;

  static Color primaryButton(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color primaryButtonForeground(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;

  static PageTransitionsTheme _pageTransitionsTheme() {
    const builder = _FadeOnlyPageTransitionsBuilder();
    return const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: builder,
        TargetPlatform.iOS: builder,
        TargetPlatform.linux: builder,
        TargetPlatform.macOS: builder,
        TargetPlatform.windows: builder,
        TargetPlatform.fuchsia: builder,
      },
    );
  }
}

class _FadeOnlyPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeOnlyPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Easing.standardDecelerate,
        reverseCurve: Easing.standardAccelerate,
      ),
      child: child,
    );
  }
}
