import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodfilm/core/constants/app_colors.dart';
import 'package:moodfilm/core/models/filter_model.dart';

void main() {
  // ────────────────────────────────────────────────────────
  // AppColors 스모크
  // ────────────────────────────────────────────────────────
  group('AppColors', () {
    test('primary 색상이 정의돼 있다', () {
      expect(AppColors.primary, isNotNull);
      expect(AppColors.primary, isA<Color>());
    });

    test('accent 색상이 정의돼 있다', () {
      expect(AppColors.accent, isNotNull);
    });

    test('cameraBg는 검정이다', () {
      expect(AppColors.cameraBg, const Color(0xFF000000));
    });
  });

  // ────────────────────────────────────────────────────────
  // 위젯 렌더링 스모크
  // ────────────────────────────────────────────────────────
  group('FilterModel 위젯 렌더링', () {
    testWidgets('FilterModel name이 Text 위젯에 표시된다', (tester) async {
      final filter = FilterData.byId('milk')!;
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Text(filter.name))),
      );
      expect(find.text('Milk'), findsOneWidget);
    });

    testWidgets('필터 30종 이름이 모두 비어있지 않다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: FilterData.all
                  .map((f) => Text(f.name, key: ValueKey(f.id)))
                  .toList(),
            ),
          ),
        ),
      );
      for (final f in FilterData.all) {
        expect(f.name.trim(), isNotEmpty, reason: '${f.id}의 name이 비어있음');
      }
    });

    testWidgets('thumbnailAssetPath 형식이 올바르다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      for (final f in FilterData.all) {
        expect(f.thumbnailAssetPath, startsWith('assets/thumbnails/'));
        expect(f.thumbnailAssetPath, endsWith('.jpg'));
      }
    });

    testWidgets('Pro 필터와 무료 필터 구분이 정상적으로 렌더링된다', (tester) async {
      final proFilters = FilterData.all.where((f) => f.isPro).toList();
      final freeFilters = FilterData.all.where((f) => !f.isPro).toList();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Pro: ${proFilters.length}'),
                Text('Free: ${freeFilters.length}'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Pro: ${proFilters.length}'), findsOneWidget);
      expect(find.text('Free: ${freeFilters.length}'), findsOneWidget);
    });
  });
}
