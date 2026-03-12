import 'package:flutter/services.dart';

/// 갤러리 이미지 필터 처리용 엔진 (편집 화면)
/// 실시간 프리뷰가 아닌 Full-resolution 처리
class FilterEngine {
  FilterEngine._();

  static const MethodChannel _channel =
      MethodChannel('com.moodfilm/filter_engine');

  /// 이미지에 LUT 필터 + 이펙트 적용 후 저장
  /// [sourcePath] 원본 이미지 경로
  /// [lutFileName] .cube 파일명
  /// [intensity] 0.0 ~ 1.0
  /// [adjustments] 슬라이더 조정값
  /// [effects] 이펙트 타입 → 강도
  /// Returns: 처리된 이미지 파일 경로
  static Future<String?> processImage({
    required String sourcePath,
    required String lutFileName,
    required double intensity,
    Map<String, double>? adjustments,
    Map<String, double>? effects,
    bool saveToGallery = false,
  }) async {
    return _channel.invokeMethod<String>('processImage', {
      'sourcePath': sourcePath,
      'lutFile': lutFileName,
      'intensity': intensity,
      'adjustments': adjustments ?? {},
      'effects': effects ?? {},
      'saveToGallery': saveToGallery,
    });
  }

  /// 동영상에 LUT 필터 적용 후 갤러리 저장
  /// [sourcePath] 원본 동영상 경로
  /// [lutFileName] .cube 파일명
  /// [intensity] 0.0 ~ 1.0
  /// [effects] 이펙트 타입 → 강도
  /// Returns: 처리된 동영상 파일 경로
  static Future<String?> processVideo({
    required String sourcePath,
    required String lutFileName,
    required double intensity,
    Map<String, double>? effects,
    bool saveToGallery = true,
  }) async {
    return _channel.invokeMethod<String>('processVideo', {
      'sourcePath': sourcePath,
      'lutFile': lutFileName,
      'intensity': intensity,
      'effects': effects ?? {},
      'saveToGallery': saveToGallery,
    });
  }

  /// 동영상 첫 번째 프레임을 이미지 파일로 추출
  /// Returns: 추출된 프레임 이미지 경로
  static Future<String?> extractVideoFrame({
    required String sourcePath,
  }) async {
    return _channel.invokeMethod<String>('extractVideoFrame', {
      'sourcePath': sourcePath,
    });
  }

  /// 이미지 썸네일 생성 (필터 미리보기용)
  /// Returns: 썸네일 바이트 데이터
  static Future<List<int>?> generateThumbnail({
    required String sourcePath,
    required String lutFileName,
    int size = 120,
  }) async {
    final result = await _channel.invokeMethod<List<dynamic>>(
      'generateThumbnail',
      {
        'sourcePath': sourcePath,
        'lutFile': lutFileName,
        'size': size,
      },
    );
    return result?.cast<int>();
  }
}
