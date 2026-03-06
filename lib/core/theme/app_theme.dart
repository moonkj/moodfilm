import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/app_dimensions.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.primary,
        colorScheme: const ColorScheme.light(
          primary: AppColors.accent,
          secondary: AppColors.secondary,
          surface: AppColors.primary,
          error: AppColors.error,
          onPrimary: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        fontFamily: 'Pretendard',
        textTheme: const TextTheme(
          headlineLarge: AppTypography.h1,
          headlineMedium: AppTypography.h2,
          bodyLarge: AppTypography.body,
          bodySmall: AppTypography.caption,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: AppTypography.h2,
        ),
        sliderTheme: SliderThemeData(
          trackHeight: AppDimensions.sliderTrackHeight,
          activeTrackColor: AppColors.accent,
          inactiveTrackColor: AppColors.accent.withOpacity(0.2),
          thumbColor: AppColors.secondary,
          overlayColor: AppColors.accent.withOpacity(0.1),
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: AppDimensions.sliderThumbSize / 2,
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTypography.filterName,
          unselectedLabelStyle: AppTypography.filterName,
          indicatorColor: AppColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        useMaterial3: true,
      );

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.darkSurface,
          surface: AppColors.darkBg,
          error: AppColors.error,
          onPrimary: Colors.white,
          onSurface: Colors.white,
        ),
        fontFamily: 'Pretendard',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        sliderTheme: SliderThemeData(
          trackHeight: AppDimensions.sliderTrackHeight,
          activeTrackColor: AppColors.accent,
          inactiveTrackColor: AppColors.accent.withOpacity(0.2),
          thumbColor: AppColors.darkSurface,
          overlayColor: AppColors.accent.withOpacity(0.1),
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: AppDimensions.sliderThumbSize / 2,
          ),
        ),
        useMaterial3: true,
      );
}
