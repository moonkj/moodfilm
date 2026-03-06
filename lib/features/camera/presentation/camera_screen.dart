import 'dart:math' show pi;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/liquid_glass_decoration.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/models/filter_model.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 카드 플립 애니메이션 컨트롤러
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipController.addListener(() {
      if (!_hasSwappedCamera && _flipController.value >= 0.5) {
        _hasSwappedCamera = true;
        ref.read(cameraProvider.notifier).flipCameraForAnimation();
      }
    });

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
    _flipController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    ref.read(cameraProvider.notifier).disposeCamera();
    super.dispose();
  }

  Future<void> _handleCameraFlip() async {
    if (_flipController.isAnimating) return;
    _hasSwappedCamera = false;
    await _flipController.forward(from: 0.0);
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
    // 수평 스와이프 → 필터 변경
    if (_isHorizontalSwipe) {
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

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);

    return Scaffold(
      backgroundColor: AppColors.cameraBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 카메라 프리뷰 (풀스크린)
          _buildCameraPreview(cameraState),

          // 2. 제스처 감지 레이어
          _buildGestureLayer(cameraState),

          // 3. 상단 컨트롤 (설정, 플래시)
          _buildTopControls(cameraState),

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

          // 6. 온보딩 힌트 오버레이
          if (_showSwipeHint) _buildSwipeHint(),

          // 7. 카메라 전환 중 플래시 오버레이 (좌우반전 글리치 방지)
          if (cameraState.isFlipping)
            const SizedBox.expand(
              child: ColoredBox(color: Colors.black),
            ),

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

    // CVPixelBuffer는 가로(landscape 1920×1080)로 도착
    // 전면: RotatedBox(1, 90°CW) + scale(-1,1) = 정상 (확인됨)
    // 후면: RotatedBox(1, 90°CW) + no scale = 정상 (steady state)
    // 전환 글리치는 isFlipping 500ms 딜레이로 처리
    final isFront = cameraState.isFrontCamera;
    final previewWidget = SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: Transform(
          alignment: Alignment.center,
          transform: isFront
              ? (Matrix4.identity()..scale(-1.0, 1.0))
              : Matrix4.identity(),
          child: RotatedBox(
            quarterTurns: 1,
            child: SizedBox(
              width: 16,
              height: 9,
              child: Texture(textureId: cameraState.textureId!),
            ),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _flipController,
      builder: (context, child) {
        final v = _flipController.value;
        if (v == 0.0) return child!;
        // 0→0.5: 0→π/2 (edge-on), 0.5→1.0: -π/2→0 (coming from other side)
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
            // 설정 버튼
            LiquidGlassPill(
              onTap: () => context.push('/settings'),
              padding: const EdgeInsets.all(10),
              child: const Icon(
                Icons.settings_outlined,
                color: AppColors.shutter,
                size: 20,
              ),
            ),

            // 앱 로고 (중앙)
            const Text(
              'MoodFilm',
              style: TextStyle(
                color: AppColors.shutter,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
            ),

            // 플래시 버튼
            LiquidGlassPill(
              onTap: () {}, // TODO: 플래시 토글
              padding: const EdgeInsets.all(10),
              child: const Icon(
                Icons.flash_off_rounded,
                color: AppColors.shutter,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - 하단 컨트롤

  Widget _buildBottomControls(CameraState cameraState) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 필터 스크롤 바
            RepaintBoundary(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: const FilterScrollBar(),
                ),
              ),
            ),

            // 셔터 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM,
                8,
                AppDimensions.paddingM,
                16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 갤러리 썸네일 (좌측)
                  _buildGalleryButton(cameraState),

                  // 셔터 버튼 (중앙)
                  ShutterButton(
                    isCapturing: cameraState.isCapturing,
                    onTap: () => ref.read(cameraProvider.notifier).capturePhoto(),
                  ),

                  // 전면/후면 전환 (우측)
                  LiquidGlassPill(
                    onTap: _handleCameraFlip,
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.flip_camera_ios_rounded,
                      color: AppColors.shutter,
                      size: 24,
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

  Widget _buildGalleryButton(CameraState cameraState) {
    return GestureDetector(
      onTap: () {
        if (cameraState.lastCapturedPath != null) {
          context.push('/editor', extra: cameraState.lastCapturedPath);
        }
      },
      onLongPress: () => context.push('/editor'),
      child: Container(
        width: AppDimensions.galleryThumbnailSize,
        height: AppDimensions.galleryThumbnailSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.shutter.withOpacity(0.5), width: 1.5),
          color: Colors.black26,
        ),
        child: cameraState.lastCapturedPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  cameraState.lastCapturedPath!,
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
