import 'package:hive_flutter/hive_flutter.dart';

part 'effect_model.g.dart';

@HiveType(typeId: 2)
enum EffectType {
  @HiveField(0)
  dreamyGlow, // 시그니처: CIBloom + Gaussian Blur (Free)

  @HiveField(1)
  filmGrain, // CIRandomGenerator + CIBlendMode (Free)

  @HiveField(2)
  dustTexture, // 오버레이 이미지 블렌딩 (Pro)

  @HiveField(3)
  lightLeak, // 그라디언트 오버레이 (Pro)

  @HiveField(4)
  dateStamp, // 촬영 날짜 오버레이 (Pro)
}

extension EffectTypeExt on EffectType {
  String get displayName {
    switch (this) {
      case EffectType.dreamyGlow:
        return 'Dreamy Glow';
      case EffectType.filmGrain:
        return 'Film Grain';
      case EffectType.dustTexture:
        return 'Dust';
      case EffectType.lightLeak:
        return 'Light Leak';
      case EffectType.dateStamp:
        return 'Date';
    }
  }

  bool get isPro {
    switch (this) {
      case EffectType.dreamyGlow:
      case EffectType.filmGrain:
        return false;
      case EffectType.dustTexture:
      case EffectType.lightLeak:
      case EffectType.dateStamp:
        return true;
    }
  }

  bool get hasIntensity => this != EffectType.dateStamp;
}
