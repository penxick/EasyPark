import 'package:flutter/material.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.foreground,
      error: AppColors.destructive,
    ),
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.border,
    textTheme:
        const TextTheme(
          headlineMedium: AppTypography.heading1,
          headlineSmall: AppTypography.heading2,
          titleLarge: AppTypography.heading3,
          titleMedium: AppTypography.title,
          bodyLarge: AppTypography.body,
          bodyMedium: AppTypography.body,
          bodySmall: AppTypography.small,
          labelLarge: AppTypography.button,
        ).apply(
          bodyColor: AppColors.foreground,
          displayColor: AppColors.foreground,
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.heading,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: AppColors.heading,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.input,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: AppTypography.body.copyWith(color: AppColors.mutedForeground),
      errorStyle: AppTypography.small.copyWith(color: AppColors.destructive),
      errorMaxLines: 4,
      border: _inputBorder(Colors.transparent),
      enabledBorder: _inputBorder(Colors.transparent),
      disabledBorder: _inputBorder(Colors.transparent),
      focusedBorder: _inputBorder(AppColors.focus, 2),
      errorBorder: _inputBorder(AppColors.destructive),
      focusedErrorBorder: _inputBorder(AppColors.destructive, 2),
    ),
  );

  static OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: color, width: width),
      );
}
