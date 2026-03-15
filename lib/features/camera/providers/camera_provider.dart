import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/filter_model.dart';
import '../../../core/models/effect_model.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../native_plugins/camera_engine/camera_engine.dart';
import '../models/camera_state.dart';

class CameraNotifier extends StateNotifier<CameraState> {
  CameraNotifier() : super(const CameraState());

  Timer? _recordingTimer;

  // MARK: - 초기화

  Future<void> initialize({bool frontCamera = true}) async {
    if (state.status == CameraStatus.initializing) {
      debugPrint('[CameraProvider] initialize() 이미 진행 중 — 중복 호출 무시');
      return;
    }
    debugPrint('[CameraProvider] initialize() 시작 frontCamera=$frontCamera');
    state = state.copyWith(status: CameraStatus.initializing);
    try {
      debugPrint('[CameraProvider] CameraEngine.initialize() 호출 중...');
      final textureId = await CameraEngine.initialize(frontCamera: frontCamera);
      debugPrint('[CameraProvider] textureId=$textureId 반환됨');

      // 마지막 사용 필터 복원 (없으면 효과 없음)
      final prefs = StorageService.prefs;
      FilterModel? lastFilter;
      if (prefs.lastUsedFilterId != null) {
        lastFilter = FilterData.byId(prefs.lastUsedFilterId!);
      }
      debugPrint('[CameraProvider] 초기 필터: ${lastFilter?.id ?? '없음'}');

      state = state.copyWith(
        status: CameraStatus.ready,
        textureId: textureId,
        isFrontCamera: frontCamera,
        activeFilter: lastFilter,
        filterIntensity: lastFilter != null ? prefs.intensityFor(lastFilter.id) : 1.0,
      );

      // 필터 바로 적용 (초기 필터 없으면 효과 없음)
      debugPrint('[CameraProvider] _applyCurrentFilter() 호출');
      if (lastFilter == null) {
        await CameraEngine.setFilter(lutFileName: '', intensity: 0.0);
      } else {
        await _applyCurrentFilter();
      }

      debugPrint('[CameraProvider] 초기화 완료 ✓');

      // 비율 동기화 (프리뷰와 사진 저장 크롭 일치)
      await CameraEngine.setAspectRatio(state.aspectRatio.nativeKey);


    } catch (e, st) {
      debugPrint('[CameraProvider] ❌ 초기화 실패: $e\n$st');
      state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    CameraEngine.dispose();
    super.dispose();
  }

  Future<void> disposeCamera() async {
    await CameraEngine.dispose();
    state = const CameraState();
  }

  // MARK: - 즐겨찾기 갱신 (FilterScrollBar 리빌드 트리거)

  void refreshFavorites() {
    state = state.copyWith(favoritesVersion: state.favoritesVersion + 1);
  }

  // MARK: - 필터 변경

  Future<void> selectFilter(FilterModel filter) async {
    if (state.activeFilter?.id == filter.id) return;

    HapticUtils.filterChange();

    final prefs = StorageService.prefs;
    final intensity = prefs.intensityFor(filter.id);

    state = state.copyWith(
      activeFilter: filter,
      filterIntensity: intensity,
    );

    await _applyCurrentFilter();

    // 마지막 사용 필터 저장
    prefs.lastUsedFilterId = filter.id;
    prefs.save();
  }

  // UI 상태만 즉시 반영 (슬라이더 드래그 중 호출)
  void setFilterIntensityUI(double intensity) {
    state = state.copyWith(filterIntensity: intensity);
  }

  // 네이티브 호출만 (쓰로틀 후 호출)
  Future<void> applyFilterIntensityNative(double intensity) async {
    state = state.copyWith(filterIntensity: intensity);
    await _applyCurrentFilter();
  }

  // Hive 저장만 (onChangeEnd에서 호출)
  void saveFilterIntensity(double intensity) {
    if (state.activeFilter != null) {
      StorageService.prefs.setIntensity(state.activeFilter!.id, intensity);
    }
  }

  // 기존 메서드 유지 (필터 선택 시 등 내부 사용)
  Future<void> setFilterIntensity(double intensity) async {
    state = state.copyWith(filterIntensity: intensity);
    await _applyCurrentFilter();
    if (state.activeFilter != null) {
      StorageService.prefs.setIntensity(state.activeFilter!.id, intensity);
    }
  }

  Future<void> clearFilter() async {
    state = state.copyWith(clearFilter: true, filterIntensity: 0.0);
    await CameraEngine.setFilter(lutFileName: '', intensity: 0.0);
  }

  Future<void> _applyCurrentFilter() async {
    final filter = state.activeFilter;
    if (filter == null) return;

    await CameraEngine.setFilter(
      lutFileName: filter.lutFileName,
      intensity: state.filterIntensity,
    );
  }

  // MARK: - 이펙트

  Future<void> setEffect(EffectType type, double intensity) async {
    final newEffects = Map<EffectType, double>.from(state.effects);
    newEffects[type] = intensity;
    state = state.copyWith(effects: newEffects);

    await CameraEngine.setEffect(
      effectType: type.name,
      intensity: intensity,
    );
  }

  // MARK: - 사진 촬영

  Future<void> capturePhoto() async {
    if (!state.isReady) return;
    HapticUtils.shutter();
    state = state.copyWith(status: CameraStatus.capturing);

    try {
      final prefs = StorageService.prefs;
      final path = prefs.isSilentShutter
          ? await CameraEngine.capturePhotoSilent()
          : await CameraEngine.capturePhoto();
      state = state.copyWith(
        status: CameraStatus.ready,
        lastCapturedPath: path,
      );

      // 촬영 횟수 증가
      prefs.totalPhotosCapture++;
      prefs.save();

      HapticUtils.saveSuccess();
    } catch (e) {
      state = state.copyWith(
        status: CameraStatus.ready,
        errorMessage: e.toString(),
      );
    }
  }

  // MARK: - 카메라 제어

  Future<void> flipCamera() async {
    HapticUtils.cameraFlip();
    final isFront = !state.isFrontCamera;
    state = state.copyWith(isFlipping: true);
    await CameraEngine.flipCamera();
    await Future.delayed(const Duration(milliseconds: 100)); // blur가 glitch 커버
    state = state.copyWith(isFrontCamera: isFront, isFlipping: false);
  }

  Future<void> setExposure(double ev) async {
    final clampedEV = ev.clamp(-2.0, 2.0);
    state = state.copyWith(exposureEV: clampedEV);
    await CameraEngine.setExposure(clampedEV);
  }

  Future<void> setZoom(double zoom) async {
    final clampedZoom = zoom.clamp(1.0, 3.0);
    HapticUtils.zoomStep();
    state = state.copyWith(zoom: clampedZoom);
    await CameraEngine.setZoom(clampedZoom);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  // MARK: - 비율 전환

  Future<void> setAspectRatio(CameraAspectRatio ratio) async {
    state = state.copyWith(aspectRatio: ratio);
    await CameraEngine.setAspectRatio(ratio.nativeKey);
  }

  // MARK: - 카메라 모드 전환

  void toggleCameraMode() {
    if (state.isRecording) return;
    final newMode = state.cameraMode == CameraMode.photo ? CameraMode.video : CameraMode.photo;
    state = state.copyWith(cameraMode: newMode);
    HapticUtils.filterChange();
  }

  // MARK: - 동영상 녹화

  Future<void> startRecording() async {
    if (!state.isReady || state.isRecording) return;
    HapticUtils.shutter();
    state = state.copyWith(isRecording: true, recordingSeconds: 0);

    try {
      await CameraEngine.startRecording();
    } catch (e) {
      debugPrint('[CameraProvider] ❌ 녹화 시작 실패: $e');
      state = state.copyWith(isRecording: false, recordingSeconds: 0);
      return;
    }

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isRecording) {
        state = state.copyWith(recordingSeconds: state.recordingSeconds + 1);
      }
    });
  }

  Future<void> stopRecording() async {
    if (!state.isRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      final path = await CameraEngine.stopRecording();
      HapticUtils.saveSuccess();
      state = state.copyWith(
        isRecording: false,
        recordingSeconds: 0,
        lastCapturedPath: path,
      );
    } catch (_) {
      // 네이티브 실패 시에도 상태는 반드시 리셋
      state = state.copyWith(isRecording: false, recordingSeconds: 0);
    }
  }
}

final cameraProvider =
    StateNotifierProvider<CameraNotifier, CameraState>((ref) {
  return CameraNotifier();
});
