import 'dart:async';
import 'dart:io';
import 'dart:math' show pi;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/models/filter_model.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../native_plugins/camera_engine/camera_engine.dart';
import '../providers/camera_provider.dart';
import '../models/camera_state.dart';
import 'widgets/shutter_button.dart';
import 'widgets/filter_scroll_bar.dart';
import 'widgets/exposure_indicator.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});
  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {

  late final AnimationController _flipController;

  bool _filterFlash = false;
  bool _showIntensitySlider = false;

  // 제스처
  double _exposureDragStart = 0;
  double _exposureEVAtDragStart = 0;
  bool _showExposureIndicator = false;
  double _pinchScaleStart = 1.0;
  Offset _scaleStartFocalPoint = Offset.zero;
  bool _gestureDirectionLocked = false;
  bool _isVerticalDrag = false;
  bool _isHorizontalSwipe = false;
  bool _showSwipeHint = false;

  // 스플릿
  bool _isSplitMode = false;
  double _splitPosition = 0.5;
  Timer? _splitAutoHideTimer;

  // 필터 패널
  bool _showFilterPanel = false;

  // 사이드 버튼 레이블 (클릭 시 2초 표시)
  String? _sideBtnLabel;
  Timer? _sideBtnLabelTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraProvider.notifier).initialize();
      _checkOnboardingHints();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion 대응
    final disable = MediaQuery.of(context).disableAnimations;
    _flipController.duration = disable ? Duration.zero : const Duration(milliseconds: 600);
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

  void _showSideBtnLabel(String label) {
    _sideBtnLabelTimer?.cancel();
    setState(() => _sideBtnLabel = label);
    _sideBtnLabelTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _sideBtnLabel = null);
    });
  }

  @override
  void dispose() {
    _splitAutoHideTimer?.cancel();
    _sideBtnLabelTimer?.cancel();
    _flipController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    ref.read(cameraProvider.notifier).disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(cameraProvider.notifier).initialize();
    } else if (state == AppLifecycleState.inactive) {
      ref.read(cameraProvider.notifier).disposeCamera();
    }
  }

  Future<void> _handleCameraFlip() async {
    if (_flipController.isAnimating) return;
    HapticUtils.cameraFlip();
    _flipController.forward(from: 0.0);
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) await ref.read(cameraProvider.notifier).flipCamera();
    if (_flipController.isAnimating) await _flipController.forward();
    _flipController.value = 0.0;

    // 스플릿 모드 중 카메라 전환 시 새 isFront 기준으로 nativePos 재계산
    if (_isSplitMode && mounted) {
      final newIsFront = ref.read(cameraProvider).isFrontCamera;
      CameraEngine.setSplitMode(
        position: _computeNativeSplitPos(_splitPosition, newIsFront),
        isFrontCamera: newIsFront,
      );
    }
  }

  // MARK: - 제스처

  void _onScaleStart(ScaleStartDetails d) {
    _scaleStartFocalPoint = d.focalPoint;
    _gestureDirectionLocked = false;
    _isVerticalDrag = false;
    _isHorizontalSwipe = false;
    if (d.pointerCount >= 2) {
      _pinchScaleStart = ref.read(cameraProvider).zoom;
    } else {
      _exposureDragStart = d.focalPoint.dy;
      _exposureEVAtDragStart = ref.read(cameraProvider).exposureEV;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      final z = (_pinchScaleStart * d.scale).clamp(1.0, 3.0);
      ref.read(cameraProvider.notifier).setZoom(z);
      return;
    }
    final delta = d.focalPoint - _scaleStartFocalPoint;
    if (!_gestureDirectionLocked && delta.distance > 8) {
      _isHorizontalSwipe = delta.dx.abs() > delta.dy.abs();
      _isVerticalDrag = !_isHorizontalSwipe;
      _gestureDirectionLocked = true;
      if (_isVerticalDrag) setState(() => _showExposureIndicator = true);
    }
    if (_isVerticalDrag) {
      final ev = (_exposureEVAtDragStart + (_exposureDragStart - d.focalPoint.dy) / 100)
          .clamp(-2.0, 2.0);
      ref.read(cameraProvider.notifier).setExposure(ev);
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_isHorizontalSwipe && !_isSplitMode) {
      final vx = d.velocity.pixelsPerSecond.dx;
      if (vx.abs() > 200) {
        final camera = ref.read(cameraProvider);
        final filters = _getFilterList();
        final idx = filters.indexWhere((f) => f.id == camera.activeFilter?.id);
        if (vx > 0 && idx > 0) {
          ref.read(cameraProvider.notifier).selectFilter(filters[idx - 1]);
        } else if (vx < 0 && idx < filters.length - 1) {
          ref.read(cameraProvider.notifier).selectFilter(filters[idx + 1]);
        }
      }
    }
    if (_isVerticalDrag) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showExposureIndicator = false);
      });
    }
  }

  List<FilterModel> _getFilterList() {
    final prefs = StorageService.prefs;
    return [
      ...FilterData.all.where((f) => prefs.favoriteFilterIds.contains(f.id)),
      ...FilterData.all.where((f) => !prefs.favoriteFilterIds.contains(f.id)),
    ];
  }


  void _triggerFilterFlash() {
    HapticUtils.filterChange();
    setState(() => _filterFlash = true);
    Future.delayed(const Duration(milliseconds: 40), () {
      if (mounted) setState(() => _filterFlash = false);
    });
  }

  // 후면: screen X → buffer Y 직접 대응 (nativePos = pos)
  // 전면: scale(-1,1) 미러 보정 (nativePos = 1 - pos)
  double _computeNativeSplitPos(double pos, bool isFront) =>
      isFront ? (1.0 - pos) : pos;

  void _toggleSplitMode(bool isFront) {
    final next = !_isSplitMode;
    setState(() {
      _isSplitMode = next;
    });
    if (next) {
      CameraEngine.setSplitMode(
        position: _computeNativeSplitPos(_splitPosition, isFront),
        isFrontCamera: isFront,
      );
    } else {
      CameraEngine.setSplitMode(position: -1.0, isFrontCamera: isFront);
    }
  }

  void _updateSplitPosition(double dx, double previewWidth, bool isFront) {
    final pos = (_splitPosition + dx / previewWidth).clamp(0.05, 0.95);
    setState(() => _splitPosition = pos);
    CameraEngine.setSplitMode(
      position: _computeNativeSplitPos(pos, isFront),
      isFrontCamera: isFront,
    );
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);

    ref.listen<FilterModel?>(
      cameraProvider.select((s) => s.activeFilter),
      (prev, next) {
        if (prev?.id != next?.id && prev != null) _triggerFilterFlash();
      },
    );

    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final safeTop = mq.padding.top;
    final safeBottom = mq.padding.bottom;
    final previewH = screenW * 4.0 / 3.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: safeTop),
              // 카메라 프리뷰 (상단 바 없이 바로 시작)
              SizedBox(
                width: screenW,
                height: previewH,
                child: _buildPreviewStack(cameraState, screenW),
              ),
              // 하단 컨트롤
              Expanded(
                child: _buildBottomArea(cameraState, safeBottom),
              ),
            ],
          ),
          if (_showSwipeHint) _buildSwipeHint(),
          if (cameraState.errorMessage != null)
            _buildErrorOverlay(cameraState.errorMessage!),
        ],
      ),
    );
  }

  // MARK: - 프리뷰 스택

  Widget _buildPreviewStack(CameraState cameraState, double screenW) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black), // 카메라 미초기화/투명 프레임 시 흰 배경 방지
        _buildCameraPreview(cameraState),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          onDoubleTap: _handleCameraFlip,
          child: const SizedBox.expand(),
        ),
        if (_isSplitMode) _buildSplitOverlay(cameraState),
        if (_isSplitMode) _buildSplitDragLayer(cameraState, screenW),
        Center(
          child: ExposureIndicator(
            ev: cameraState.exposureEV,
            isVisible: _showExposureIndicator,
          ),
        ),
        _buildPreviewSideButtons(cameraState),
        // 필터 전환 flash
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _filterFlash ? 0.18 : 0.0,
            duration: Duration(milliseconds: _filterFlash ? 30 : 200),
            child: const ColoredBox(color: Colors.white),
          ),
        ),
        // 카메라 전환 blur
        AnimatedBuilder(
          animation: _flipController,
          builder: (context, child) {
            final v = _flipController.value;
            if (v == 0) return const SizedBox.shrink();
            final double p;
            if (v < 0.2) {
              p = v / 0.2;
            } else if (v < 0.8) {
              p = 1.0;
            } else {
              p = 1.0 - (v - 0.8) / 0.2;
            }
            return IgnorePointer(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: p * 30, sigmaY: p * 30),
                child: ColoredBox(color: Colors.black.withValues(alpha: p * 0.82)),
              ),
            );
          },
        ),
      ],
    );
  }

  // MARK: - 카메라 프리뷰

  Widget _buildCameraPreview(CameraState cameraState) {
    if (cameraState.textureId == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white38)),
      );
    }
    final isFront = cameraState.isFrontCamera;
    final textureWidget = Transform(
      alignment: Alignment.center,
      transform: isFront ? Matrix4.diagonal3Values(-1.0, 1.0, 1.0) : Matrix4.identity(),
      child: RotatedBox(
        quarterTurns: 1,
        child: SizedBox(width: 16, height: 9, child: Texture(textureId: cameraState.textureId!)),
      ),
    );
    return AnimatedBuilder(
      animation: _flipController,
      builder: (_, child) {
        final v = _flipController.value;
        if (v == 0) return child!;
        final angle = v <= 0.5 ? v * pi : (v - 1.0) * pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
          child: child,
        );
      },
      child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: textureWidget),
    );
  }

  // MARK: - 프리뷰 우측 사이드 버튼 (라이브포토 + 비교 + 강도 + 설정)

  Widget _buildPreviewSideButtons(CameraState cameraState) {
    return Positioned(
      right: 10,
      bottom: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (cameraState.isRecording) ...[
            _buildRecordingTimer(cameraState.recordingSeconds),
            const SizedBox(height: 10),
          ],
          _sideLabeledBtn(
            label: '라이브포토',
            icon: Icons.motion_photos_on_rounded,
            active: StorageService.prefs.isLivePhotoEnabled,
            onTap: () {
              final prefs = StorageService.prefs;
              final next = !prefs.isLivePhotoEnabled;
              setState(() {
                prefs.isLivePhotoEnabled = next;
                if (next) prefs.isSilentShutter = false;
                prefs.save();
              });
              CameraEngine.setLivePhotoEnabled(next);
              _showSideBtnLabel('라이브포토');
            },
          ),
          const SizedBox(height: 10),
          _sideLabeledBtn(
            label: '비교',
            icon: Icons.compare_rounded,
            active: _isSplitMode,
            onTap: () {
              _toggleSplitMode(cameraState.isFrontCamera);
              _showSideBtnLabel('비교');
            },
          ),
          const SizedBox(height: 10),
          _sideLabeledBtn(
            label: '필터 강도',
            icon: Icons.tune_rounded,
            active: _showIntensitySlider,
            onTap: () {
              setState(() => _showIntensitySlider = !_showIntensitySlider);
              _showSideBtnLabel('필터 강도');
            },
          ),
          const SizedBox(height: 10),
          _sideLabeledBtn(
            label: '설정',
            icon: Icons.settings_outlined,
            active: false,
            onTap: () {
              _showSideBtnLabel('설정');
              context.push('/settings');
            },
          ),
        ],
      ),
    );
  }

  Widget _sideLabeledBtn({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    final showLabel = _sideBtnLabel == label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: showLabel ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: showLabel
              ? Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(label,
                      style: const TextStyle(color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w500)),
                )
              : const SizedBox.shrink(),
        ),
        _glassBtn(icon: icon, active: active, onTap: onTap),
      ],
    );
  }

  // MARK: - 하단 컨트롤 영역

  Widget _buildBottomArea(CameraState cameraState, double safeBottom) {
    return Column(
      children: [
        const SizedBox(height: 16),
        // 활성 필터 이름 (전환 시 fade)
        AnimatedSwitcher(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: Text(
            cameraState.activeFilter?.name.toUpperCase() ?? '',
            key: ValueKey(cameraState.activeFilter?.id ?? ''),
            style: const TextStyle(
              color: Color(0xFF3D3531),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.8,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 강도 슬라이더 (토글)
        AnimatedContainer(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: _showIntensitySlider ? 40 : 0,
          child: _showIntensitySlider
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.wb_sunny_outlined, color: Color(0xFF8A8480), size: 15),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape: SliderComponentShape.noOverlay,
                          ),
                          child: Slider(
                            value: cameraState.filterIntensity,
                            min: 0,
                            max: 1,
                            onChanged: (v) => ref.read(cameraProvider.notifier).setFilterIntensity(v),
                            activeColor: const Color(0xFF3D3531),
                            inactiveColor: const Color(0xFFDDD9D5),
                          ),
                        ),
                      ),
                      Text(
                        '${(cameraState.filterIntensity * 100).toInt()}%',
                        style: const TextStyle(color: Color(0xFF8A8480), fontSize: 11),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // 필터 스크롤 바 (토글)
        AnimatedSize(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _showFilterPanel
              ? FilterScrollBar(
                  isNoFilterSelected: cameraState.activeFilter == null,
                  onNoFilterSelected: () => ref.read(cameraProvider.notifier).clearFilter(),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 4),
        // 사진 / 동영상 모드 탭
        _buildModeSelector(cameraState),
        const Spacer(),
        // 셔터 행: [갤러리] [셔터(center)] [필터+카메라전환]
        Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, safeBottom > 0 ? safeBottom : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 좌측: 갤러리
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildGalleryButton(cameraState),
                ),
              ),
              // 중앙: 셔터
              if (cameraState.isVideoMode)
                _buildVideoRecordButton(cameraState)
              else
                ShutterButton(
                  isCapturing: cameraState.isCapturing,
                  onTap: () => ref.read(cameraProvider.notifier).capturePhoto(),
                ),
              // 우측: 필터 + 카메라전환
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconBtn(
                        _showFilterPanel ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                        () => setState(() => _showFilterPanel = !_showFilterPanel),
                        active: _showFilterPanel,
                      ),
                      const SizedBox(width: 8),
                      _iconBtn(Icons.flip_camera_ios_rounded, _handleCameraFlip),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector(CameraState cameraState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _modeTab('사진', !cameraState.isVideoMode, cameraState),
        const SizedBox(width: 24),
        _modeTab('동영상', cameraState.isVideoMode, cameraState),
      ],
    );
  }

  Widget _modeTab(String label, bool isActive, CameraState cameraState) {
    return GestureDetector(
      onTap: () {
        if (!cameraState.isRecording) ref.read(cameraProvider.notifier).toggleCameraMode();
      },
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          color: isActive ? const Color(0xFF3D3531) : const Color(0xFFBBB6B2),
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          letterSpacing: 0.5,
        ),
        child: Text(label),
      ),
    );
  }

  // MARK: - 갤러리 버튼

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
          border: Border.all(color: const Color(0xFFDDD9D5), width: 1.5),
          color: const Color(0xFFF5F2EF),
        ),
        child: cameraState.lastCapturedPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: _isVideoFile(cameraState.lastCapturedPath!)
                    ? const ColoredBox(
                        color: Color(0xFF1A1A1A),
                        child: Center(
                          child: Icon(Icons.play_circle_outline_rounded,
                              color: Colors.white70, size: 22),
                        ),
                      )
                    : Image.file(
                        File(cameraState.lastCapturedPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.photo_library_outlined, color: Color(0xFF8A8480), size: 20),
                      ),
              )
            : const Icon(Icons.photo_library_outlined, color: Color(0xFF8A8480), size: 20),
      ),
    );
  }

  bool _isVideoFile(String path) =>
      path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov');

  // MARK: - 동영상 녹화 버튼

  Widget _buildVideoRecordButton(CameraState cameraState) {
    final rec = cameraState.isRecording;
    return GestureDetector(
      onTap: () => rec
          ? ref.read(cameraProvider.notifier).stopRecording()
          : ref.read(cameraProvider.notifier).startRecording(),
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
            width: rec ? 28 : 52,
            height: rec ? 28 : 52,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(rec ? 6 : 26),
            ),
          ),
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
        Container(width: 8, height: 8,
          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$mm:$ss',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
      ],
    );
  }

  // MARK: - 스플릿 오버레이

  Widget _buildSplitOverlay(CameraState cameraState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final lineX = constraints.maxWidth * _splitPosition;
        final cy = constraints.maxHeight * 0.45;
        final filterName = cameraState.activeFilter?.name ?? 'Filter';
        return IgnorePointer(
          child: Stack(
            children: [
              Positioned(
                left: lineX - 1, top: 0, bottom: 0,
                child: Container(width: 2, color: Colors.white.withValues(alpha: 0.8)),
              ),
              Positioned(
                left: lineX - 18, top: cy,
                child: Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.compare_arrows_rounded, color: Colors.black54, size: 18),
                ),
              ),
              Positioned(
                right: (constraints.maxWidth - lineX + 8).clamp(8.0, constraints.maxWidth - 20.0),
                top: cy + 42,
                child: _splitLabel(filterName),
              ),
              Positioned(
                left: (lineX + 8).clamp(8.0, constraints.maxWidth - 56.0),
                top: cy + 42,
                child: _splitLabel('원본'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _splitLabel(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
  );

  Widget _buildSplitDragLayer(CameraState cameraState, double previewWidth) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) =>
          _updateSplitPosition(d.delta.dx, previewWidth, cameraState.isFrontCamera),
      child: const SizedBox.expand(),
    );
  }

  // MARK: - 온보딩 힌트

  Widget _buildSwipeHint() {
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: _showSwipeHint ? 0.85 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swipe_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('스와이프하여 필터 변경', style: TextStyle(color: Colors.white, fontSize: 14)),
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
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 13))),
            GestureDetector(
              onTap: () => ref.read(cameraProvider.notifier).clearError(),
              child: const Icon(Icons.close, color: Colors.white70, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - 헬퍼 버튼

  Widget _iconBtn(IconData icon, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.15)
              : const Color(0xFFF0EDEA),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: active ? AppColors.accent : const Color(0xFF5A5450), size: 20),
      ),
    );
  }

  Widget _glassBtn({required IconData icon, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Icon(icon, color: active ? AppColors.accent : Colors.white, size: 18),
      ),
    );
  }
}
