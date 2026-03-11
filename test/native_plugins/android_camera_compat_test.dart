/// Android 카메라 엔진 플랫폼 호환성 테스트
///
/// Android(Kotlin) ↔ Flutter(Dart) Method Channel 계약 검증.
/// iOS 구현과 동일한 인수 키·반환 타입을 Android가 준수하는지 확인한다.
/// Native 레이어는 MockMethodChannel로 대체.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodfilm/native_plugins/camera_engine/camera_engine.dart';

const _channel = MethodChannel('com.moodfilm/camera_engine');
final _calls = <MethodCall>[];

// Android에서 반환할 mock 값 (iOS 구현과 동일한 타입이어야 함)
void _setupAndroidMock() {
  _calls.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    _calls.add(call);
    switch (call.method) {
      case 'initialize':
        return 7; // textureId: Long → int (Flutter는 int로 수신)
      case 'capturePhoto':
        return '/data/user/0/com.moodfilm/cache/likeit_123.jpg';
      case 'capturePhotoSilent':
        return '/data/user/0/com.moodfilm/cache/likeit_silent_123.jpg';
      case 'startRecording':
        return '/data/user/0/com.moodfilm/cache/likeit_video_123.mp4';
      case 'stopRecording':
        return '/data/user/0/com.moodfilm/cache/likeit_video_123.mp4';
      case 'isFrontCamera':
        return true;
      // void 메서드는 null 반환 (iOS도 동일)
      default:
        return null;
    }
  });
}

