import 'package:flutter/material.dart';

/// 深色黑板風格（與 iPhone 版相同色系）
class AppColors {
  static const background = Color(0xFF000000);
  static const chalkboard = Color(0xFF121714);
  static const card = Color(0xFF1A201C);
  static const chalkYellow = Color(0xFF8C7A4C);
  static const chalkYellowBright = Color(0xFFD6BE78);
  static const chalkWhite = Color(0xFFC7C7C0);
  static const muted = Color(0xFF7D827D);
  static const recordRed = Color(0xFFB8423C);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.chalkYellowBright,
      secondary: AppColors.chalkYellow,
      surface: AppColors.chalkboard,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.chalkWhite,
      elevation: 0,
      centerTitle: false,
    ),
    dividerColor: Colors.white12,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.chalkWhite,
      displayColor: AppColors.chalkWhite,
    ),
  );
}
