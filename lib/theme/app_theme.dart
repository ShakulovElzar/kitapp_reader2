import 'package:flutter/material.dart';

/// Design A ("Тынч барак"): quiet off-white paper, one green accent,
/// Golos Text for the interface and Literata for headings and reading.
abstract final class AppColors {
  static const green = Color(0xFF0B6B35);
  static const greenDark = Color(0xFF06481F);
  static const greenSoft = Color(0xFFDCEEE2);
  static const ink = Color(0xFF191B19);
  static const body = Color(0xFF2A2D2A);
  static const muted = Color(0xFF5A605A);
  static const line = Color(0xFFE3E6E1);
  static const lineSoft = Color(0xFFEEF0EC);
  static const field = Color(0xFFCDD2CC);
  static const paper = Color(0xFFFAFAF7);
  static const surface = Color(0xFFEEF0EC);
  static const warm = Color(0xFF8A4B0B);
  static const danger = Color(0xFFB42318);
}

abstract final class AppFonts {
  static const ui = 'Golos Text';
  static const serif = 'Literata';
}

/// Shared text styles so every screen uses the same scale.
abstract final class AppText {
  static const pageTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const bookTitle = TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: 23,
    height: 1.15,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const section = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );
  static const body = TextStyle(
    fontSize: 15,
    height: 1.45,
    color: AppColors.body,
  );
  static const meta = TextStyle(fontSize: 13, color: AppColors.muted);
}

abstract final class AppTheme {
  static final _radius = BorderRadius.circular(10);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
      primary: AppColors.green,
      onPrimary: Colors.white,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      canvasColor: AppColors.paper,
      fontFamily: AppFonts.ui,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.ink),
        bodyMedium: TextStyle(fontSize: 15, color: AppColors.ink),
        bodySmall: TextStyle(fontSize: 13, color: AppColors.muted),
        titleLarge: TextStyle(
          fontFamily: AppFonts.serif,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.serif,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      dividerColor: AppColors.line,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surface,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: _radius),
          textStyle: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: AppColors.field),
          shape: RoundedRectangleBorder(borderRadius: _radius),
          textStyle: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(44, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 16),
        labelStyle: const TextStyle(color: AppColors.muted),
        prefixIconColor: AppColors.muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: const BorderSide(color: AppColors.field),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: const BorderSide(color: AppColors.field),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: const BorderSide(color: AppColors.green, width: 1.5),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.muted,
          selectedBackgroundColor: Colors.white,
          selectedForegroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.surface),
          textStyle: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.green
              : AppColors.field,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.green,
        inactiveTrackColor: AppColors.line,
        thumbColor: Colors.white,
        trackHeight: 3,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.green,
        linearTrackColor: AppColors.line,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 15,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: _radius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          fontFamily: AppFonts.serif,
          fontSize: 21,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 15,
          height: 1.45,
          color: AppColors.body,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.muted,
        textColor: AppColors.ink,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Colors.white,
        side: BorderSide(color: AppColors.field),
        labelStyle: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
