import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodfilm/native_plugins/camera_engine/camera_engine.dart';

// ────────────────────────────────────────────────────────────
// Mock 설정
// ────────────────────────────────────────────────────────────
const _channel = MethodChannel('com.moodfilm/camera_engine');
const _platformChannel = SystemChannels.platform;

final _calls = <MethodCall>[];

void _setupMocks() {
  _calls.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    _calls.add(call);
    switch (call.method) {
      case 'initialize':
        return 42;
      case 'capturePhoto':
        return '/tmp/test_photo.jpg';
      case 'capturePhotoSilent':
        return '/tmp/test_silent.jpg';
      case 'startRecording':
        return '/tmp/test_video.mp4';
      case 'stopRecording':
        return '/tmp/test_video.mp4';
      case 'isFrontCamera':
        return true;
      default:
        return null;
    }
  });
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_platformChannel, (_) async => null);
}

void _tearDownMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_platformChannel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_setupMocks);
  tearDownAll(_tearDownMocks);
  setUp(() => _calls.clear());

  // ────────────────────────────────────────────────────────
  // 초기화 / 해제
  // ────────────────────────────────────────────────────────
  group('CameraEngine 초기화/해제', () {
    test('initialize — textureId를 반환한다', () async {
      final id = await CameraEngine.initialize(frontCamera: true);
      expect(id, 42);
    });

    test('initialize — 채널에 frontCamera 파라미터가 전달된다', () async {
      await CameraEngine.initialize(frontCamera: false);
      final call = _calls.firstWhere((c) => c.method == 'initialize');
      expect(call.arguments['frontCamera'], false);
    });

    test('dispose — dispose 채널이 호출된다', () async {
      await CameraEngine.dispose();
      expect(_calls.any((c) => c.method == 'dispose'), true);
    });
  });

  // ────────────────────────────────────────────────────────
  // 촬영
  // ────────────────────────────────────────────────────────
  group('CameraEngine 촬영', () {
    test('capturePhoto — 경로를 반환한다', () async {
      final path = await CameraEngine.capturePhoto();
      expect(path, '/tmp/test_photo.jpg');
    });

    test('capturePhotoSilent — 경로를 반환한다', () async {
      final path = await CameraEngine.capturePhotoSilent();
      expect(path, '/tmp/test_silent.jpg');
    });
  });

  // ────────────────────────────────────────────────────────
  // 세션 관리
  // ────────────────────────────────────────────────────────
  group('CameraEngine 세션', () {
    test('pauseSession — 채널이 호출된다', () async {
      await CameraEngine.pauseSession();
      expect(_calls.any((c) => c.method == 'pauseSession'), true);
    });

    test('resumeSession — 채널이 호출된다', () async {
      await CameraEngine.resumeSession();
      expect(_calls.any((c) => c.method == 'resumeSession'), true);
    });
  });

  // ────────────────────────────────────────────────────────
  // 필터 / 이펙트
  // ────────────────────────────────────────────────────────
  group('CameraEngine 필터/이펙트', () {
    test('setFilter — 채널에 lutFile과 intensity가 전달된다', () async {
      await CameraEngine.setFilter(lutFileName: 'milk.cube', intensity: 0.8);
      final call = _calls.firstWhere((c) => c.method == 'setFilter');
      expect(call.arguments['lutFile'], 'milk.cube');
      expect(call.arguments['intensity'], 0.8);
    });

    test('setEffect — 채널에 effectType과 intensity가 전달된다', () async {
      await CameraEngine.setEffect(effectType: 'glow', intensity: 0.5);
      final call = _calls.firstWhere((c) => c.method == 'setEffect');
      expect(call.arguments['effectType'], 'glow');
      expect(call.arguments['intensity'], 0.5);
    });
  });

  // ────────────────────────────────────────────────────────
  // 카메라 제어
  // ────────────────────────────────────────────────────────
  group('CameraEngine 카메라 제어', () {
    test('flipCamera — flipCamera 채널이 호출된다', () async {
      await CameraEngine.flipCamera();
      expect(_calls.any((c) => c.method == 'flipCamera'), true);
    });

    test('isFrontCamera — bool을 반환한다', () async {
      final result = await CameraEngine.isFrontCamera();
      expect(result, true);
    });

    test('setFocusPoint — 채널에 x, y가 전달된다', () async {
      await CameraEngine.setFocusPoint(0.5, 0.3);
      final call = _calls.firstWhere((c) => c.method == 'setFocusPoint');
      expect(call.arguments['x'], 0.5);
      expect(call.arguments['y'], 0.3);
    });
  });

  // ────────────────────────────────────────────────────────
  // 화면 비율 / 스플릿 모드
  // ────────────────────────────────────────────────────────
  group('CameraEngine 비율/스플릿', () {
    test('setAspectRatio — 채널에 ratio가 전달된다', () async {
      await CameraEngine.setAspectRatio('4:3');
      final call = _calls.firstWhere((c) => c.method == 'setAspectRatio');
      expect(call.arguments['ratio'], '4:3');
    });

    test('setSplitMode — 채널에 position과 isFrontCamera가 전달된다', () async {
      await CameraEngine.setSplitMode(position: 0.5, isFrontCamera: true);
      final call = _calls.firstWhere((c) => c.method == 'setSplitMode');
      expect(call.arguments['position'], 0.5);
      expect(call.arguments['isFrontCamera'], true);
    });
  });

  // ────────────────────────────────────────────────────────
  // 동영상 녹화
  // ────────────────────────────────────────────────────────
  group('CameraEngine 녹화', () {
    test('startRecording — 파일 경로를 반환한다', () async {
      final path = await CameraEngine.startRecording();
      expect(path, '/tmp/test_video.mp4');
    });

    test('stopRecording — 파일 경로를 반환한다', () async {
      final path = await CameraEngine.stopRecording();
      expect(path, '/tmp/test_video.mp4');
    });
  });

}
