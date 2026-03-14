import 'dart:async';
import 'dart:io';
import 'dart:math' show pi;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/models/filter_model.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/services/router.dart' show routeObserver;
import '../../../l10n/app_localizations.dart';
import '../../../native_plugins/camera_engine/camera_engine.dart';
import '../providers/camera_provider.dart';
import '../models/camera_state.dart';
import 'widgets/shutter_button.dart';
import 'widgets/filter_scroll_bar.dart';
import 'widgets/exposure_indicator.dart';
import '../../gallery/presentation/video_player_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});
  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin, RouteAware {

  late final AnimationController _flipController;
  late final AnimationController _recPulseController;

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

  // 필터 패널 (앱 실행 시 기본 열림)


  // 색보정 효과 패널
  bool _showEffectsPanel = false;
  int _selectedEffectIndex = 0;
  final Map<String, double> _adjustments = {
    'brightness': 0.0,
    'contrast':   0.0,
    'saturation': 0.0,
    'softness':   0.2,  // 기본 솜결 20%
    'beauty':     0.12, // 기본 뽀얀 12%
    'glow':       0.0,
  };

  // 타이머
  int _timerSeconds = 0; // 0=off, 3, 5, 10
  int _timerCountdown = 0;
  Timer? _countdownTimer;
  bool _isCountingDown = false;

  // 사이드 버튼 레이블 (클릭 시 2초 표시)
  String? _sideBtnLabel;
  Timer? _sideBtnLabelTimer;

  // 사이드 버튼 자동숨김 (5초 후)
  bool _showSideButtons = true;
  Timer? _sideButtonsHideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _recPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(cameraProvider.notifier).initialize();
      _applyDefaultEffects();
      _checkOnboardingHints();
      _resetSideButtonsTimer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion 대응
    final disable = MediaQuery.of(context).disableAnimations;
    _flipController.duration = disable ? Duration.zero : const Duration(milliseconds: 600);
    // RouteObserver 구독 (화면 전환 감지)
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  void _applyDefaultEffects() {
    for (final entry in _adjustments.entries) {
      if (entry.value != 0.0) {
        CameraEngine.setEffect(effectType: entry.key, intensity: entry.value);
      }
    }
  }

  Future<void> _doCapturePhoto(CameraState cameraState) async {
    if (_isSplitMode) {
      CameraEngine.setSplitMode(position: -1.0, isFrontCamera: cameraState.isFrontCamera);
    }
    await ref.read(cameraProvider.notifier).capturePhoto();
    if (_isSplitMode && mounted) {
      CameraEngine.setSplitMode(
        position: _computeNativeSplitPos(_splitPosition, cameraState.isFrontCamera),
        isFrontCamera: cameraState.isFrontCamera,
      );
    }
  }

  void _handleShutterTap(CameraState cameraState) {
    if (_isCountingDown) {
      // 카운트다운 중 셔터 재탭 → 취소
      _countdownTimer?.cancel();
      setState(() { _isCountingDown = false; _timerCountdown = 0; });
      return;
    }
    if (_timerSeconds == 0) {
      _doCapturePhoto(cameraState);
      return;
    }
    // 카운트다운 시작
    HapticUtils.filterChange();
    setState(() { _isCountingDown = true; _timerCountdown = _timerSeconds; });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) { timer.cancel(); return; }
      if (_timerCountdown <= 1) {
        timer.cancel();
        setState(() { _isCountingDown = false; _timerCountdown = 0; });
        await _doCapturePhoto(cameraState);
      } else {
        setState(() => _timerCountdown--);
        HapticUtils.filterChange();
      }
    });
  }

  void _checkOnboardingHints() {
    final prefs = StorageService.prefs;
    if (!prefs.hasSeenSwipeHint) {
      setState(() => _showSwipeHint = true);
      Future.delayed(const Duration(seconds: 3), () {
        prefs.hasSeenSwipeHint = true;
        prefs.save();
        if (mounted) setState(() => _showSwipeHint = false);
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

  void _resetSideButtonsTimer() {
    _sideButtonsHideTimer?.cancel();
    if (!_showSideButtons) setState(() => _showSideButtons = true);
    _sideButtonsHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() { _showSideButtons = false; _showIntensitySlider = false; });
    });
  }

  // 슬라이더 드래그 중: 타이머 정지만 (숨김 방지)
  void _pauseSideButtonsTimer() {
    _sideButtonsHideTimer?.cancel();
    if (!_showSideButtons) setState(() => _showSideButtons = true);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _splitAutoHideTimer?.cancel();
    _sideBtnLabelTimer?.cancel();
    _sideButtonsHideTimer?.cancel();
    _countdownTimer?.cancel();
    _flipController.dispose();
    _recPulseController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    ref.read(cameraProvider.notifier).disposeCamera();
    super.dispose();
  }

  // 다른 화면으로 이동 → 카메라 세션 일시정지
  @override
  void didPushNext() {
    CameraEngine.pauseSession();
  }

  // 다른 화면에서 돌아옴 → 카메라 세션 재개
  @override
  void didPopNext() {
    CameraEngine.resumeSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(cameraProvider.notifier).initialize().then((_) {
        if (mounted) _applyDefaultEffects();
      });
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
    _resetSideButtonsTimer();
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
              ClipRect(
                child: SizedBox(
                  width: screenW,
                  height: previewH,
                  child: _buildPreviewStack(cameraState, screenW),
                ),
              ),
              // 하단 컨트롤
              Expanded(
                child: _buildBottomArea(cameraState, safeBottom),
              ),
            ],
          ),
          // 밝기 인디케이터 (강도 슬라이더 위)
          Positioned(
            top: safeTop + previewH - 52 - 48,
            left: 0,
            right: 0,
            child: Center(
              child: ExposureIndicator(
                ev: cameraState.exposureEV,
                isVisible: _showExposureIndicator,
              ),
            ),
          ),
          // 강도 슬라이더 (프리뷰 위 오버레이 — 레이아웃 영향 없음)
          if (_showIntensitySlider)
            Positioned(
              top: safeTop + previewH - 52,
              left: 24,
              right: 24,
              child: _buildIntensitySliderWidget(cameraState),
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
          // 강도 슬라이더 표시 중에는 모든 제스처 비활성 → 슬라이더 thumb 드래그 허용
          onTap: _showIntensitySlider ? null : _resetSideButtonsTimer,
          onScaleStart: _showIntensitySlider ? null : _onScaleStart,
          onScaleUpdate: _showIntensitySlider ? null : _onScaleUpdate,
          onScaleEnd: _showIntensitySlider ? null : _onScaleEnd,
          onDoubleTap: _showIntensitySlider ? null : _handleCameraFlip,
          child: const SizedBox.expand(),
        ),
        if (_isSplitMode && !cameraState.isRecording) _buildSplitOverlay(cameraState),
        if (_isSplitMode && !cameraState.isRecording) _buildSplitDragLayer(cameraState, screenW),
        _buildPreviewSideButtons(cameraState),
        if (cameraState.isRecording) _buildRecBadge(),
        // 타이머 카운트다운 오버레이
        if (_isCountingDown)
          IgnorePointer(
            child: Center(
              child: Text(
                '$_timerCountdown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 110,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 24, color: Colors.black54)],
                ),
              ),
            ),
          ),
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
    return ClipRect(
      child: AnimatedBuilder(
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
      ),
    );
  }

  // MARK: - 프리뷰 우측 사이드 버튼 (라이브포토 + 비교 + 강도 + 설정)

  Widget _buildPreviewSideButtons(CameraState cameraState) {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      right: 10,
      bottom: 68, // 강도 슬라이더(하단 52px) 위에 배치
      child: AnimatedOpacity(
        opacity: _showSideButtons ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _timerSideBtn(l10n),
          const SizedBox(height: 10),
          _sideLabeledBtn(
            labelKey: 'filterEffect',
            labelText: l10n.effectTab,
            icon: Icons.tune_rounded,
            active: _showIntensitySlider,
            onTap: () {
              _resetSideButtonsTimer();
              setState(() => _showIntensitySlider = !_showIntensitySlider);
              _showSideBtnLabel('filterEffect');
            },
          ),
          const SizedBox(height: 10),
          _sideLabeledBtn(
            labelKey: 'compare',
            labelText: l10n.original,
            icon: Icons.compare_rounded,
            active: _isSplitMode,
            onTap: () {
              _resetSideButtonsTimer();
              _toggleSplitMode(cameraState.isFrontCamera);
              _showSideBtnLabel('compare');
            },
          ),
          const SizedBox(height: 10),
          _sideLabeledBtn(
            labelKey: 'settings',
            labelText: l10n.settings,
            icon: Icons.settings_outlined,
            active: false,
            onTap: () {
              _resetSideButtonsTimer();
              _showSideBtnLabel('settings');
              context.push('/settings');
            },
          ),
        ],
        ),
      ),
    );
  }

  Widget _timerSideBtn(AppLocalizations l10n) {
    final showLabel = _sideBtnLabel == 'timer';
    final isActive = _timerSeconds > 0 || _isCountingDown;
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
                  child: Text(
                    _timerSeconds > 0 ? l10n.timerSeconds(_timerSeconds) : l10n.camera,
                    style: const TextStyle(color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        GestureDetector(
          onTap: () {
            if (_isCountingDown) return;
            _resetSideButtonsTimer();
            const options = [0, 3, 5, 10];
            final idx = options.indexOf(_timerSeconds);
            setState(() => _timerSeconds = options[(idx + 1) % options.length]);
            HapticUtils.filterChange();
            _showSideBtnLabel('timer');
          },
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15), width: 0.5),
            ),
            child: Center(
              child: _timerSeconds > 0
                  ? Text(
                      l10n.timerSeconds(_timerSeconds),
                      style: TextStyle(
                        color: isActive ? AppColors.accent : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Icon(
                      Icons.timer_outlined,
                      color: isActive ? AppColors.accent : Colors.white,
                      size: 18,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sideLabeledBtn({
    required String labelKey,
    required String labelText,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    final showLabel = _sideBtnLabel == labelKey;
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
                  child: Text(labelText,
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

  Widget _buildIntensitySliderWidget(CameraState cameraState) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.wb_sunny_outlined, color: Colors.white70, size: 15),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayColor: Colors.transparent,
              ),
              child: Slider(
                value: cameraState.filterIntensity,
                min: 0,
                max: 1,
                onChanged: (v) {
                  _pauseSideButtonsTimer();
                  ref.read(cameraProvider.notifier).setFilterIntensity(v);
                },
                onChangeEnd: (_) => _resetSideButtonsTimer(),
                activeColor: Colors.white,
                inactiveColor: Colors.white30,
              ),
            ),
          ),
          Text(
            '${(cameraState.filterIntensity * 100).toInt()}%',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomArea(CameraState cameraState, double safeBottom) {
    return Column(
      children: [
        const SizedBox(height: 8),
        // 패널 영역: 고정 높이로 사진/동영상 텍스트 위치 고정
        SizedBox(
          height: AppDimensions.filterBarHeight,
          child: AnimatedSwitcher(
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 200),
            child: _showEffectsPanel
                ? _buildEffectsPanel()
                : FilterScrollBar(
                    key: const ValueKey('filter'),
                    isNoFilterSelected: cameraState.activeFilter == null,
                    onNoFilterSelected: () => ref.read(cameraProvider.notifier).clearFilter(),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        // 사진 / 동영상 모드 탭
        _buildModeSelector(cameraState),
        const Spacer(),
        // 셔터 행: [갤러리, 필터] [셔터(center)] [효과, 카메라전환]
        Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, safeBottom > 0 ? safeBottom : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 좌측: 갤러리 + 필터
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildGalleryButton(cameraState),
                    const SizedBox(width: 12),
                    _iconBtn(
                      _showEffectsPanel ? Icons.auto_awesome_outlined : Icons.auto_awesome,
                      () => setState(() {
                        _showEffectsPanel = false;
                      }),
                      active: !_showEffectsPanel,
                    ),
                  ],
                ),
              ),
              // 중앙: 셔터
              if (cameraState.isVideoMode)
                _buildVideoRecordButton(cameraState)
              else
                ShutterButton(
                  isCapturing: cameraState.isCapturing || _isCountingDown,
                  onTap: () => _handleShutterTap(cameraState),
                ),
              // 우측: 색보정 효과 + 카메라전환
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _iconBtn(
                      Icons.auto_fix_high_rounded,
                      () => setState(() {
                        _showEffectsPanel = true;
                      }),
                      active: _showEffectsPanel,
                    ),
                    const SizedBox(width: 12),
                    _iconBtn(Icons.flip_camera_ios_rounded, _handleCameraFlip),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // MARK: - 색보정 효과 패널

  // (key, label, icon, min, max) — labels resolved at build time via l10n
  List<(String, String, IconData, double, double)> _effectItems(AppLocalizations l10n) => [
    ('softness',   l10n.softness,   Icons.face_retouching_natural_rounded,  0.0, 1.0),
    ('beauty',     l10n.beauty,     Icons.blur_circular_rounded,            0.0, 1.0),
    ('brightness', l10n.brightness, Icons.wb_sunny_outlined,               -1.0, 1.0),
    ('contrast',   l10n.contrast,   Icons.contrast_rounded,                -1.0, 1.0),
    ('saturation', l10n.saturation, Icons.palette_outlined,                -1.0, 1.0),
    ('glow',       l10n.glow,       Icons.flare_rounded,                    0.0, 1.0),
  ];

  Widget _buildEffectsPanel() {
    final l10n = AppLocalizations.of(context);
    final effectItems = _effectItems(l10n);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 효과 선택 버튼 행
        SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(effectItems.length, (i) {
              final (key, label, icon, _, _) = effectItems[i];
              final isActive = i == _selectedEffectIndex;
              final value = _adjustments[key]!;
              final n = (value * 100).round();
              final displayStr = n >= 0 ? '+$n' : '$n';
              return GestureDetector(
                onTap: () => setState(() => _selectedEffectIndex = i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    isActive
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFADDE6),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              displayStr,
                              style: const TextStyle(
                                color: Color(0xFFB06878),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : Icon(icon, color: const Color(0xFF8A8480), size: 20),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFFB06878)
                            : const Color(0xFF8A8480),
                        fontSize: 11,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        // 선택된 효과의 단일 슬라이더
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Builder(builder: (context) {
            final (key, _, _, min, max) = effectItems[_selectedEffectIndex];
            final value = _adjustments[key]!;
            return SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayColor: Colors.transparent,
                activeTrackColor: const Color(0xFFD4A0B0),
                inactiveTrackColor: const Color(0xFFEAE4E0),
                thumbColor: const Color(0xFF8A6870),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: 200,
                onChanged: (v) {
                  _pauseSideButtonsTimer();
                  setState(() => _adjustments[key] = v);
                  CameraEngine.setEffect(effectType: key, intensity: v);
                },
                onChangeEnd: (_) => _resetSideButtonsTimer(),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildModeSelector(CameraState cameraState) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _modeTab(l10n.photo, !cameraState.isVideoMode, cameraState),
        const SizedBox(width: 24),
        _modeTab(l10n.video, cameraState.isVideoMode, cameraState),
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
          fontSize: 16,
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
        final path = cameraState.lastCapturedPath;
        if (path == null) return;
        if (_isVideoFile(path)) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(videoPath: path),
          ));
        } else {
          context.push('/editor', extra: path);
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
                    ? _VideoThumbnail(path: cameraState.lastCapturedPath!)
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
    final outerSize = AppDimensions.shutterButtonSize + 4; // 80px — layout 고정
    return GestureDetector(
      onTap: () {
        if (rec) {
          ref.read(cameraProvider.notifier).stopRecording();
          // 녹화 종료 시 스플릿 복원
          if (_isSplitMode) {
            CameraEngine.setSplitMode(
              position: _computeNativeSplitPos(_splitPosition, cameraState.isFrontCamera),
              isFrontCamera: cameraState.isFrontCamera,
            );
          }
        } else {
          // 녹화 시작 시 스플릿 숨김 (전체 필터 적용)
          if (_isSplitMode) {
            CameraEngine.setSplitMode(position: -1.0, isFrontCamera: cameraState.isFrontCamera);
          }
          ref.read(cameraProvider.notifier).startRecording();
        }
      },
      child: SizedBox(
        width: outerSize,
        height: outerSize,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            // 녹화 중: 정지 아이콘 보일 흰 원 + 빨간 사각형 / 대기: 중간 크기 빨간 원
            width: rec ? outerSize - 4 : 62,
            height: rec ? outerSize - 4 : 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rec ? Colors.white : Colors.red,
            ),
            child: rec
                ? Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  // MARK: - 녹화 타이머

  Widget _buildRecBadge() {
    return Positioned(
      top: 16,
      right: 16,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _recPulseController,
          builder: (context, child) {
            // 0.3 → 1.0 으로 천천히 왕복 (부드러운 점멸)
            final dotOpacity = 0.3 + _recPulseController.value * 0.7;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: dotOpacity,
                    child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'REC',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
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
              // 라벨: 원(36×36)과 수평 — 원 중앙(cy+18)에 맞춤
              Positioned(
                top: cy + 9,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    SizedBox(
                      width: (lineX - 18).clamp(0.0, double.infinity),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _splitLabel(AppLocalizations.of(context).original),
                        ),
                      ),
                    ),
                    const SizedBox(width: 36), // 원 너비만큼 건너뜀
                    SizedBox(
                      width: (constraints.maxWidth - lineX - 18).clamp(0.0, double.infinity),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _splitLabel(filterName),
                        ),
                      ),
                    ),
                  ],
                ),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swipe_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).swipeToChangeFilter,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
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

/// 비디오 파일 경로에서 첫 프레임 썸네일을 비동기 추출해 표시
class _VideoThumbnail extends StatefulWidget {
  final String path;
  const _VideoThumbnail({required this.path});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  Uint8List? _thumb;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_VideoThumbnail old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _thumb = null;
      _loaded = false;
      _load();
    }
  }

  Future<void> _load() async {
    final data = await VideoThumbnail.thumbnailData(
      video: widget.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 128,
      quality: 75,
    );
    if (mounted) setState(() { _thumb = data; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (_thumb != null) {
      return Image.memory(_thumb!, fit: BoxFit.cover);
    }
    return const ColoredBox(
      color: Color(0xFF1A1A1A),
      child: Center(
        child: Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 22),
      ),
    );
  }
}
