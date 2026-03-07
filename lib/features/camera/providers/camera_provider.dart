import 'dart:async';
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
    state = state.copyWith(status: CameraStatus.initializing);
    try {
      final textureId = await CameraEngine.initialize(frontCamera: frontCamera);

      // 마지막 사용 필터 복원
      final prefs = StorageService.prefs;
      FilterModel? lastFilter;
      if (prefs.lastUsedFilterId != null) {
        lastFilter = FilterData.byId(prefs.lastUsedFilterId!);
      }
      lastFilter ??= FilterData.all.first; // 기본: Milk

      state = state.copyWith(
        status: CameraStatus.ready,
        textureId: textureId,
        isFrontCamera: frontCamera,
        activeFilter: lastFilter,
        filterIntensity: prefs.intensityFor(lastFilter.id),
      );

      // 필터 바로 적용
      await _applyCurrentFilter();

      // 뽀샤시 기본 적용 (0.45 — 피부 보정 + 은은한 발광)
      await CameraEngine.setEffect(effectType: 'beauty', intensity: 0.45);
    } catch (e) {
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

  Future<void> setFilterIntensity(double intensity) async {
    state = state.copyWith(filterIntensity: intensity);
    await _applyCurrentFilter();

    // 강도 저장
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
    // 상태 먼저 업데이트 → UI 즉시 반응
    state = state.copyWith(isRecording: true, recordingSeconds: 0);
    // 녹화 시작 (비동기, await 불필요)
    CameraEngine.startRecording();

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
