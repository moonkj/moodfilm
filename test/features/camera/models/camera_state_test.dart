import 'package:flutter_test/flutter_test.dart';
import 'package:moodfilm/core/models/filter_model.dart';
import 'package:moodfilm/features/camera/models/camera_state.dart';

void main() {
  // ────────────────────────────────────────────────────────
  // CameraState 초기값
  // ────────────────────────────────────────────────────────
  group('CameraState 초기값', () {
    late CameraState state;

    setUp(() => state = const CameraState());

    test('status는 uninitialized다', () {
      expect(state.status, CameraStatus.uninitialized);
    });

    test('isFrontCamera는 false다', () {
      expect(state.isFrontCamera, false);
    });

    test('activeFilter는 null이다', () {
      expect(state.activeFilter, null);
    });

    test('filterIntensity는 1.0이다', () {
      expect(state.filterIntensity, 1.0);
    });

    test('exposureEV는 0.0이다', () {
      expect(state.exposureEV, 0.0);
    });

    test('zoom은 1.0이다', () {
      expect(state.zoom, 1.0);
    });

    test('isFlipping은 false다', () {
      expect(state.isFlipping, false);
    });

    test('cameraMode는 photo다', () {
      expect(state.cameraMode, CameraMode.photo);
    });

    test('isRecording은 false다', () {
      expect(state.isRecording, false);
    });

    test('recordingSeconds는 0이다', () {
      expect(state.recordingSeconds, 0);
    });

    test('aspectRatio는 ratio3_4다', () {
      expect(state.aspectRatio, CameraAspectRatio.ratio3_4);
    });
  });

  // ────────────────────────────────────────────────────────
  // CameraState 계산 속성
  // ────────────────────────────────────────────────────────
  group('CameraState 계산 속성', () {
    test('isReady — status가 ready일 때 true다', () {
      final state = const CameraState(status: CameraStatus.ready);
      expect(state.isReady, true);
    });

    test('isReady — status가 ready가 아닐 때 false다', () {
      expect(const CameraState(status: CameraStatus.uninitialized).isReady, false);
      expect(const CameraState(status: CameraStatus.initializing).isReady, false);
      expect(const CameraState(status: CameraStatus.error).isReady, false);
    });

    test('isCapturing — status가 capturing일 때 true다', () {
      final state = const CameraState(status: CameraStatus.capturing);
      expect(state.isCapturing, true);
    });

    test('isVideoMode — cameraMode가 video일 때 true다', () {
      final state = const CameraState(cameraMode: CameraMode.video);
      expect(state.isVideoMode, true);
    });

    test('isVideoMode — cameraMode가 photo일 때 false다', () {
      final state = const CameraState(cameraMode: CameraMode.photo);
      expect(state.isVideoMode, false);
    });
  });

  // ────────────────────────────────────────────────────────
  // CameraState copyWith
  // ────────────────────────────────────────────────────────
  group('CameraState copyWith', () {
    late CameraState base;

    setUp(() => base = const CameraState(
      status: CameraStatus.ready,
      isFrontCamera: true,
      filterIntensity: 0.8,
      zoom: 1.5,
    ));

    test('status를 업데이트한다', () {
      final updated = base.copyWith(status: CameraStatus.capturing);
      expect(updated.status, CameraStatus.capturing);
      expect(updated.filterIntensity, 0.8); // 나머지는 유지
    });

    test('isFrontCamera를 업데이트한다', () {
      final updated = base.copyWith(isFrontCamera: false);
      expect(updated.isFrontCamera, false);
    });

    test('filterIntensity를 업데이트한다', () {
      final updated = base.copyWith(filterIntensity: 0.5);
      expect(updated.filterIntensity, 0.5);
    });

    test('zoom을 업데이트한다', () {
      final updated = base.copyWith(zoom: 2.0);
      expect(updated.zoom, 2.0);
    });

    test('activeFilter를 업데이트한다', () {
      final filter = FilterModel(
        id: 'milk',
        name: 'Milk',
        category: FilterCategory.warm,
        lutFileName: 'milk.cube',
      );
      final updated = base.copyWith(activeFilter: filter);
      expect(updated.activeFilter?.id, 'milk');
    });

    test('clearFilter=true이면 activeFilter가 null이 된다', () {
      final withFilter = base.copyWith(
        activeFilter: FilterModel(
          id: 'milk',
          name: 'Milk',
          category: FilterCategory.warm,
          lutFileName: 'milk.cube',
        ),
      );
      final cleared = withFilter.copyWith(clearFilter: true);
      expect(cleared.activeFilter, isNull);
    });

    test('아무것도 안 바꾸면 기존 값이 유지된다', () {
      final copy = base.copyWith();
      expect(copy.status, base.status);
      expect(copy.isFrontCamera, base.isFrontCamera);
      expect(copy.filterIntensity, base.filterIntensity);
      expect(copy.zoom, base.zoom);
    });

    test('recordingSeconds를 업데이트한다', () {
      final updated = base.copyWith(recordingSeconds: 42);
      expect(updated.recordingSeconds, 42);
    });

    test('favoritesVersion을 업데이트한다', () {
      final updated = base.copyWith(favoritesVersion: 3);
      expect(updated.favoritesVersion, 3);
    });
  });

  // ────────────────────────────────────────────────────────
  // CameraAspectRatio
  // ────────────────────────────────────────────────────────
  group('CameraAspectRatio', () {
    test('full의 ratio는 null이다', () {
      expect(CameraAspectRatio.full.ratio, isNull);
    });

    test('ratio1_1의 ratio는 1.0이다', () {
      expect(CameraAspectRatio.ratio1_1.ratio, 1.0);
    });

    test('ratio3_4의 ratio는 3/4다', () {
      expect(CameraAspectRatio.ratio3_4.ratio, closeTo(0.75, 0.001));
    });

    test('nativeKey — ratio3_4는 "4:3"이다 (landscape 버퍼 크롭 기준)', () {
      expect(CameraAspectRatio.ratio3_4.nativeKey, '4:3');
    });

    test('label — ratio9_16은 "9:16"이다', () {
      expect(CameraAspectRatio.ratio9_16.label, '9:16');
    });

    test('모든 케이스에 label이 있다', () {
      for (final ratio in CameraAspectRatio.values) {
        expect(ratio.label, isNotEmpty,
            reason: '$ratio의 label이 비어있음');
      }
    });

    test('nativeKey — 모든 케이스에 값이 있다', () {
      expect(CameraAspectRatio.full.nativeKey, 'full');
      expect(CameraAspectRatio.ratio9_16.nativeKey, '16:9');
      expect(CameraAspectRatio.ratio3_4.nativeKey, '4:3');
      expect(CameraAspectRatio.ratio1_1.nativeKey, '1:1');
      expect(CameraAspectRatio.ratio4_3.nativeKey, '3:4');
      expect(CameraAspectRatio.ratio16_9.nativeKey, '9:16');
    });

    test('ratio — ratio9_16은 9/16이다', () {
      expect(CameraAspectRatio.ratio9_16.ratio, closeTo(9 / 16, 0.001));
    });

    test('ratio — ratio4_3은 4/3이다', () {
      expect(CameraAspectRatio.ratio4_3.ratio, closeTo(4 / 3, 0.001));
    });

    test('ratio — ratio16_9은 16/9이다', () {
      expect(CameraAspectRatio.ratio16_9.ratio, closeTo(16 / 9, 0.001));
    });
  });
}
