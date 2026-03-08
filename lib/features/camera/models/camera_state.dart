import '../../../core/models/filter_model.dart';
import '../../../core/models/effect_model.dart';

enum CameraStatus { uninitialized, initializing, ready, capturing, error }
enum CameraMode { photo, video }

enum CameraAspectRatio {
  full,       // 화면 가득 (크롭 없음)
  ratio9_16,  // 9:16 세로
  ratio3_4,   // 3:4 세로
  ratio1_1,   // 1:1 정사각
  ratio4_3,   // 4:3 가로
  ratio16_9,  // 16:9 가로
}

extension CameraAspectRatioX on CameraAspectRatio {
  String get label {
    switch (this) {
      case CameraAspectRatio.full: return 'Full';
      case CameraAspectRatio.ratio9_16: return '9:16';
      case CameraAspectRatio.ratio3_4: return '3:4';
      case CameraAspectRatio.ratio1_1: return '1:1';
      case CameraAspectRatio.ratio4_3: return '4:3';
      case CameraAspectRatio.ratio16_9: return '16:9';
    }
  }

  // width / height 비율 (null = full screen)
  double? get ratio {
    switch (this) {
      case CameraAspectRatio.full: return null;
      case CameraAspectRatio.ratio9_16: return 9 / 16;
      case CameraAspectRatio.ratio3_4: return 3 / 4;
      case CameraAspectRatio.ratio1_1: return 1.0;
      case CameraAspectRatio.ratio4_3: return 4 / 3;
      case CameraAspectRatio.ratio16_9: return 16 / 9;
    }
  }

  // 네이티브 크롭 전달용 문자열 키
  // landscape 버퍼(1920×1080) 기준으로 크롭 → RotatedBox(1) 후 portrait 변환
  // 예: "4:3" 크롭 → 1440×1080 → RotatedBox → 1080×1440 = 3:4 portrait
  String get nativeKey {
    switch (this) {
      case CameraAspectRatio.full: return 'full';
      case CameraAspectRatio.ratio9_16: return '16:9'; // 무크롭(1920×1080) → 9:16 portrait
      case CameraAspectRatio.ratio3_4: return '4:3';  // 1440×1080 → 3:4 portrait
      case CameraAspectRatio.ratio1_1: return '1:1';  // 1080×1080 → 1:1 square
      case CameraAspectRatio.ratio4_3: return '3:4';  // 810×1080 → 4:3 landscape
      case CameraAspectRatio.ratio16_9: return '9:16'; // 607×1080 → 16:9 landscape
    }
  }
}

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
  final CameraMode cameraMode; // 사진 / 동영상 모드
  final bool isRecording; // 동영상 녹화 중
  final int recordingSeconds; // 녹화 경과 시간(초)
  final int favoritesVersion; // 즐겨찾기 변경 감지 (FilterScrollBar 리빌드 트리거)
  final CameraAspectRatio aspectRatio; // 카메라 비율

  const CameraState({
    this.status = CameraStatus.uninitialized,
    this.textureId,
    this.isFrontCamera = false,
    this.activeFilter,
    this.filterIntensity = 1.0,
    this.effects = const {},
    this.exposureEV = 0.0,
    this.zoom = 1.0,
    this.errorMessage,
    this.lastCapturedPath,
    this.isFlipping = false,
    this.cameraMode = CameraMode.photo,
    this.isRecording = false,
    this.recordingSeconds = 0,
    this.favoritesVersion = 0,
    this.aspectRatio = CameraAspectRatio.ratio3_4,
  });

  CameraState copyWith({
    CameraStatus? status,
    int? textureId,
    bool? isFrontCamera,
    FilterModel? activeFilter,
    bool clearFilter = false,
    double? filterIntensity,
    Map<EffectType, double>? effects,
    double? exposureEV,
    double? zoom,
    String? errorMessage,
    String? lastCapturedPath,
    bool? isFlipping,
    CameraMode? cameraMode,
    bool? isRecording,
    int? recordingSeconds,
    int? favoritesVersion,
    CameraAspectRatio? aspectRatio,
  }) {
    return CameraState(
      status: status ?? this.status,
      textureId: textureId ?? this.textureId,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      activeFilter: clearFilter ? null : (activeFilter ?? this.activeFilter),
      filterIntensity: filterIntensity ?? this.filterIntensity,
      effects: effects ?? this.effects,
      exposureEV: exposureEV ?? this.exposureEV,
      zoom: zoom ?? this.zoom,
      errorMessage: errorMessage ?? this.errorMessage,
      lastCapturedPath: lastCapturedPath ?? this.lastCapturedPath,
      isFlipping: isFlipping ?? this.isFlipping,
      cameraMode: cameraMode ?? this.cameraMode,
      isRecording: isRecording ?? this.isRecording,
      recordingSeconds: recordingSeconds ?? this.recordingSeconds,
      favoritesVersion: favoritesVersion ?? this.favoritesVersion,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }

  bool get isReady => status == CameraStatus.ready;
  bool get isCapturing => status == CameraStatus.capturing;
  bool get isVideoMode => cameraMode == CameraMode.video;
}
