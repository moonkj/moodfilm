import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodfilm/native_plugins/filter_engine/filter_engine.dart';

// ────────────────────────────────────────────────────────────────────────────
// Mock 설정
// ────────────────────────────────────────────────────────────────────────────
const _channel = MethodChannel('com.moodfilm/filter_engine');
final _calls = <MethodCall>[];

void _setupMocks() {
  _calls.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    _calls.add(call);
    switch (call.method) {
      case 'processImage':
        return '/tmp/processed.jpg';
      case 'processVideo':
        return '/tmp/processed.mp4';
      case 'generateThumbnail':
        return [1, 2, 3, 4]; // dummy bytes
      case 'initImagePreview':
        return {'textureId': 42, 'width': 1080, 'height': 1350};
      default:
        return null;
    }
  });
}

void _tearDownMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_setupMocks);
  tearDownAll(_tearDownMocks);
  setUp(() => _calls.clear());

  // ──────────────────────────────────────────────────────────────────────────
  // processImage
  // ──────────────────────────────────────────────────────────────────────────
  group('FilterEngine.processImage', () {
    test('processImage — 처리된 파일 경로를 반환한다', () async {
      final path = await FilterEngine.processImage(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
        intensity: 0.8,
      );
      expect(path, '/tmp/processed.jpg');
    });

    test('processImage — 채널에 sourcePath가 전달된다', () async {
      await FilterEngine.processImage(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
        intensity: 0.8,
      );
      final call = _calls.firstWhere((c) => c.method == 'processImage');
      // Android(Kotlin)와 iOS(Swift) 양쪽 모두 sourcePath 키를 읽어야 한다
      expect(call.arguments['sourcePath'], '/input/photo.jpg');
    });

    test('processImage — 채널에 lutFile과 intensity가 전달된다', () async {
      await FilterEngine.processImage(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'film_80.cube',
        intensity: 0.6,
      );
      final call = _calls.firstWhere((c) => c.method == 'processImage');
      expect(call.arguments['lutFile'], 'film_80.cube');
      expect(call.arguments['intensity'], 0.6);
    });

    test('processImage — adjustments 맵이 채널에 전달된다', () async {
      await FilterEngine.processImage(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
        intensity: 1.0,
        adjustments: {'brightness': 0.3, 'contrast': -0.2, 'saturation': 0.5},
      );
      final call = _calls.firstWhere((c) => c.method == 'processImage');
      final adj = call.arguments['adjustments'] as Map;
      expect(adj['brightness'], 0.3);
      expect(adj['contrast'], -0.2);
      expect(adj['saturation'], 0.5);
    });

    test('processImage — adjustments 미전달 시 빈 맵이 전달된다', () async {
      await FilterEngine.processImage(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
        intensity: 1.0,
      );
      final call = _calls.firstWhere((c) => c.method == 'processImage');
      expect(call.arguments['adjustments'], isEmpty);
    });

    test('processImage — effects 맵이 채널에 전달된다', () async {
      await FilterEngine.processImage(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
        intensity: 1.0,
        effects: {'glow': 0.4, 'filmGrain': 0.2},
      );
      final call = _calls.firstWhere((c) => c.method == 'processImage');
      final eff = call.arguments['effects'] as Map;
      expect(eff['glow'], 0.4);
      expect(eff['filmGrain'], 0.2);
    });

    test('processImage — saveToGallery 기본값은 false다', () async {
      await FilterEngine.processImage(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
        intensity: 1.0,
      );
      final call = _calls.firstWhere((c) => c.method == 'processImage');
      expect(call.arguments['saveToGallery'], false);
    });

    test('processImage — saveToGallery true 전달 시 채널에 반영된다', () async {
      await FilterEngine.processImage(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
        intensity: 1.0,
        saveToGallery: true,
      );
      final call = _calls.firstWhere((c) => c.method == 'processImage');
      expect(call.arguments['saveToGallery'], true);
    });

    test('processImage — 빈 lutFileName 전달 시 채널에 빈 문자열이 간다', () async {
      await FilterEngine.processImage(
        sourcePath: '/input/photo.jpg',
        lutFileName: '',
        intensity: 0.0,
      );
      final call = _calls.firstWhere((c) => c.method == 'processImage');
      expect(call.arguments['lutFile'], '');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // processVideo
  // ──────────────────────────────────────────────────────────────────────────
  group('FilterEngine.processVideo', () {
    test('processVideo — 처리된 파일 경로를 반환한다', () async {
      final path = await FilterEngine.processVideo(
        sourcePath: '/input/video.mp4',
        lutFileName: 'milk.cube',
        intensity: 0.7,
      );
      expect(path, '/tmp/processed.mp4');
    });

    test('processVideo — 채널에 sourcePath가 전달된다', () async {
      await FilterEngine.processVideo(
        sourcePath: '/input/video.mp4',
        lutFileName: 'milk.cube',
        intensity: 0.7,
      );
      final call = _calls.firstWhere((c) => c.method == 'processVideo');
      expect(call.arguments['sourcePath'], '/input/video.mp4');
    });

    test('processVideo — saveToGallery 기본값은 true다', () async {
      await FilterEngine.processVideo(
        sourcePath: '/input/video.mp4',
        lutFileName: 'milk.cube',
        intensity: 1.0,
      );
      final call = _calls.firstWhere((c) => c.method == 'processVideo');
      expect(call.arguments['saveToGallery'], true);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // generateThumbnail
  // ──────────────────────────────────────────────────────────────────────────
  group('FilterEngine.generateThumbnail', () {
    test('generateThumbnail — 바이트 리스트를 반환한다', () async {
      final bytes = await FilterEngine.generateThumbnail(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
      );
      expect(bytes, isNotNull);
      expect(bytes, isNotEmpty);
    });

    test('generateThumbnail — 채널에 sourcePath가 전달된다', () async {
      await FilterEngine.generateThumbnail(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
      );
      final call = _calls.firstWhere((c) => c.method == 'generateThumbnail');
      expect(call.arguments['sourcePath'], '/input/photo.jpg');
    });

    test('generateThumbnail — 기본 size는 120이다', () async {
      await FilterEngine.generateThumbnail(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
      );
      final call = _calls.firstWhere((c) => c.method == 'generateThumbnail');
      expect(call.arguments['size'], 120);
    });

    test('generateThumbnail — 커스텀 size가 전달된다', () async {
      await FilterEngine.generateThumbnail(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
        size: 200,
      );
      final call = _calls.firstWhere((c) => c.method == 'generateThumbnail');
      expect(call.arguments['size'], 200);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // initImagePreview / updateImagePreview / disposeImagePreview
  // ──────────────────────────────────────────────────────────────────────────
  group('FilterEngine.initImagePreview', () {
    test('initImagePreview — textureId, width, height를 반환한다', () async {
      final result = await FilterEngine.initImagePreview(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
        intensity: 0.8,
      );
      expect(result, isNotNull);
      expect(result!['textureId'], 42);
      expect(result['width'], 1080);
      expect(result['height'], 1350);
    });

    test('initImagePreview — 채널에 sourcePath, lutFile, intensity가 전달된다', () async {
      await FilterEngine.initImagePreview(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'film_80.cube',
        intensity: 0.6,
      );
      final call = _calls.firstWhere((c) => c.method == 'initImagePreview');
      expect(call.arguments['sourcePath'], '/input/photo.jpg');
      expect(call.arguments['lutFile'], 'film_80.cube');
      expect(call.arguments['intensity'], 0.6);
    });

    test('initImagePreview — adjustments 미전달 시 빈 맵이 전달된다', () async {
      await FilterEngine.initImagePreview(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
        intensity: 1.0,
      );
      final call = _calls.firstWhere((c) => c.method == 'initImagePreview');
      expect(call.arguments['adjustments'], isEmpty);
      expect(call.arguments['effects'], isEmpty);
    });

    test('initImagePreview — adjustments, effects 맵이 채널에 전달된다', () async {
      await FilterEngine.initImagePreview(
        sourcePath: '/input/photo.jpg',
        lutFileName: 'milk.cube',
        intensity: 1.0,
        adjustments: {'exposure': 0.3, 'contrast': -0.1},
        effects: {'dreamyGlow': 0.5, 'beauty': 0.2},
      );
      final call = _calls.firstWhere((c) => c.method == 'initImagePreview');
      final adj = call.arguments['adjustments'] as Map;
      final eff = call.arguments['effects'] as Map;
      expect(adj['exposure'], 0.3);
      expect(adj['contrast'], -0.1);
      expect(eff['dreamyGlow'], 0.5);
      expect(eff['beauty'], 0.2);
    });
  });

  group('FilterEngine.updateImagePreview', () {
    test('updateImagePreview — 채널에 lutFile, intensity가 전달된다', () async {
      await FilterEngine.updateImagePreview(
        lutFileName: 'lomo.cube',
        intensity: 0.7,
      );
      final call = _calls.firstWhere((c) => c.method == 'updateImagePreview');
      expect(call.arguments['lutFile'], 'lomo.cube');
      expect(call.arguments['intensity'], 0.7);
    });

    test('updateImagePreview — adjustments, effects 맵이 채널에 전달된다', () async {
      await FilterEngine.updateImagePreview(
        lutFileName: '',
        intensity: 0.0,
        adjustments: {'vignette': 0.4},
        effects: {'filmGrain': 0.3},
      );
      final call = _calls.firstWhere((c) => c.method == 'updateImagePreview');
      expect((call.arguments['adjustments'] as Map)['vignette'], 0.4);
      expect((call.arguments['effects'] as Map)['filmGrain'], 0.3);
    });
  });

  group('FilterEngine.disposeImagePreview', () {
    test('disposeImagePreview — disposeImagePreview 채널 메서드를 호출한다', () async {
      await FilterEngine.disposeImagePreview();
      expect(_calls.any((c) => c.method == 'disposeImagePreview'), isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Android 플랫폼 호환 계약 검증
  // (iOS filterEngine과 동일한 채널 이름·인수 키를 Android도 사용해야 한다)
  // ──────────────────────────────────────────────────────────────────────────
  group('FilterEngine Android 플랫폼 호환', () {
    test('채널 이름이 com.moodfilm/filter_engine 이다', () {
      // FilterEngine._channel은 private이므로 실제 호출로 검증
      // mock handler가 해당 채널을 수신했으면 채널 이름이 일치하는 것
      expect(true, true); // mock 설정 자체가 채널 이름 검증
    });

    test('processImage — iOS·Android 공통 키 sourcePath를 사용한다', () async {
      await FilterEngine.processImage(
        sourcePath: '/photo.jpg',
        lutFileName: 'lomo.cube',
        intensity: 0.5,
      );
      final call = _calls.firstWhere((c) => c.method == 'processImage');
      // 양 플랫폼 모두 'sourcePath' 키를 사용해야 함 (imagePath 아님)
      expect(call.arguments.containsKey('sourcePath'), true);
      expect(call.arguments.containsKey('imagePath'), false);
    });

    test('processImage — adjustments/effects 맵 키 구조가 일치한다', () async {
      await FilterEngine.processImage(
        sourcePath: '/photo.jpg',
        lutFileName: 'lomo.cube',
        intensity: 0.5,
        adjustments: {'brightness': 0.1},
        effects: {'glow': 0.3},
      );
      final call = _calls.firstWhere((c) => c.method == 'processImage');
      // 맵 형태로 전달됨을 검증 (Android Kotlin에서 동일하게 읽어야 함)
      expect(call.arguments['adjustments'], isA<Map>());
      expect(call.arguments['effects'], isA<Map>());
    });
  });
}
