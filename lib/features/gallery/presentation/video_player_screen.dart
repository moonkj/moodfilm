import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/models/filter_model.dart';
import '../../../native_plugins/filter_engine/filter_engine.dart';
import '../../camera/presentation/widgets/filter_scroll_bar.dart';
import '../../camera/providers/camera_provider.dart';

/// 동영상 재생 + 실시간 필터/효과 편집 화면
/// AVPlayerItemVideoOutput → MFLUTEngine → FlutterTexture 파이프라인
class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoPath;
  final String? assetId;
  const VideoPlayerScreen({super.key, required this.videoPath, this.assetId});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  // 공유 버튼 위치 (iOS sharePositionOrigin용)
  final _shareButtonKey = GlobalKey();

  // 텍스처
  int? _textureId;
  double _videoWidth  = 1080;
  double _videoHeight = 1920;

  // 재생 상태
  bool _isPlaying = false;
  bool _isInitializing = true;
  bool _isProcessing = false;

  // 필터
  bool _noFilter = true;

  // 효과 파라미터
  static const _params = [
    (label: '밝기',   icon: Icons.wb_sunny_outlined,               min: -1.0, max: 1.0),
    (label: '대비',   icon: Icons.contrast,                         min: -1.0, max: 1.0),
    (label: '채도',   icon: Icons.palette_outlined,                 min: -1.0, max: 1.0),
    (label: '솜결',   icon: Icons.face_retouching_natural_rounded,  min: 0.0,  max: 1.0),
    (label: '뽀얀',   icon: Icons.blur_circular_rounded,            min: 0.0,  max: 1.0),
    (label: '글로우',  icon: Icons.flare_rounded,                   min: 0.0,  max: 1.0),
  ];
  int _activeParamIndex = 0;
  double _brightness = 0;
  double _contrast   = 0;
  double _saturation = 0;
  double _softness   = 0;
  double _beauty     = 0;
  double _dreamyGlow = 0;

  String _activeTab = 'filter';

  // 필터 디바운스 (빠른 스크롤 시 중간 LUT 로드 방지)
  Timer? _filterDebounce;

  bool get _hasEffectChanges =>
      _brightness != 0 || _contrast != 0 || _saturation != 0 ||
      _softness != 0 || _beauty != 0 || _dreamyGlow != 0;

  Map<String, double> get _currentEffects => {
    'brightness': _brightness,
    'contrast':   _contrast,
    'saturation': _saturation,
    'softness':   _softness,
    'beauty':     _beauty,
    'dreamyGlow': _dreamyGlow,
  };

  double _getParamValue(int i) {
    switch (i) {
      case 0: return _brightness;
      case 1: return _contrast;
      case 2: return _saturation;
      case 3: return _softness;
      case 4: return _beauty;
      case 5: return _dreamyGlow;
      default: return 0;
    }
  }

  void _setParam(int i, double v) {
    switch (i) {
      case 0: _brightness = v;
      case 1: _contrast   = v;
      case 2: _saturation = v;
      case 3: _softness   = v;
      case 4: _beauty     = v;
      case 5: _dreamyGlow = v;
    }
  }

  String _formatValue(int i) {
    final v = _getParamValue(i);
    final n = (v * 100).round();
    return n >= 0 ? '+$n' : '$n';
  }

  // MARK: - 초기화

  @override
  void initState() {
    super.initState();
    final camera = ref.read(cameraProvider);
    _noFilter = camera.activeFilter == null;
    _startPreview();
  }

  Future<void> _startPreview() async {
    final camera = ref.read(cameraProvider);
    final lutFile  = _noFilter ? '' : (camera.activeFilter?.lutFileName ?? '');
    final intensity = _noFilter ? 0.0 : camera.filterIntensity;

    // 전체 LUT 목록을 네이티브에 전달 → 백그라운드에서 캐시 선점
    final allLuts = FilterData.all.map((f) => f.lutFileName).toList();

    final result = await FilterEngine.startVideoPreview(
      videoPath:   widget.videoPath,
      lutFileName: lutFile,
      intensity:   intensity,
      effects:     _currentEffects,
      preloadLuts: allLuts,
    );

    if (!mounted || result == null) return;

    final textureId = result['textureId'] as int?;
    final w = (result['width']  as int? ?? 1080).toDouble();
    final h = (result['height'] as int? ?? 1920).toDouble();

    setState(() {
      _textureId = textureId;
      if (w > 0 && h > 0) { _videoWidth = w; _videoHeight = h; }
      _isInitializing = false;
      _isPlaying = true;
    });
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    FilterEngine.stopVideoPreview();
    super.dispose();
  }

  // MARK: - 필터/효과 업데이트 (실시간)

  void _onFilterChanged() {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 120), () {
      final camera = ref.read(cameraProvider);
      FilterEngine.setVideoPreviewFilter(
        lutFileName: _noFilter ? '' : (camera.activeFilter?.lutFileName ?? ''),
        intensity:   _noFilter ? 0.0 : camera.filterIntensity,
      );
    });
  }

  void _onEffectsChanged() {
    FilterEngine.setVideoPreviewEffects(_currentEffects);
  }

  // MARK: - 재생 제어

  void _togglePlayPause() {
    if (_isPlaying) {
      FilterEngine.pauseVideoPreview();
    } else {
      FilterEngine.playVideoPreview();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  // MARK: - 저장

  Future<void> _saveVideo() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final camera = ref.read(cameraProvider);
    final lutFile = _noFilter ? '' : (camera.activeFilter?.lutFileName ?? '');

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('저장 중...'),
      backgroundColor: Color(0xFF3D3531),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 30),
    ));

    try {
      final result = await FilterEngine.processVideo(
        sourcePath:    widget.videoPath,
        lutFileName:   lutFile,
        intensity:     _noFilter ? 0.0 : camera.filterIntensity,
        effects:       _currentEffects,
        saveToGallery: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result != null ? '갤러리에 저장했습니다' : '저장 실패'),
        backgroundColor: result != null ? const Color(0xFF3D3531) : Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('오류: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// 공유 버튼의 화면 좌표 (iOS sharePositionOrigin 필수)
  Rect get _shareButtonRect {
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      final w = MediaQuery.of(context).size.width;
      return Rect.fromLTWH(w - 96, 4, 36, 36);
    }
    final pos = box.localToGlobal(Offset.zero);
    return pos & box.size;
  }

  Future<void> _shareVideo() async {
    if (_isProcessing) return;

    final camera = ref.read(cameraProvider);
    final hasFilter = !_noFilter && camera.activeFilter != null;

    // 필터/효과 없으면 원본 바로 공유
    if (!hasFilter && !_hasEffectChanges) {
      try {
        await Share.shareXFiles(
          [XFile(widget.videoPath, mimeType: 'video/mp4')],
          sharePositionOrigin: _shareButtonRect,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('공유 실패: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
      return;
    }

    // 필터/효과 있으면 export 후 공유
    if (!mounted) return;
    setState(() => _isProcessing = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('공유 준비 중...'),
      backgroundColor: Color(0xFF3D3531),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 60),
    ));

    try {
      final result = await FilterEngine.processVideo(
        sourcePath:    widget.videoPath,
        lutFileName:   _noFilter ? '' : (camera.activeFilter?.lutFileName ?? ''),
        intensity:     _noFilter ? 0.0 : camera.filterIntensity,
        effects:       _currentEffects,
        saveToGallery: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (result != null) {
        await Share.shareXFiles(
          [XFile(result, mimeType: 'video/mp4')],
          sharePositionOrigin: _shareButtonRect,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('공유 준비 실패'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('공유 실패: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteVideo() async {
    if (widget.assetId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 동영상을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await PhotoManager.editor.deleteWithIds([widget.assetId!]);
    if (mounted) Navigator.of(context).pop();
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    ref.listen(cameraProvider, (prev, next) {
      final prevId = prev?.activeFilter?.id;
      final nextId = next.activeFilter?.id;
      if (prevId != nextId) {
        setState(() => _noFilter = nextId == null);
        _onFilterChanged();
      }
      // 강도 변경 시 실시간 반영
      if (prev?.filterIntensity != next.filterIntensity && !_noFilter) {
        _onFilterChanged();
      }
    });

    final screenW = MediaQuery.of(context).size.width;
    final camera = ref.watch(cameraProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(camera),
                // 동영상 프리뷰 — 남은 공간 전체 사용, 비율 유지(FittedBox)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!_isInitializing) _togglePlayPause();
                    },
                    child: Container(
                      width: screenW,
                      color: Colors.black,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_textureId != null)
                            FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: _videoWidth,
                                height: _videoHeight,
                                child: Texture(textureId: _textureId!),
                              ),
                            )
                          else
                            const CircularProgressIndicator(
                                color: Colors.white38),
                          if (!_isInitializing && !_isPlaying)
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 32),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: AppDimensions.filterBarHeight + 52,
                  child: _activeTab == 'effect'
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildEffectRow(),
                            _buildTickSlider(),
                            const SizedBox(height: 4),
                          ],
                        )
                      : _buildFilterSection(),
                ),
                _buildBottomTabBar(camera),
              ],
            ),
            if (_isProcessing)
              const IgnorePointer(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // MARK: - 상단 바

  Widget _buildTopBar(dynamic camera) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Color(0xFF3D3531), size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          if (!_noFilter || _hasEffectChanges) ...[
            GestureDetector(
              onTap: () {
                ref.read(cameraProvider.notifier).clearFilter();
                setState(() {
                  _noFilter = true;
                  _brightness = 0; _contrast = 0; _saturation = 0;
                  _softness = 0; _beauty = 0; _dreamyGlow = 0;
                });
                _onFilterChanged();
                _onEffectsChanged();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F2EF),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFFE0DAD4), width: 0.5),
                ),
                child: const Text('초기화',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A8480),
                        fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.assetId != null) ...[
            _topIconBtn(Icons.delete_outline_rounded,
                onTap: _deleteVideo, iconColor: Colors.red),
            const SizedBox(width: 8),
          ],
          _topIconBtn(Icons.ios_share_rounded, onTap: _shareVideo,
              widgetKey: _shareButtonKey),
          const SizedBox(width: 8),
          _topIconBtn(Icons.download_rounded, onTap: _saveVideo),
        ],
      ),
    );
  }

  Widget _topIconBtn(IconData icon,
      {required VoidCallback onTap, bool active = false, Color? iconColor, Key? widgetKey}) {
    return GestureDetector(
      key: widgetKey,
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3D3531) : const Color(0xFFF5F0EC),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE0DAD4), width: 0.5),
        ),
        child: Icon(icon,
            color: active ? Colors.white : (iconColor ?? const Color(0xFF3D3531)),
            size: 18),
      ),
    );
  }

  // MARK: - 효과 파라미터 행

  Widget _buildEffectRow() {
    return SizedBox(
      height: 68,
      child: Row(
        children: List.generate(_params.length, (i) {
          final isActive = i == _activeParamIndex;
          final param = _params[i];
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _activeParamIndex = i),
              child: SizedBox(
                height: 68,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 52, height: 28,
                      child: Center(
                        child: isActive
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFADDE6),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(_formatValue(i),
                                    style: const TextStyle(
                                        color: Color(0xFFB06878),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              )
                            : Icon(param.icon,
                                color: const Color(0xFF8A8480), size: 20),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(param.label,
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFFB06878)
                              : const Color(0xFF8A8480),
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        )),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // MARK: - 슬라이더

  Widget _buildTickSlider() {
    final param = _params[_activeParamIndex];
    final value = _getParamValue(_activeParamIndex);
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: SliderComponentShape.noOverlay,
          activeTrackColor: const Color(0xFFD4A0B0),
          inactiveTrackColor: const Color(0xFFEAE4E0),
          thumbColor: const Color(0xFF8A6870),
        ),
        child: Slider(
          value: value,
          min: param.min,
          max: param.max,
          divisions: 200,
          onChanged: (v) {
            setState(() => _setParam(_activeParamIndex, v));
            _onEffectsChanged();
          },
          onChangeEnd: (_) {},
        ),
      ),
    );
  }

  // MARK: - 필터 섹션

  Widget _buildFilterSection() {
    final camera = ref.watch(cameraProvider);
    final intensity = _noFilter ? 1.0 : camera.filterIntensity;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: AppDimensions.filterBarHeight,
          child: FilterScrollBar(
            isNoFilterSelected: _noFilter,
            onNoFilterSelected: () {
              ref.read(cameraProvider.notifier).clearFilter();
              setState(() => _noFilter = true);
              _onFilterChanged();
            },
          ),
        ),
        if (!_noFilter)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: const Color(0xFFD4A0B0),
                inactiveTrackColor: const Color(0xFFEAE4E0),
                thumbColor: const Color(0xFF8A6870),
              ),
              child: Slider(
                value: intensity.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                onChanged: (v) {
                  ref.read(cameraProvider.notifier).setFilterIntensity(v);
                },
                onChangeEnd: (_) {},
              ),
            ),
          )
        else
          const SizedBox(height: 36),
      ],
    );
  }

  // MARK: - 하단 탭 바

  Widget _buildBottomTabBar(dynamic camera) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEDE8E4), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTab('필터', Icons.auto_awesome_rounded, 'filter', hasDot: !_noFilter),
          _buildTab('효과', Icons.flare_rounded, 'effect', hasDot: _hasEffectChanges),
        ],
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, String tabId,
      {bool hasDot = false}) {
    final isActive = _activeTab == tabId;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _activeTab = tabId),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    color: isActive
                        ? const Color(0xFF3D3531)
                        : const Color(0xFFBBB6B2),
                    size: 22),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFF3D3531)
                          : const Color(0xFFBBB6B2),
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    )),
              ],
            ),
          ),
          if (hasDot)
            Positioned(
              top: 6, right: 24,
              child: Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: AppColors.accent, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}
