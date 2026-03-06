import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette (계획서 6-4 기준)
  static const Color primary = Color(0xFFFBF5EE);      // 크림 화이트 (배경)
  static const Color secondary = Color(0xFFF5E6D8);    // 피치 크림 (카드)
  static const Color accent = Color(0xFFC8A2D0);       // 라벤더 (포인트)

  // Text
  static const Color textPrimary = Color(0xFF3D3531);  // 다크 브라운
  static const Color textSecondary = Color(0xFF8A7F78); // 웜 그레이

  // Camera
  static const Color cameraBg = Color(0xFF000000);     // 순수 블랙
  static const Color shutter = Color(0xFFFFFFFF);      // 화이트 서터

  // Functional
  static const Color proBadge = Color(0xFFD4A574);     // 골드 톤
  static const Color newBadge = accent;
  static const Color error = Color(0xFFE57373);
  static const Color success = Color(0xFF81C784);

  // Dark Mode
  static const Color darkBg = Color(0xFF1A1210);       // 웜 다크 브라운
  static const Color darkSurface = Color(0xFF2D2420);  // 카드/컨테이너

  // Liquid Glass (glassmorphism)
  static const Color glassLight = Color(0x14FFFFFF);   // opacity 0.08
  static const Color glassBorder = Color(0x1AFFFFFF);  // opacity 0.10

  // Filter category colors (썸네일 배경 fallback)
  static const Color warmTone = Color(0xFFF5E6D8);
  static const Color coolTone = Color(0xFFD8EBF5);
  static const Color filmTone = Color(0xFFE8E0D8);
  static const Color aestheticTone = Color(0xFFF0D8F5);
}
