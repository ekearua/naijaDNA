import 'package:flutter/material.dart';

class AppTheme {
  static const String headlineFontFamily = 'Merriweather';
  static const String bodyFontFamily = 'Inter';

  static const Color primary = Color(0xFF006B3F);
  static const Color primaryContainer = Color(0xFF008751);
  static const Color accent = Color(0xFF2A9D6A);

  static const Color bg = Color(0xFFF9F9F8);
  static const Color bgSoft = Color(0xFFF1F3EF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEDEEEB);
  static const Color divider = Color(0xFFCBD5C8);

  static const Color textPrimary = Color(0xFF191C1C);
  static const Color textSecondary = Color(0xFF52605A);
  static const Color textMeta = Color(0xFF6F7974);

  static const Color breaking = Color(0xFFC84C3B);
  static const Color business = Color(0xFF305F9A);
  static const Color sports = Color(0xFFDD8A32);
  static const Color tech = Color(0xFF19756A);
  static const Color entertainment = Color(0xFF7C5BA5);
  static const Color warning = Color(0xFFB8861E);
  static const Color success = Color(0xFF2C7A4B);

  static const Color darkBg = Color(0xFF101514);
  static const Color darkBgSoft = Color(0xFF17201E);
  static const Color darkSurface = Color(0xFF18211F);
  static const Color darkSurfaceMuted = Color(0xFF24312E);
  static const Color darkDivider = Color(0xFF31403B);
  static const Color darkTextPrimary = Color(0xFFF3F5F2);
  static const Color darkTextSecondary = Color(0xFFD4DBD6);
  static const Color darkTextMeta = Color(0xFFABB7B0);

  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static LinearGradient editorialGradient(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF12352A), Color(0xFF0D221B)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0A6C40), Color(0xFF008751)],
    );
  }

  static List<BoxShadow> ambientShadow(Brightness brightness) {
    return [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: brightness == Brightness.dark ? 0.18 : 0.06,
        ),
        blurRadius: brightness == Brightness.dark ? 28 : 22,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? darkBg : bg;
    final backgroundSoft = isDark ? darkBgSoft : bgSoft;
    final panel = isDark ? darkSurface : surface;
    final mutedPanel = isDark ? darkSurfaceMuted : surfaceMuted;
    final ink = isDark ? darkTextPrimary : textPrimary;
    final inkSoft = isDark ? darkTextSecondary : textSecondary;
    final rule = isDark ? darkDivider : divider;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
          primary: primary,
          secondary: accent,
        ).copyWith(
          primary: primary,
          primaryContainer: primaryContainer,
          secondary: accent,
          surface: panel,
          onSurface: ink,
          outlineVariant: rule.withValues(alpha: isDark ? 0.9 : 0.6),
          error: breaking,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: rule.withValues(alpha: isDark ? 0.85 : 0.5),
      hintColor: inkSoft,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: bodyFontFamily,
      textTheme: isDark ? _textThemeDark : _textThemeLight,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: (isDark ? _textThemeDark : _textThemeLight).titleLarge
            ?.copyWith(color: ink, fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: panel.withValues(alpha: isDark ? 0.92 : 0.96),
        indicatorColor: primary.withValues(alpha: isDark ? 0.28 : 0.12),
        height: 72,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: bodyFontFamily,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? primaryContainer : inkSoft,
            letterSpacing: 0.1,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primaryContainer : inkSoft,
            size: 22,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: bodyFontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: rule.withValues(alpha: isDark ? 0.9 : 0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: bodyFontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontFamily: bodyFontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: mutedPanel,
        hintStyle: TextStyle(color: inkSoft, fontSize: 15),
        labelStyle: TextStyle(color: inkSoft, fontSize: 14),
        prefixIconColor: inkSoft,
        suffixIconColor: inkSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: rule.withValues(alpha: 0.16)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: rule.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: primaryContainer.withValues(alpha: 0.85),
            width: 1.25,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: breaking, width: 1.1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: breaking, width: 1.25),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: mutedPanel,
        selectedColor: primary,
        side: BorderSide(color: rule.withValues(alpha: isDark ? 0.75 : 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: TextStyle(
          color: ink,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: inkSoft,
        textColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? darkSurfaceMuted : textPrimary,
        contentTextStyle: TextStyle(color: isDark ? darkTextPrimary : surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryContainer,
        linearTrackColor: rule.withValues(alpha: isDark ? 0.35 : 0.18),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  static const TextTheme _textThemeLight = TextTheme(
    headlineLarge: TextStyle(
      fontFamily: headlineFontFamily,
      fontSize: 28,
      height: 1.08,
      fontWeight: FontWeight.w800,
      color: textPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: headlineFontFamily,
      fontSize: 23,
      height: 1.12,
      fontWeight: FontWeight.w700,
      color: textPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: headlineFontFamily,
      fontSize: 19,
      height: 1.18,
      fontWeight: FontWeight.w700,
      color: textPrimary,
    ),
    titleLarge: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: textPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: textPrimary,
      letterSpacing: 0.2,
    ),
    bodyLarge: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 16,
      height: 1.5,
      color: textPrimary,
    ),
    bodyMedium: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 14,
      height: 1.48,
      color: textPrimary,
    ),
    bodySmall: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 12,
      height: 1.4,
      color: textSecondary,
      fontWeight: FontWeight.w600,
    ),
    labelLarge: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: textPrimary,
    ),
    labelMedium: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: textSecondary,
      letterSpacing: 0.4,
    ),
  );

  static const TextTheme _textThemeDark = TextTheme(
    headlineLarge: TextStyle(
      fontFamily: headlineFontFamily,
      fontSize: 28,
      height: 1.08,
      fontWeight: FontWeight.w800,
      color: darkTextPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: headlineFontFamily,
      fontSize: 23,
      height: 1.12,
      fontWeight: FontWeight.w700,
      color: darkTextPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: headlineFontFamily,
      fontSize: 19,
      height: 1.18,
      fontWeight: FontWeight.w700,
      color: darkTextPrimary,
    ),
    titleLarge: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: darkTextPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: darkTextPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: darkTextPrimary,
      letterSpacing: 0.2,
    ),
    bodyLarge: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 16,
      height: 1.5,
      color: darkTextPrimary,
    ),
    bodyMedium: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 14,
      height: 1.48,
      color: darkTextPrimary,
    ),
    bodySmall: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 12,
      height: 1.4,
      color: darkTextSecondary,
      fontWeight: FontWeight.w600,
    ),
    labelLarge: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: darkTextPrimary,
    ),
    labelMedium: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: darkTextSecondary,
      letterSpacing: 0.4,
    ),
  );
}

Color categoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'world':
    case 'world news':
    case 'breaking':
    case 'breaking news':
    case 'politics':
      return AppTheme.breaking;
    case 'business':
      return AppTheme.business;
    case 'health':
      return const Color(0xFF0F9D58);
    case 'science':
      return const Color(0xFF2563EB);
    case 'sports':
      return AppTheme.sports;
    case 'technology':
    case 'tech':
      return AppTheme.tech;
    case 'entertainment':
    case 'lifestyle':
      return AppTheme.entertainment;
    default:
      return AppTheme.primary;
  }
}
