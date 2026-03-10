import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:moodfilm/core/models/effect_model.dart';
import 'package:moodfilm/core/models/filter_model.dart';
import 'package:moodfilm/core/models/user_preferences.dart';

// ────────────────────────────────────────────────────────────
// Hive 어댑터 등록 헬퍼 (중복 등록 방지)
// ────────────────────────────────────────────────────────────
void _registerAdapters() {
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(FilterCategoryAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(FilterModelAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(EffectTypeAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(UserPreferencesAdapter());
}

void main() {
  // ────────────────────────────────────────────────────────
  // 순수 로직 (Hive 불필요)
  // ────────────────────────────────────────────────────────
  group('UserPreferences 순수 로직', () {
    late UserPreferences prefs;

    setUp(() => prefs = UserPreferences());

    // -- 기본값 --
    test('기본값: hasSeenOnboarding=false', () {
      expect(prefs.hasSeenOnboarding, false);
    });

    test('기본값: isProUser=false', () {
      expect(prefs.isProUser, false);
    });

    test('기본값: lastUsedFilterId=null', () {
      expect(prefs.lastUsedFilterId, null);
    });

    test('기본값: filterIntensities는 빈 Map이다', () {
      expect(prefs.filterIntensities, isEmpty);
    });

    test('기본값: favoriteFilterIds는 빈 List다', () {
      expect(prefs.favoriteFilterIds, isEmpty);
    });

    test('기본값: isSilentShutter=false', () {
      expect(prefs.isSilentShutter, false);
    });

    test('기본값: totalPhotosCapture=0', () {
      expect(prefs.totalPhotosCapture, 0);
    });

    // -- intensityFor --
    test('intensityFor — 저장된 커스텀 강도를 반환한다', () {
      prefs.filterIntensities['milk'] = 0.75;
      expect(prefs.intensityFor('milk'), 0.75);
    });

    test('intensityFor — 저장값 없으면 defaultIntensities를 반환한다', () {
      // FilterData.defaultIntensities['milk'] = 0.55
      expect(prefs.intensityFor('milk'), FilterData.defaultIntensities['milk']);
    });

    test('intensityFor — defaultIntensities에도 없으면 0.6을 반환한다', () {
      expect(prefs.intensityFor('completely_unknown_filter'), 0.6);
    });

    test('intensityFor — 커스텀 강도가 defaultIntensities보다 우선된다', () {
      prefs.filterIntensities['milk'] = 0.99;
      expect(prefs.intensityFor('milk'), 0.99);
    });

    test('intensityFor — 강도를 0.0으로 저장하면 0.0을 반환한다', () {
      prefs.filterIntensities['milk'] = 0.0;
      expect(prefs.intensityFor('milk'), 0.0);
    });

    // -- EffectType 확인 --
    test('EffectType.dreamyGlow는 isPro가 false다', () {
      expect(EffectType.dreamyGlow.isPro, false);
    });

    test('EffectType.lightLeak는 isPro가 true다', () {
      expect(EffectType.lightLeak.isPro, true);
    });

    test('EffectType.dateStamp는 hasIntensity가 false다', () {
      expect(EffectType.dateStamp.hasIntensity, false);
    });

    test('EffectType.dreamyGlow의 displayName은 "Dreamy Glow"다', () {
      expect(EffectType.dreamyGlow.displayName, 'Dreamy Glow');
    });
  });

  // ────────────────────────────────────────────────────────
  // Hive 연동 (setIntensity, toggleFavorite — save() 필요)
  // ────────────────────────────────────────────────────────
  group('UserPreferences Hive 연동', () {
    late Directory tempDir;
    late Box<UserPreferences> box;
    late UserPreferences prefs;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('moodfilm_up_test_');
      Hive.init(tempDir.path);
      _registerAdapters();
      box = await Hive.openBox<UserPreferences>('up_test_${tempDir.hashCode}');
      prefs = UserPreferences();
      await box.add(prefs);
    });

    tearDown(() async {
      await box.deleteFromDisk();
      await Hive.close();
    });

    test('setIntensity — filterIntensities에 값이 저장된다', () {
      prefs.setIntensity('milk', 0.8);
      expect(prefs.filterIntensities['milk'], 0.8);
    });

    test('setIntensity — 기존 값을 덮어쓴다', () {
      prefs.setIntensity('milk', 0.5);
      prefs.setIntensity('milk', 0.9);
      expect(prefs.filterIntensities['milk'], 0.9);
    });

    test('setIntensity — 여러 필터를 독립적으로 저장한다', () {
      prefs.setIntensity('milk', 0.5);
      prefs.setIntensity('cream', 0.7);
      expect(prefs.filterIntensities['milk'], 0.5);
      expect(prefs.filterIntensities['cream'], 0.7);
    });

    test('toggleFavorite — 즐겨찾기에 추가된다', () {
      prefs.toggleFavorite('milk');
      expect(prefs.favoriteFilterIds, contains('milk'));
    });

    test('toggleFavorite — 두 번 호출하면 제거된다', () {
      prefs.toggleFavorite('milk');
      prefs.toggleFavorite('milk');
      expect(prefs.favoriteFilterIds, isNot(contains('milk')));
    });

    test('toggleFavorite — 여러 필터 즐겨찾기 독립 동작', () {
      prefs.toggleFavorite('milk');
      prefs.toggleFavorite('cream');
      prefs.toggleFavorite('milk'); // milk 제거
      expect(prefs.favoriteFilterIds, isNot(contains('milk')));
      expect(prefs.favoriteFilterIds, contains('cream'));
    });

    test('intensityFor — setIntensity 이후 올바른 값을 반환한다', () {
      prefs.setIntensity('film98', 0.88);
      expect(prefs.intensityFor('film98'), 0.88);
    });
  });
}
