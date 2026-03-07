import 'dart:async';
import 'dart:io';
import 'dart:math' show pi, max;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/liquid_glass_decoration.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/models/filter_model.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../native_plugins/camera_engine/camera_engine.dart';
import '../providers/camera_provider.dart';
import '../models/camera_state.dart';
import 'widgets/shutter_button.dart';
import 'widgets/filter_scroll_bar.dart';
import 'widgets/exposure_indicator.dart';

/// 메인 카메라 화면
/// 풀스크린 카메라 프리뷰 + 반투명 오버레이 컨트롤
/// 계획서 6-6: 상단/하단 바 없음, 모든 컨트롤 투명 오버레이
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {

  // 카드 플립 애니메이션
  late final AnimationController _flipController;
  bool _hasSwappedCamera = false;

  // 필터 전환 flash
  bool _filterFlash = false;

  // 강도 슬라이더
  bool _showIntensitySlider = false;

  // 제스처 상태
  double _exposureDragStart = 0;
  double _exposureEVAtDragStart = 0;
  bool _showExposureIndicator = false;
  double _pinchScaleStart = 1.0;
  Offset _scaleStartFocalPoint = Offset.zero;
  bool _gestureDirectionLocked = false;
  bool _isVerticalDrag = false;
  bool _isHorizontalSwipe = false;

  // 온보딩 힌트
  bool _showSwipeHint = false;

  // Before/After 스플릿 모드
  bool _isSplitMode = false;
  double _splitPosition = 0.5;
  bool _splitUIHidden = false;
  Timer? _splitAutoHideTimer;

  // 필터 패널 표시
  bool _showFilterPanel = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 카메라 전환 blur 애니메이션 컨트롤러 (Apple 스타일)
    // 시각 전용 애니메이션 컨트롤러 (카드 회전 + blur)
    // 실제 카메라 전환은 _handleCameraFlip()에서 flipCamera()로 처리
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // 상태바 투명 + 아이콘 흰색 (카메라 화면)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraProvider.notifier).initialize();
      _checkOnboardingHints();
    });
  }

  void _checkOnboardingHints() {
    final prefs = StorageService.prefs;
    if (!prefs.hasSeenSwipeHint) {
      setState(() => _showSwipeHint = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showSwipeHint = false);
        prefs.hasSeenSwipeHint = true;
        prefs.save();
      });
    }
  }

  @override
  void dispose() {
    _splitAutoHideTimer?.cancel();
    _flipController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    ref.read(cameraProvider.notifier).disposeCamera();
    super.dispose();
  }

  void _startSplitAutoHideTimer() {
    _splitAutoHideTimer?.cancel();
    if (_splitUIHidden) setState(() => _splitUIHidden = false);
    _splitAutoHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isSplitMode) {
        setState(() => _splitUIHidden = true);
      }
    });
  }

  Future<void> _handleCameraFlip() async {
    if (_flipController.isAnimating) return;
    _hasSwappedCamera = false;

    // 시각 애니메이션 시작 (카드 회전 + blur)
    _flipController.forward(from: 0.0);

    // blur peak 시점(0.2 × 600ms = 120ms) 대기 후 카메라 전환
    // flipCamera() 내부: hardware(~200ms) + 100ms delay → 완료 ~420ms
    // blur hold 종료: 0.8 × 600ms = 480ms → 60ms 여유
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) {
      await ref.read(cameraProvider.notifier).flipCamera();
    }

    // 애니메이션이 끝나지 않았으면 마저 완료 대기
    if (_flipController.isAnimating) {
      await _flipController.forward();
    }
    _flipController.value = 0.0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(cameraProvider.notifier).initialize();
    } else if (state == AppLifecycleState.inactive) {
      ref.read(cameraProvider.notifier).disposeCamera();
    }
  }

  // MARK: - 제스처 핸들러 (onScale로 통합: horizontal/vertical/pinch 동시 사용 불가)

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStartFocalPoint = details.focalPoint;
    _gestureDirectionLocked = false;
    _isVerticalDrag = false;
    _isHorizontalSwipe = false;

    if (details.pointerCount >= 2) {
      _pinchScaleStart = ref.read(cameraProvider).zoom;
    } else {
      _exposureDragStart = details.focalPoint.dy;
      _exposureEVAtDragStart = ref.read(cameraProvider).exposureEV;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // 핀치 줌 (2손가락)
    if (details.pointerCount >= 2) {
      final newZoom = (_pinchScaleStart * details.scale).clamp(1.0, 3.0);
      ref.read(cameraProvider.notifier).setZoom(newZoom);
      return;
    }

    // 드래그 방향 결정 (첫 8px 이동 후 잠금)
    final delta = details.focalPoint - _scaleStartFocalPoint;
    if (!_gestureDirectionLocked && delta.distance > 8) {
      _isHorizontalSwipe = delta.dx.abs() > delta.dy.abs();
      _isVerticalDrag = !_isHorizontalSwipe;
      _gestureDirectionLocked = true;
      if (_isVerticalDrag) setState(() => _showExposureIndicator = true);
    }

    // 수직 드래그 → 노출 조절
    if (_isVerticalDrag) {
      final dragDelta = _exposureDragStart - details.focalPoint.dy;
      final newEV = (_exposureEVAtDragStart + dragDelta / 100).clamp(-2.0, 2.0);
      ref.read(cameraProvider.notifier).setExposure(newEV);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // 수평 스와이프 → 스플릿 모드면 무시 (드래그로 처리), 아니면 필터 변경
    if (_isHorizontalSwipe && !_isSplitMode) {
      final vx = details.velocity.pixelsPerSecond.dx;
      if (vx.abs() > 200) {
        final camera = ref.read(cameraProvider);
        final filters = _getFilterList();
        final currentIndex = filters.indexWhere((f) => f.id == camera.activeFilter?.id);
        if (vx > 0 && currentIndex > 0) {
          ref.read(cameraProvider.notifier).selectFilter(filters[currentIndex - 1]);
        } else if (vx < 0 && currentIndex < filters.length - 1) {
          ref.read(cameraProvider.notifier).selectFilter(filters[currentIndex + 1]);
        }
      }
    }

    // 수직 드래그 종료 → 인디케이터 숨김
    if (_isVerticalDrag) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showExposureIndicator = false);
      });
    }
  }

  List<dynamic> _getFilterList() {
    final prefs = StorageService.prefs;
    return [
      ...FilterData.all.where((f) => prefs.favoriteFilterIds.contains(f.id)),
      ...FilterData.all.where((f) => !prefs.favoriteFilterIds.contains(f.id)),
    ];
  }

  void _cycleAspectRatio() {
    final current = ref.read(cameraProvider).aspectRatio;
    final values = CameraAspectRatio.values;
    final nextIndex = (values.indexOf(current) + 1) % values.length;
    ref.read(cameraProvider.notifier).setAspectRatio(values[nextIndex]);
    HapticUtils.filterChange();
  }

  void _triggerFilterFlash() {
    setState(() => _filterFlash = true);
    Future.delayed(const Duration(milliseconds: 40), () {
      if (mounted) setState(() => _filterFlash = false);
    });
  }

  /// 화면 X 좌표(_splitPosition 0~1)를 버퍼 Y 좌표(0~1)로 변환
  /// BoxFit.cover 크롭 오프셋을 보정하여 시각적 분할선과 실제 필터 경계를 일치
  double _computeNativeSplitPos(double splitPosition, bool isFront, Size screenSize) {
    // 카메라 프리뷰: SizedBox(16,9) + RotatedBox(1) = portrait 9:16 이미지
    // FittedBox.cover로 스크린에 맞출 때 좌우 크롭 발생
    final scale = max(screenSize.width / 9.0, screenSize.height / 16.0);
    final scaledW = 9.0 * scale;
    final cropX = (scaledW - screenSize.width) / 2.0;
    // screen X -> image X -> buffer Y 비율
    final raw = ((screenSize.width * splitPosition) + cropX) / scaledW;
    // back 카메라: buffer 저Y → display 우 → nativePos = 1 - raw
    // front 카메라: scale(-1,1) 후 buffer 저Y → display 좌 → nativePos = raw
    // 전면/후면 모두 동일: splitPos 증가(오른쪽 드래그) → 왼쪽(필터) 영역 확대
    return 1.0 - raw;
  }

  void _toggleSplitMode(bool isFront) {
    final newMode = !_isSplitMode;
    setState(() {
      _isSplitMode = newMode;
      _splitUIHidden = false;
    });
    if (newMode) {
      final screenSize = MediaQuery.of(context).size;
      final nativePos = _computeNativeSplitPos(_splitPosition, isFront, screenSize);
      CameraEngine.setSplitMode(position: nativePos, isFrontCamera: isFront);
      _startSplitAutoHideTimer();
    } else {
      _splitAutoHideTimer?.cancel();
      CameraEngine.setSplitMode(position: -1.0, isFrontCamera: isFront);
    }
  }

  void _updateSplitPosition(double dx, double screenWidth, bool isFront) {
    final newPos = (_splitPosition + dx / screenWidth).clamp(0.05, 0.95);
    setState(() => _splitPosition = newPos);
    final screenSize = MediaQuery.of(context).size;
    final nativePos = _computeNativeSplitPos(newPos, isFront, screenSize);
    CameraEngine.setSplitMode(position: nativePos, isFrontCamera: isFront);
    _startSplitAutoHideTimer();
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);

    // 필터 변경 감지 → flash 트리거
    ref.listen<FilterModel?>(
      cameraProvider.select((s) => s.activeFilter),
      (previous, next) {
        if (previous?.id != next?.id && previous != null) {
          _triggerFilterFlash();
        }
      },
    );

    return Scaffold(
      backgroundColor: AppColors.cameraBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 카메라 프리뷰 (항상 풀스크린)
          _buildCameraPreview(cameraState),

          // 2. 제스처 감지 레이어
          _buildGestureLayer(cameraState),

          // 3. 상단 컨트롤 (설정) — 스플릿 자동숨김 대상
          AnimatedOpacity(
            opacity: (_isSplitMode && _splitUIHidden) ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: _isSplitMode && _splitUIHidden,
              child: _buildTopControls(cameraState),
            ),
          ),

          // 3-b. 오른쪽 플로팅 버튼 (비교 + 밝기) — Positioned는 Stack 직접 자식이어야 함
          _buildRightFloatingButtons(cameraState),

          // 3-c. 스플릿 모드 오버레이 (분할선 + Before/After 레이블)
          if (_isSplitMode) _buildSplitOverlay(cameraState),

          // 3-d. 스플릿 드래그 레이어
          if (_isSplitMode) _buildSplitDragLayer(cameraState),

          // 4. 노출 인디케이터
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: 0,
            right: 0,
            child: Center(
              child: ExposureIndicator(
                ev: cameraState.exposureEV,
                isVisible: _showExposureIndicator,
              ),
            ),
          ),

          // 5. 하단 컨트롤 (필터바 + 셔터 + 갤러리)
          _buildBottomControls(cameraState),

          // 5-b. 스플릿 자동숨김 시 화면 탭하면 UI 복원
          if (_isSplitMode && _splitUIHidden)
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _startSplitAutoHideTimer,
              child: const SizedBox.expand(),
            ),

          // 6-a. 필터 전환 flash (200ms crossfade 효과)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _filterFlash ? 0.18 : 0.0,
              duration: Duration(milliseconds: _filterFlash ? 30 : 200),
              child: const ColoredBox(color: Colors.white),
            ),
          ),

          // 6-b. 카메라 전환 blur 오버레이 (완전 불투명 → 글리치 완전 차단)
          AnimatedBuilder(
            animation: _flipController,
            builder: (context, _) {
              final v = _flipController.value;
              if (v == 0.0) return const SizedBox.shrink();
              // 0→0.2: blur 급속 증가, 0.2→0.8: 완전 불투명 유지, 0.8→1.0: 감소
              // 카메라 전환(~420ms)이 hold 종료(480ms)보다 먼저 완료됨을 보장
              final double progress;
              if (v < 0.2) {
                progress = v / 0.2;
              } else if (v < 0.8) {
                progress = 1.0;
              } else {
                progress = 1.0 - (v - 0.8) / 0.2;
              }
              final sigma = progress * 30.0;
              final dimOpacity = progress * 0.82;
              return IgnorePointer(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha:dimOpacity),
                  ),
                ),
              );
            },
          ),

          // 6-c. 온보딩 힌트 오버레이
          if (_showSwipeHint) _buildSwipeHint(),

          // 8. 에러 표시
          if (cameraState.errorMessage != null)
            _buildErrorOverlay(cameraState.errorMessage!),
        ],
      ),
    );
  }

  // MARK: - 카메라 프리뷰

  Widget _buildCameraPreview(CameraState cameraState) {
    if (cameraState.textureId == null) {
      return Container(
        color: AppColors.cameraBg,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white38),
        ),
      );
    }

    // CVPixelBuffer는 항상 landscape (1920×1080)로 도착
    // 세로 모드: RotatedBox(1, 90°CW)로 portrait 변환
    // 가로 모드: RotatedBox 불필요 (buffer가 이미 landscape)
    //   LandscapeRight(홈 우측): 버퍼 방향과 일치 → quarterTurns = 0
    //   LandscapeLeft(홈 좌측): 버퍼 상하 반전 → quarterTurns = 2
    // 전면 카메라: scale(-1,1) 좌우 미러 (모든 방향 공통)
    final isFront = cameraState.isFrontCamera;
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // 가로 모드 방향 감지 (LandscapeLeft vs LandscapeRight)
    // MediaQuery.orientationData가 없으면 size 비율로 판단 후 기본값 사용
    int quarterTurns;
    if (!isLandscape) {
      quarterTurns = 1; // portrait: 90° CW
    } else {
      // 가로모드: UIDeviceOrientation은 직접 접근 불가
      // 실기기에서는 LandscapeRight(홈 우측)가 기본이므로 0 사용
      // LandscapeLeft는 View.padding 차이로 구분 가능하지만 복잡
      // 일단 0으로 처리하고 실기기 확인 후 조정
      quarterTurns = 0;
    }

    // 텍스처 위젯 (항상 16:9 landscape 버퍼)
    final textureWidget = Transform(
      alignment: Alignment.center,
      transform: isFront
          ? (Matrix4.identity()..scale(-1.0, 1.0))
          : Matrix4.identity(),
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: SizedBox(
          width: 16,
          height: 9,
          child: Texture(textureId: cameraState.textureId!),
        ),
      ),
    );

    final aspectRatio = cameraState.aspectRatio;

    Widget previewWidget;
    if (aspectRatio == CameraAspectRatio.full) {
      // 풀스크린 — 기존 동작 유지
      previewWidget = SizedBox.expand(
        child: FittedBox(fit: BoxFit.cover, child: textureWidget),
      );
    } else {
      // 특정 비율 — Flutter가 ClipRect로 잘라냄 (네이티브 버퍼는 항상 16:9)
      previewWidget = LayoutBuilder(
        builder: (context, constraints) {
          final screenW = constraints.maxWidth;
          final screenH = constraints.maxHeight;
          final targetRatio = aspectRatio.ratio!; // width / height

          double containerW = screenW;
          double containerH = screenW / targetRatio;

          if (containerH > screenH) {
            containerH = screenH;
            containerW = screenH * targetRatio;
          }

          return Center(
            child: ClipRect(
              child: SizedBox(
                width: containerW,
                height: containerH,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: textureWidget,
                ),
              ),
            ),
          );
        },
      );
    }

    // 카드 플립 3D 회전 (시각 애니메이션)
    return AnimatedBuilder(
      animation: _flipController,
      builder: (context, child) {
        final v = _flipController.value;
        if (v == 0.0) return child!;
        // 0→0.5: 0→π/2 (edge-on), 0.5→1.0: -π/2→0 (reveal)
        final angle = v <= 0.5 ? v * pi : (v - 1.0) * pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: child,
        );
      },
      child: previewWidget,
    );
  }

  // MARK: - 제스처 레이어

  Widget _buildGestureLayer(CameraState cameraState) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      onDoubleTap: _handleCameraFlip,
      onTapDown: (details) {
        // 탭 투 포커스
        final size = MediaQuery.of(context).size;
        final x = details.globalPosition.dx / size.width;
        final y = details.globalPosition.dy / size.height;
        // CameraEngine.setFocusPoint(x, y); // 추후 연결
      },
      child: const SizedBox.expand(),
    );
  }

  // MARK: - 상단 컨트롤

  Widget _buildTopControls(CameraState cameraState) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 설정 버튼 (원형 어두운 배경)
            Semantics(
              label: '설정',
              button: true,
              child: _cameraButton(
                onTap: () => context.push('/settings'),
                child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
              ),
            ),

            // 비율 전환 버튼
            LiquidGlassPill(
              onTap: _cycleAspectRatio,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                cameraState.aspectRatio.label,
                style: const TextStyle(
                  color: AppColors.shutter,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // 중앙: 녹화 타이머
            if (cameraState.isRecording)
              _buildRecordingTimer(cameraState.recordingSeconds)
            else
              const SizedBox.shrink(),

            // 우측 여백 (버튼들은 _buildRightFloatingButtons로 이동)
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }

  // MARK: - 오른쪽 플로팅 버튼 (비교 + 밝기) — Positioned를 Stack 직접 자식으로 유지
  Widget _buildRightFloatingButtons(CameraState cameraState) {
    final hide = _isSplitMode && _splitUIHidden;
    return Positioned(
      right: AppDimensions.paddingM,
      top: MediaQuery.of(context).size.height * 0.32,
      child: AnimatedOpacity(
        opacity: hide ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: IgnorePointer(
          ignoring: hide,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Before/After 비교 버튼
              _cameraButton(
                onTap: () => _toggleSplitMode(cameraState.isFrontCamera),
                child: Icon(
                  Icons.compare_rounded,
                  color: _isSplitMode ? AppColors.accent : Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 10),
              // 필터 강도 토글
              _cameraButton(
                onTap: () => setState(() => _showIntensitySlider = !_showIntensitySlider),
                child: Icon(
                  Icons.tune_rounded,
                  color: _showIntensitySlider ? AppColors.accent : Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MARK: - 하단 컨트롤

  Widget _buildBottomControls(CameraState cameraState) {
    // 스플릿 자동숨김 시: 셔터 버튼만 표시
    final hideForSplit = _isSplitMode && _splitUIHidden;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 강도 슬라이더 + 필터 패널 + 모드 탭 — 스플릿 자동숨김 대상
            AnimatedOpacity(
              opacity: hideForSplit ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: hideForSplit,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 강도 슬라이더 (토글로 표시/숨김)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      height: _showIntensitySlider ? 44 : 0,
                      child: _showIntensitySlider
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.paddingM,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.wb_sunny_outlined,
                                      color: Colors.white54, size: 16),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 2,
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 8),
                                        overlayShape: SliderComponentShape.noOverlay,
                                      ),
                                      child: Slider(
                                        value: cameraState.filterIntensity,
                                        min: 0.0,
                                        max: 1.0,
                                        onChanged: (v) => ref
                                            .read(cameraProvider.notifier)
                                            .setFilterIntensity(v),
                                        activeColor: Colors.white,
                                        inactiveColor: Colors.white24,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(cameraState.filterIntensity * 100).toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // 필터 패널 (토글)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: _showFilterPanel
                          ? RepaintBoundary(
                              child: ClipRect(
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                                  child: FilterScrollBar(
                                    isNoFilterSelected: cameraState.activeFilter == null,
                                    onNoFilterSelected: () =>
                                        ref.read(cameraProvider.notifier).clearFilter(),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // 사진/동영상 모드 전환 탭
                    _buildModeSelector(cameraState),
                  ],
                ),
              ),
            ),

            // 셔터 영역 (항상 표시) — Expanded로 셔터를 정중앙 고정
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM,
                8,
                AppDimensions.paddingM,
                16,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 좌측 Expanded: 갤러리 썸네일
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedOpacity(
                        opacity: hideForSplit ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: IgnorePointer(
                          ignoring: hideForSplit,
                          child: _buildGalleryButton(cameraState),
                        ),
                      ),
                    ),
                  ),

                  // 중앙: 셔터 / 녹화 버튼 — 항상 정중앙
                  if (cameraState.isVideoMode)
                    _buildVideoRecordButton(cameraState)
                  else
                    ShutterButton(
                      isCapturing: cameraState.isCapturing,
                      onTap: () => ref.read(cameraProvider.notifier).capturePhoto(),
                    ),

                  // 우측 Expanded: 필터 버튼 + 카메라 전환
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedOpacity(
                        opacity: hideForSplit ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: IgnorePointer(
                          ignoring: hideForSplit,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _cameraButton(
                                size: 48,
                                onTap: () => setState(() => _showFilterPanel = !_showFilterPanel),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: _showFilterPanel ? AppColors.accent : Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _cameraButton(
                                size: 48,
                                onTap: _handleCameraFlip,
                                child: const Icon(
                                  Icons.flip_camera_ios_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - 녹화 타이머

  Widget _buildRecordingTimer(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$mm:$ss',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  // MARK: - 모드 선택 탭 (사진 / 동영상)

  Widget _buildModeSelector(CameraState cameraState) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildModeTab('사진', !cameraState.isVideoMode, cameraState),
          const SizedBox(width: 24),
          _buildModeTab('동영상', cameraState.isVideoMode, cameraState),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, bool isActive, CameraState cameraState) {
    return GestureDetector(
      onTap: () {
        if (!cameraState.isRecording) {
          ref.read(cameraProvider.notifier).toggleCameraMode();
        }
      },
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          color: isActive ? Colors.white : Colors.white38,
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          letterSpacing: 0.5,
        ),
        child: Text(label),
      ),
    );
  }

  // MARK: - 동영상 녹화 버튼

  Widget _buildVideoRecordButton(CameraState cameraState) {
    final isRecording = cameraState.isRecording;
    return GestureDetector(
      onTap: () {
        if (isRecording) {
          ref.read(cameraProvider.notifier).stopRecording();
        } else {
          ref.read(cameraProvider.notifier).startRecording();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isRecording ? 28 : 52,
            height: isRecording ? 28 : 52,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(isRecording ? 6 : 26),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryButton(CameraState cameraState) {
    return GestureDetector(
      onTap: () => context.push('/gallery'),
      onLongPress: () {
        if (cameraState.lastCapturedPath != null) {
          context.push('/editor', extra: cameraState.lastCapturedPath);
        }
      },
      child: Container(
        width: AppDimensions.galleryThumbnailSize,
        height: AppDimensions.galleryThumbnailSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.shutter.withValues(alpha:0.5), width: 1.5),
          color: Colors.black26,
        ),
        child: cameraState.lastCapturedPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.file(
                  File(cameraState.lastCapturedPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white60,
                    size: 20,
                  ),
                ),
              )
            : const Icon(
                Icons.photo_library_outlined,
                color: Colors.white60,
                size: 20,
              ),
      ),
    );
  }

  // MARK: - 온보딩 힌트

  Widget _buildSwipeHint() {
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: _showSwipeHint ? 0.85 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: LiquidGlassPill(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swipe_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  '스와이프하여 필터 변경',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // MARK: - Before/After 스플릿 오버레이 (분할선 + 레이블)

  Widget _buildSplitOverlay(CameraState cameraState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final lineX = constraints.maxWidth * _splitPosition;
        final circleY = constraints.maxHeight * 0.45;
        // 사용자 리포트: 필터/원본이 반대로 표시되어 라벨 교체
        // 왼쪽: 필터 적용, 오른쪽: 원본
        final filterName = cameraState.activeFilter?.name ?? 'Filter';
        return IgnorePointer(
          child: Stack(
            children: [
              // 분할선
              Positioned(
                left: lineX - 1,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              // 핸들 아이콘
              Positioned(
                left: lineX - 18,
                top: circleY,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.compare_arrows_rounded,
                      color: Colors.black54, size: 18),
                ),
              ),
              // 왼쪽 라벨: 필터 이름 (원 왼쪽)
              Positioned(
                right: (constraints.maxWidth - lineX + 8).clamp(8.0, constraints.maxWidth - 20),
                top: circleY + 42,
                child: _splitLabel(filterName),
              ),
              // 오른쪽 라벨: 원본 (원 오른쪽)
              Positioned(
                left: (lineX + 8).clamp(8.0, constraints.maxWidth - 56),
                top: circleY + 42,
                child: _splitLabel('원본'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _splitLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildSplitDragLayer(CameraState cameraState) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        final width = MediaQuery.of(context).size.width;
        _updateSplitPosition(details.delta.dx, width, cameraState.isFrontCamera);
      },
      child: const SizedBox.expand(),
    );
  }


  // MARK: - 원형 카메라 아이콘 버튼 헬퍼

  Widget _cameraButton({
    required Widget child,
    VoidCallback? onTap,
    double size = 40,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }

  // MARK: - 에러 오버레이

  Widget _buildErrorOverlay(String message) {
    return Positioned(
      bottom: 160,
      left: AppDimensions.paddingM,
      right: AppDimensions.paddingM,
      child: LiquidGlassContainer(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            GestureDetector(
              onTap: () => ref.read(cameraProvider.notifier).clearError(),
              child: const Icon(Icons.close, color: Colors.white70, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
