import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodfilm/core/utils/haptic_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // HapticFeedback은 platform channel을 사용하므로 mock 처리
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('HapticUtils', () {
    test('filterChange — 예외 없이 실행된다', () {
      expect(() => HapticUtils.filterChange(), returnsNormally);
    });

    test('shutter — 예외 없이 실행된다', () {
      expect(() => HapticUtils.shutter(), returnsNormally);
    });

    test('cameraFlip — 예외 없이 실행된다', () {
      expect(() => HapticUtils.cameraFlip(), returnsNormally);
    });

    test('zoomStep — 예외 없이 실행된다', () {
      expect(() => HapticUtils.zoomStep(), returnsNormally);
    });

    test('favoriteToggle — 예외 없이 실행된다', () {
      expect(() => HapticUtils.favoriteToggle(), returnsNormally);
    });

    test('saveSuccess — 예외 없이 실행된다', () {
      expect(() => HapticUtils.saveSuccess(), returnsNormally);
    });
  });
}
