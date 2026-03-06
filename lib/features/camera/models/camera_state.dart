import '../../../core/models/filter_model.dart';
import '../../../core/models/effect_model.dart';

enum CameraStatus { uninitialized, initializing, ready, capturing, error }

class CameraState {
  final CameraStatus status;
  final int? textureId;
  final bool isFrontCamera;
  final FilterModel? activeFilter;
  final double filterIntensity;
  final Map<EffectType, double> effects;
  final double exposureEV; // -2.0 ~ +2.0
  final double zoom; // 1.0 ~ 3.0
  final String? errorMessage;
  final String? lastCapturedPath;
  final bool isFlipping; // 카메라 전환 중 플래시 오버레이용

  const CameraState({
    this.status = CameraStatus.uninitialized,
    this.textureId,
    this.isFrontCamera = true,
    this.activeFilter,
    this.filterIntensity = 1.0,
    this.effects = const {},
    this.exposureEV = 0.0,
    this.zoom = 1.0,
    this.errorMessage,
    this.lastCapturedPath,
    this.isFlipping = false,
  });

  CameraState copyWith({
    CameraStatus? status,
    int? textureId,
    bool? isFrontCamera,
    FilterModel? activeFilter,
    double? filterIntensity,
    Map<EffectType, double>? effects,
    double? exposureEV,
    double? zoom,
    String? errorMessage,
    String? lastCapturedPath,
    bool? isFlipping,
  }) {
    return CameraState(
      status: status ?? this.status,
      textureId: textureId ?? this.textureId,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      activeFilter: activeFilter ?? this.activeFilter,
      filterIntensity: filterIntensity ?? this.filterIntensity,
      effects: effects ?? this.effects,
      exposureEV: exposureEV ?? this.exposureEV,
      zoom: zoom ?? this.zoom,
      errorMessage: errorMessage ?? this.errorMessage,
      lastCapturedPath: lastCapturedPath ?? this.lastCapturedPath,
      isFlipping: isFlipping ?? this.isFlipping,
    );
  }

  bool get isReady => status == CameraStatus.ready;
  bool get isCapturing => status == CameraStatus.capturing;
}
