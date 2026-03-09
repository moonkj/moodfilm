import 'package:flutter_test/flutter_test.dart';
import 'package:moodfilm/core/models/filter_model.dart';

void main() {
  // ────────────────────────────────────────────────────────
  // FilterModel
  // ────────────────────────────────────────────────────────
  group('FilterModel', () {
    test('필수 필드로 생성된다', () {
      final f = FilterModel(
        id: 'milk',
        name: 'Milk',
        category: FilterCategory.warm,
        lutFileName: 'milk.cube',
      );

      expect(f.id, 'milk');
      expect(f.name, 'Milk');
      expect(f.category, FilterCategory.warm);
      expect(f.lutFileName, 'milk.cube');
    });

    test('기본값: isPro=false, isFavorite=false, lastIntensity=1.0, isNew=false', () {
      final f = FilterModel(
        id: 'milk',
        name: 'Milk',
        category: FilterCategory.warm,
        lutFileName: 'milk.cube',
      );

      expect(f.isPro, false);
      expect(f.isFavorite, false);
      expect(f.lastIntensity, 1.0);
      expect(f.isNew, false);
      expect(f.packId, null);
      expect(f.description, '');
    });

    test('thumbnailAssetPath는 assets/thumbnails/<id>.jpg 형식이다', () {
      final f = FilterModel(
        id: 'soft_pink',
        name: 'Soft Pink',
        category: FilterCategory.aesthetic,
        lutFileName: 'soft_pink.cube',
      );

      expect(f.thumbnailAssetPath, 'assets/thumbnails/soft_pink.jpg');
    });

    test('toString에 id, name, isPro 정보가 포함된다', () {
      final f = FilterModel(
        id: 'butter',
        name: 'Butter',
        category: FilterCategory.warm,
        lutFileName: 'butter.cube',
        isPro: true,
      );

      expect(f.toString(), contains('butter'));
      expect(f.toString(), contains('Butter'));
      expect(f.toString(), contains('isPro: true'));
    });

    test('isFavorite은 변경 가능하다', () {
      final f = FilterModel(
        id: 'milk',
        name: 'Milk',
        category: FilterCategory.warm,
        lutFileName: 'milk.cube',
      );

      f.isFavorite = true;
      expect(f.isFavorite, true);

      f.isFavorite = false;
      expect(f.isFavorite, false);
    });
  });

  // ────────────────────────────────────────────────────────
  // FilterData
  // ────────────────────────────────────────────────────────
  group('FilterData', () {
    test('전체 필터가 26종이다', () {
      expect(FilterData.all.length, 26);
    });

    test('모든 id가 고유하다', () {
      final ids = FilterData.all.map((f) => f.id).toList();
      final uniqueIds = ids.toSet();
      expect(ids.length, uniqueIds.length);
    });

    test('모든 lutFileName이 .cube로 끝난다', () {
      for (final f in FilterData.all) {
        expect(f.lutFileName.endsWith('.cube'), true,
            reason: '${f.id}의 lutFileName이 .cube가 아님: ${f.lutFileName}');
      }
    });

    test('byId — 존재하는 id로 필터를 찾는다', () {
      final f = FilterData.byId('milk');
      expect(f, isNotNull);
      expect(f!.name, 'Milk');
    });

    test('byId — 존재하지 않는 id는 null을 반환한다', () {
      expect(FilterData.byId('unknown_filter_xyz'), isNull);
    });

    test('byCategory — warm 카테고리 필터를 반환한다', () {
      final warmFilters = FilterData.byCategory(FilterCategory.warm);
      expect(warmFilters, isNotEmpty);
      for (final f in warmFilters) {
        expect(f.category, FilterCategory.warm);
      }
    });

    test('byCategory — 각 카테고리에 필터가 존재한다', () {
      for (final cat in FilterCategory.values) {
        final filters = FilterData.byCategory(cat);
        expect(filters, isNotEmpty, reason: '$cat 카테고리에 필터가 없음');
      }
    });

    test('defaultIntensities — 모든 값이 0.0~1.0 범위다', () {
      for (final entry in FilterData.defaultIntensities.entries) {
        expect(entry.value, greaterThanOrEqualTo(0.0),
            reason: '${entry.key} intensity가 0.0 미만');
        expect(entry.value, lessThanOrEqualTo(1.0),
            reason: '${entry.key} intensity가 1.0 초과');
      }
    });

    test('defaultIntensities — 모든 필터 id가 포함된다', () {
      for (final f in FilterData.all) {
        expect(FilterData.defaultIntensities.containsKey(f.id), true,
            reason: '${f.id}가 defaultIntensities에 없음');
      }
    });

    test('무료 필터(isPro=false)가 존재한다', () {
      final freeFilters = FilterData.all.where((f) => !f.isPro).toList();
      expect(freeFilters, isNotEmpty);
    });

    test('Pro 필터(isPro=true)가 존재한다', () {
      final proFilters = FilterData.all.where((f) => f.isPro).toList();
      expect(proFilters, isNotEmpty);
    });
  });
}
