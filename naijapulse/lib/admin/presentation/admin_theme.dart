import 'package:flutter/material.dart';

class AdminTheme {
  const AdminTheme._();

  static const Color background = Color(0xFFF6F1EA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFFCF8F2);
  static const Color accent = Color(0xFF0F6B4B);
  static const Color accentDark = Color(0xFF0B4F38);
  static const Color textStrong = Color(0xFF1D1B18);
  static const Color textBase = Color(0xFF3F3A34);
  static const Color textMuted = Color(0xFF5F574C);
  static const Color border = Color(0xFFC0B29E);
  static const Color cardBorder = Color(0xFFCFC3B0);
  static const Color inputFill = Color(0xFFF1E8DC);
  static const Color error = Color(0xFFC53030);

  static ThemeData of(BuildContext context) => light;

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        secondary: accentDark,
        onSecondary: Colors.white,
        tertiary: Color(0xFF2563EB),
        onTertiary: Colors.white,
        error: error,
        onError: Colors.white,
        surface: surface,
        onSurface: textStrong,
        outline: border,
        outlineVariant: cardBorder,
      ),
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      splashFactory: InkRipple.splashFactory,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(color: textStrong),
      displayMedium: base.textTheme.displayMedium?.copyWith(color: textStrong),
      displaySmall: base.textTheme.displaySmall?.copyWith(color: textStrong),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(color: textStrong),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: textStrong,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(color: textStrong),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: textStrong,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: textStrong,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        color: textStrong,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: textBase,
        height: 1.45,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: textBase,
        height: 1.4,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: textMuted,
        height: 1.35,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        color: textStrong,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        color: textStrong,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        color: textMuted,
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: const IconThemeData(color: textStrong),
      primaryIconTheme: const IconThemeData(color: textStrong),
      dividerColor: cardBorder,
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: cardBorder, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceAlt,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: cardBorder, width: 1.2),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textStrong,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: textBase,
          height: 1.45,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textStrong,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: const Color(0xFFB5F0D4),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceAlt,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: cardBorder, width: 1.1),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(
          color: textStrong,
          fontWeight: FontWeight.w600,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textStrong,
        textColor: textStrong,
        titleTextStyle: textTheme.titleSmall?.copyWith(
          color: textStrong,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: textMuted),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentDark,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF9EB7AC),
          disabledForegroundColor: Colors.white,
          textStyle: textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textStrong,
          side: const BorderSide(color: border, width: 1.2),
          textStyle: textTheme.labelLarge?.copyWith(
            color: textStrong,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textStrong),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        labelStyle: const TextStyle(
          color: Color(0xFF5A5248),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF695F52),
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: const Color(0xFF5B5146),
        suffixIconColor: const Color(0xFF5B5146),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1.8),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: const BorderSide(color: border, width: 1.0),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: textStrong,
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: surface,
        selectedColor: const Color(0xFFE3F0E8),
        secondarySelectedColor: const Color(0xFFE3F0E8),
        disabledColor: const Color(0xFFEDE5D9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
    );
  }
}
