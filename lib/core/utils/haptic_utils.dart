import 'package:flutter/services.dart';

/// 계획서 6-6 햅틱 피드백 스펙 구현
class HapticUtils {
  HapticUtils._();

  /// 필터 전환 — 가벼운 틱 (필터마다)
  static void filterChange() {
    HapticFeedback.selectionClick();
  }

  /// 서터 촬영 — 카메라 호환 햅틱 (AudioServicesPlaySystemSound 1108)
  static void shutter() {
    // iOS: 시스템 카메라 셔터 소리와 동일
    HapticFeedback.heavyImpact();
  }

  /// 전면/후면 전환 — 중간 강도 임팩트
  static void cameraFlip() {
    HapticFeedback.mediumImpact();
  }

  /// 줌 단계 — 가벼운 임팩트
  static void zoomStep() {
    HapticFeedback.lightImpact();
  }

  /// 즐겨찾기 토글 — 성공 피드백
  static void favoriteToggle() {
    HapticFeedback.mediumImpact();
  }

  /// 저장 완료 — success
  static void saveSuccess() {
    HapticFeedback.lightImpact();
  }
}
