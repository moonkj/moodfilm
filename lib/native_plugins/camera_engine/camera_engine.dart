import 'package:flutter/services.dart' show MethodChannel;

/// Flutter ↔ iOS Native 카메라 엔진 Method Channel 인터페이스
/// iOS: AVFoundation + CIFilter + MTKView
class CameraEngine {
  CameraEngine._();

  static const MethodChannel _channel =
      MethodChannel('com.moodfilm/camera_engine');

/// 카메라 초기화 및 프리뷰 시작
  /// [frontCamera] true = 전면 카메라 (셀카), false = 후면
  /// Returns: Flutter Texture ID
  static Future<int> initialize({bool frontCamera = true}) async {
    final textureId = await _channel.invokeMethod<int>('initialize', {
      'frontCamera': frontCamera,
    });
    return textureId!;
  }

  /// 카메라 해제
  static Future<void> dispose() async {
    await _channel.invokeMethod('dispose');
  }

  /// LUT 필터 적용 (실시간 프리뷰)
  /// [lutFileName] .cube 파일명 (e.g. 'milk.cube')
  /// [intensity] 0.0 ~ 1.0
  static Future<void> setFilter({
    required String lutFileName,
    required double intensity,
  }) async {
    await _channel.invokeMethod('setFilter', {
      'lutFile': lutFileName,
      'intensity': intensity,
    });
  }

  /// 이펙트 적용 (Glow, Grain 등)
  static Future<void> setEffect({
    required String effectType,
    required double intensity,
  }) async {
    await _channel.invokeMethod('setEffect', {
      'effectType': effectType,
      'intensity': intensity,
    });
  }

  /// 사진 촬영 (Full-resolution)
  /// Returns: 저장된 임시 파일 경로
  static Future<String?> capturePhoto() async {
    return _channel.invokeMethod<String>('capturePhoto');
  }

  /// 전면/후면 전환
  static Future<void> flipCamera() async {
    await _channel.invokeMethod('flipCamera');
  }

  /// 노출 조정 (-2EV ~ +2EV)
  static Future<void> setExposure(double ev) async {
    await _channel.invokeMethod('setExposure', {'ev': ev});
  }

  /// 줌 설정 (1.0 ~ 3.0 디지털)
  static Future<void> setZoom(double zoom) async {
    await _channel.invokeMethod('setZoom', {'zoom': zoom});
  }

  /// 초점 포인트 설정 (탭 투 포커스)
  static Future<void> setFocusPoint(double x, double y) async {
    await _channel.invokeMethod('setFocusPoint', {'x': x, 'y': y});
  }

  /// 현재 카메라 방향 (전면/후면)
  static Future<bool> isFrontCamera() async {
    return await _channel.invokeMethod<bool>('isFrontCamera') ?? true;
  }

  /// 동영상 녹화 시작
  /// Returns: 임시 출력 파일 경로
  static Future<String> startRecording() async {
    final path = await _channel.invokeMethod<String>('startRecording');
    return path!;
  }

  /// 동영상 녹화 종료 + 갤러리 저장
  /// Returns: 저장된 파일 경로
  static Future<String?> stopRecording() async {
    return _channel.invokeMethod<String>('stopRecording');
  }
}
