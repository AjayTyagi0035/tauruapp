import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF0F766E);
  static const primaryLight = Color(0xFF14B8A6);
  static const primaryDark = Color(0xFF134E4A);
  static const surfaceTint = Color(0xFFE6F4F2);
  static const background = Color(0xFFF2F7F6);
  static const fieldFill = Color(0xFFF8FBFB);
  static const border = Color(0xFFD3E4E1);
  static const textPrimary = Color(0xFF0F2A28);
  static const textMuted = Color(0xFF5F7471);
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);

  static const headerGradient = LinearGradient(
    colors: [primaryDark, primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: AppColors.background,
    );

    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fieldFill,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: Colors.black26),
        prefixIconColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: outline(AppColors.border),
        enabledBorder: outline(AppColors.border),
        focusedBorder: outline(AppColors.primary, 2),
        errorBorder: outline(AppColors.error),
        focusedErrorBorder: outline(AppColors.error, 2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
