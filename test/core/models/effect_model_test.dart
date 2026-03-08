import 'package:flutter_test/flutter_test.dart';
import 'package:moodfilm/core/models/effect_model.dart';

void main() {
  // ────────────────────────────────────────────────────────
  // EffectType.displayName
  // ────────────────────────────────────────────────────────
  group('EffectType displayName', () {
    test('dreamyGlow → "Dreamy Glow"', () {
      expect(EffectType.dreamyGlow.displayName, 'Dreamy Glow');
    });

    test('filmGrain → "Film Grain"', () {
      expect(EffectType.filmGrain.displayName, 'Film Grain');
    });

    test('dustTexture → "Dust"', () {
      expect(EffectType.dustTexture.displayName, 'Dust');
    });

    test('lightLeak → "Light Leak"', () {
      expect(EffectType.lightLeak.displayName, 'Light Leak');
    });

    test('dateStamp → "Date"', () {
      expect(EffectType.dateStamp.displayName, 'Date');
    });

    test('모든 케이스에 displayName이 비어있지 않다', () {
      for (final type in EffectType.values) {
        expect(type.displayName.trim(), isNotEmpty,
            reason: '$type의 displayName이 비어있음');
      }
    });
  });

  // ────────────────────────────────────────────────────────
  // EffectType.isPro
  // ────────────────────────────────────────────────────────
  group('EffectType isPro', () {
    test('dreamyGlow은 무료다', () {
      expect(EffectType.dreamyGlow.isPro, false);
    });

    test('filmGrain은 무료다', () {
      expect(EffectType.filmGrain.isPro, false);
    });

    test('dustTexture는 Pro다', () {
      expect(EffectType.dustTexture.isPro, true);
    });

    test('lightLeak은 Pro다', () {
      expect(EffectType.lightLeak.isPro, true);
    });

    test('dateStamp은 Pro다', () {
      expect(EffectType.dateStamp.isPro, true);
    });
  });

  // ────────────────────────────────────────────────────────
  // EffectType.hasIntensity
  // ────────────────────────────────────────────────────────
  group('EffectType hasIntensity', () {
    test('dreamyGlow은 intensity가 있다', () {
      expect(EffectType.dreamyGlow.hasIntensity, true);
    });

    test('filmGrain은 intensity가 있다', () {
      expect(EffectType.filmGrain.hasIntensity, true);
    });

    test('dustTexture는 intensity가 있다', () {
      expect(EffectType.dustTexture.hasIntensity, true);
    });

    test('lightLeak은 intensity가 있다', () {
      expect(EffectType.lightLeak.hasIntensity, true);
    });

    test('dateStamp은 intensity가 없다', () {
      expect(EffectType.dateStamp.hasIntensity, false);
    });
  });
}