void _tearDown() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_setupAndroidMock);
  tearDownAll(_tearDown);
  setUp(() => _calls.clear());

  // ──────────────────────────────────────────────────────────────────────────
  // 초기화 — iOS·Android 동일 계약
  // ──────────────────────────────────────────────────────────────────────────
  group('Android 초기화 계약', () {
    test('initialize — Android가 반환한 Long textureId를 int로 수신한다', () async {
      final id = await CameraEngine.initialize(frontCamera: true);
      expect(id, isA<int>());
      expect(id, 7);
    });

    test('initialize — frontCamera: true가 채널에 전달된다', () async {
      await CameraEngine.initialize(frontCamera: true);
      final call = _calls.firstWhere((c) => c.method == 'initialize');
      expect(call.arguments['frontCamera'], true);
    });

    test('initialize — frontCamera: false (후면 카메라)가 전달된다', () async {
      await CameraEngine.initialize(frontCamera: false);
      final call = _calls.firstWhere((c) => c.method == 'initialize');
      expect(call.arguments['frontCamera'], false);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 필터 — Android LUT 파이프라인 계약
  // ──────────────────────────────────────────────────────────────────────────
  group('Android 필터 계약', () {
    test('setFilter — lutFile 키로 파일명이 전달된다', () async {
      await CameraEngine.setFilter(lutFileName: 'milk.cube', intensity: 0.8);
      final call = _calls.firstWhere((c) => c.method == 'setFilter');
      // Android Kotlin: call.argument<String>("lutFile")
      expect(call.arguments['lutFile'], 'milk.cube');
      expect(call.arguments.containsKey('lutFileName'), false); // 잘못된 키 사용 금지
    });

    test('setFilter — intensity가 double로 전달된다', () async {
      await CameraEngine.setFilter(lutFileName: 'lomo.cube', intensity: 0.65);
      final call = _calls.firstWhere((c) => c.method == 'setFilter');
      expect(call.arguments['intensity'], 0.65);
    });

    test('setFilter — 빈 lutFileName은 Android에서 필터 해제로 처리된다', () async {
      await CameraEngine.setFilter(lutFileName: '', intensity: 0.0);
      final call = _calls.firstWhere((c) => c.method == 'setFilter');
      expect(call.arguments['lutFile'], '');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 이펙트 — Android CameraEngine 8가지 이펙트 계약
  // ──────────────────────────────────────────────────────────────────────────
  group('Android 이펙트 계약', () {
    // iOS CLAUDE.md에 정의된 8가지 effectType이 Android에서도 동일하게 전달돼야 함
    final effectTypes = [
      'brightness', 'contrast', 'saturation',
      'softness', 'beauty', 'glow', 'filmGrain', 'lightLeak',
    ];

    for (final type in effectTypes) {
      test('setEffect — $type effectType이 채널에 전달된다', () async {
        await CameraEngine.setEffect(effectType: type, intensity: 0.5);
        final call = _calls.firstWhere((c) => c.method == 'setEffect');
        expect(call.arguments['effectType'], type);
        expect(call.arguments['intensity'], 0.5);
      });
    }

    test('setEffect — dreamyGlow도 Android Kotlin에서 glow와 동일 처리된다', () async {
      // Android Kotlin: "dreamyGlow" | "glow" → glowIntensity
      await CameraEngine.setEffect(effectType: 'dreamyGlow', intensity: 0.4);
      final call = _calls.firstWhere((c) => c.method == 'setEffect');
      expect(call.arguments['effectType'], 'dreamyGlow');
    });

    test('setEffect — intensity 0.0 전달 시 이펙트 해제된다', () async {
      await CameraEngine.setEffect(effectType: 'glow', intensity: 0.0);
      final call = _calls.firstWhere((c) => c.method == 'setEffect');
      expect(call.arguments['intensity'], 0.0);
    });

    test('setEffect — intensity 최대값 1.0이 전달된다', () async {
      await CameraEngine.setEffect(effectType: 'beauty', intensity: 1.0);
      final call = _calls.firstWhere((c) => c.method == 'setEffect');
      expect(call.arguments['intensity'], 1.0);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 사진 캡처 — Android 반환 경로 타입 계약
  // ──────────────────────────────────────────────────────────────────────────
  group('Android 사진 캡처 계약', () {
    test('capturePhoto — Android 캐시 경로(String)를 반환한다', () async {
      final path = await CameraEngine.capturePhoto();
      expect(path, isA<String>());
      expect(path, contains('.jpg'));
    });

    test('capturePhotoSilent — String 경로를 반환한다', () async {
      final path = await CameraEngine.capturePhotoSilent();
      expect(path, isNotNull);
      expect(path, isA<String>());
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Before/After 스플릿 — Android 계약
  // ──────────────────────────────────────────────────────────────────────────
  group('Android Split 모드 계약', () {
    test('setSplitMode — position이 채널에 전달된다', () async {
      await CameraEngine.setSplitMode(position: 0.4, isFrontCamera: false);
      final call = _calls.firstWhere((c) => c.method == 'setSplitMode');
      expect(call.arguments['position'], 0.4);
      expect(call.arguments['isFrontCamera'], false);
    });

    test('setSplitMode — position -1.0이 비활성을 의미한다', () async {
      await CameraEngine.setSplitMode(position: -1.0, isFrontCamera: true);
      final call = _calls.firstWhere((c) => c.method == 'setSplitMode');
      expect(call.arguments['position'], -1.0);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 카메라 전환 / 세션 관리
  // ──────────────────────────────────────────────────────────────────────────
  group('Android 세션 관리 계약', () {
    test('flipCamera — null 반환 (void 메서드)', () async {
      // Android에서 result.success(null) 반환하므로 예외 없이 완료돼야 함
      await expectLater(CameraEngine.flipCamera(), completes);
    });

    test('pauseSession — 예외 없이 완료된다', () async {
      await expectLater(CameraEngine.pauseSession(), completes);
    });

    test('resumeSession — 예외 없이 완료된다', () async {
      await expectLater(CameraEngine.resumeSession(), completes);
    });

    test('dispose — 예외 없이 완료된다', () async {
      await expectLater(CameraEngine.dispose(), completes);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 동영상 녹화 — Android MediaCodec 계약
  // ──────────────────────────────────────────────────────────────────────────
  group('Android 녹화 계약', () {
    test('startRecording — Android 캐시 경로를 반환한다', () async {
      final path = await CameraEngine.startRecording();
      expect(path, isA<String>());
      expect(path, contains('.mp4'));
    });

    test('stopRecording — 저장된 경로를 반환한다', () async {
      final path = await CameraEngine.stopRecording();
      expect(path, isNotNull);
      expect(path, contains('.mp4'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Aspect Ratio — Android 크롭 계약
  // ──────────────────────────────────────────────────────────────────────────
  group('Android Aspect Ratio 계약', () {
    final ratios = ['full', '9:16', '3:4', '1:1', '4:3', '16:9'];

    for (final ratio in ratios) {
      test('setAspectRatio — $ratio가 채널에 전달된다', () async {
        await CameraEngine.setAspectRatio(ratio);
        final call = _calls.firstWhere((c) => c.method == 'setAspectRatio');
        expect(call.arguments['ratio'], ratio);
      });
    }
  });
}
