import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodfilm/features/settings/presentation/policy_screen.dart';

void main() {
  // ────────────────────────────────────────────────────────
  // PolicyScreen 위젯 스모크 테스트
  // ────────────────────────────────────────────────────────
  Widget wrap(Widget child) {
    return MaterialApp(home: child);
  }

  group('PolicyScreen 렌더링', () {
    testWidgets('privacyPolicy — AppBar 타이틀이 개인정보처리방침이다', (tester) async {
      await tester.pumpWidget(wrap(PolicyScreen.privacyPolicy));
      expect(find.text('개인정보처리방침'), findsWidgets);
    });

    testWidgets('privacyPolicy — 섹션 heading이 화면에 표시된다', (tester) async {
      await tester.pumpWidget(wrap(PolicyScreen.privacyPolicy));
      await tester.pump();
      expect(find.text('1. 수집하는 정보'), findsOneWidget);
    });

    test('privacyPolicy — 문의 섹션 body에 이메일 주소가 포함된다', () {
      final sections = PolicyScreen.privacyPolicy.sections;
      final hasEmail = sections.any((s) => s.body.contains('imurmkj@gmail.com'));
      expect(hasEmail, true);
    });

    testWidgets('termsOfService — AppBar 타이틀이 이용약관이다', (tester) async {
      await tester.pumpWidget(wrap(PolicyScreen.termsOfService));
      expect(find.text('이용약관'), findsWidgets);
    });

    testWidgets('termsOfService — 첫 번째 섹션이 표시된다', (tester) async {
      await tester.pumpWidget(wrap(PolicyScreen.termsOfService));
      await tester.pump();
      expect(find.text('1. 서비스 이용'), findsOneWidget);
    });

    testWidgets('termsOfService — ListView가 스크롤 가능하다', (tester) async {
      await tester.pumpWidget(wrap(PolicyScreen.termsOfService));
      await tester.pump();
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────────────
  // PolicySection 모델
  // ────────────────────────────────────────────────────────
  group('PolicySection', () {
    test('heading과 body가 올바르게 저장된다', () {
      const section = PolicySection(heading: '테스트', body: '내용');
      expect(section.heading, '테스트');
      expect(section.body, '내용');
    });

    test('heading이 null일 수 있다', () {
      const section = PolicySection(heading: null, body: '내용');
      expect(section.heading, isNull);
    });
  });

  // ────────────────────────────────────────────────────────
  // static const 인스턴스 검증
  // ────────────────────────────────────────────────────────
  group('PolicyScreen static 인스턴스', () {
    test('privacyPolicy.title은 개인정보처리방침이다', () {
      expect(PolicyScreen.privacyPolicy.title, '개인정보처리방침');
    });

    test('privacyPolicy.sections가 비어있지 않다', () {
      expect(PolicyScreen.privacyPolicy.sections, isNotEmpty);
    });

    test('termsOfService.title은 이용약관이다', () {
      expect(PolicyScreen.termsOfService.title, '이용약관');
    });

    test('termsOfService.sections가 비어있지 않다', () {
      expect(PolicyScreen.termsOfService.sections, isNotEmpty);
    });

    test('privacyPolicy 섹션 수는 9개 이상이다', () {
      // heading이 있는 섹션 (intro 제외)
      expect(PolicyScreen.privacyPolicy.sections.length, greaterThanOrEqualTo(9));
    });

    test('termsOfService 섹션 수는 7개 이상이다', () {
      expect(PolicyScreen.termsOfService.sections.length, greaterThanOrEqualTo(7));
    });
  });
}
