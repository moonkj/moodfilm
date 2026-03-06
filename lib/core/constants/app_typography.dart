import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const String _pretendard = 'Pretendard';

  // H1 — 섹션 타이틀
  static const TextStyle h1 = TextStyle(
    fontFamily: _pretendard,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
    color: AppColors.textPrimary,
  );

  // H2 — 서브 타이틀
  static const TextStyle h2 = TextStyle(
    fontFamily: _pretendard,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 26 / 18,
    color: AppColors.textPrimary,
  );

  // Body — 본문
  static const TextStyle body = TextStyle(
    fontFamily: _pretendard,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
    color: AppColors.textPrimary,
  );

  // Caption — 보조 텍스트
  static const TextStyle caption = TextStyle(
    fontFamily: _pretendard,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 18 / 12,
    color: AppColors.textSecondary,
  );

  // Filter Name — 필터 이름 (SF Pro Rounded fallback)
  static const TextStyle filterName = TextStyle(
    fontFamily: _pretendard,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
  );

  // Filter Label — 영문 라벨
  static const TextStyle filterLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );

  // Pro Badge
  static const TextStyle proBadge = TextStyle(
    fontFamily: _pretendard,
    fontSize: 9,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.5,
  );
}
