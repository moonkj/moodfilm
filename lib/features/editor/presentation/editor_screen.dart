import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../native_plugins/filter_engine/filter_engine.dart';
import '../../camera/presentation/widgets/filter_scroll_bar.dart';
import '../../camera/providers/camera_provider.dart';

/// 편집 화면
/// 갤러리 Import 또는 촬영 직후 → 필터 + 슬라이더 + 이펙트 적용
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.imagePath});
  final String? imagePath;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {

  // 기본 조정
  double _exposure = 0;
  double _contrast = 0;
  double _highlights = 0;
  double _shadows = 0;
  double _saturation = 0;
  double _temperature = 0;
  double _tint = 0;
  // 디테일 조정
  double _sharpness = 0;
  double _fade = 0;
  double _vignette = 0;
  double _skinTone = 0;
  // 이펙트
  double _dreamyGlow = 0;
  double _filmGrain = 0;
  double _beauty = 0;

  // 기본 "효과 없음" 상태 — 찍은 사진에 이미 필터가 베이크되어 있으므로
  bool _editorNoFilter = true;

  String? _filteredPreviewPath;
  bool _isGeneratingPreview = false;
  bool _showSplitView = false;
  double _splitPosition = 0.5;

  // 활성 패널: null | 'filter' | 'adjust' | 'effect'
  String? _activePanel;

  @override
  void initState() {
    super.initState();
    // 자동 preview 생성 없음: 찍은 사진에 이미 필터가 적용되어 있음
  }

  bool _hasAdjustments() =>
      _exposure != 0 || _contrast != 0 || _highlights != 0 || _shadows != 0 ||
      _saturation != 0 || _temperature != 0 || _tint != 0 ||
      _sharpness != 0 || _fade != 0 || _vignette != 0 || _skinTone != 0;

  bool _hasEffects() => _dreamyGlow != 0 || _filmGrain != 0 || _beauty != 0;

  void _resetAdjustments() {
    setState(() {
      _exposure = 0; _contrast = 0; _highlights = 0; _shadows = 0;
      _saturation = 0; _temperature = 0; _tint = 0;
      _sharpness = 0; _fade = 0; _vignette = 0; _skinTone = 0;
    });
    _generatePreview();
  }

  void _resetEffects() {
    setState(() { _dreamyGlow = 0; _filmGrain = 0; _beauty = 0; });
    _generatePreview();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(cameraProvider, (prev, next) {
      final prevId = prev?.activeFilter?.id;
      final nextId = next.activeFilter?.id;
      if (prevId != nextId) {
        if (nextId == null) {
          // "효과 없음" 선택
          setState(() { _editorNoFilter = true; _filteredPreviewPath = null; });
        } else {
          setState(() => _editorNoFilter = false);
          _generatePreview();
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 풀스크린 사진
          _buildFullScreenImage(),

          // 2. 상단 오버레이 (닫기 / 비교 / 저장)
          _buildTopOverlay(),

          // 3. 하단 컨트롤 패널
          _buildBottomPanel(),

          // 4. 프리뷰 생성 중 로딩
          if (_isGeneratingPreview)
            const IgnorePointer(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generatePreview() async {
    if (widget.imagePath == null || _isGeneratingPreview) return;

    // 효과 없음 + 조정값/이펙트도 없으면 원본 그대로 표시
    if (_editorNoFilter && !_hasAdjustments() && !_hasEffects()) {
      setState(() { _filteredPreviewPath = null; });
      return;
    }

    setState(() => _isGeneratingPreview = true);
    final camera = ref.read(cameraProvider);
    final path = await FilterEngine.processImage(
      sourcePath: widget.imagePath!,
      lutFileName: _editorNoFilter ? '' : (camera.activeFilter?.lutFileName ?? ''),
      intensity: _editorNoFilter ? 0.0 : camera.filterIntensity,
      adjustments: _buildAdjustments(),
      effects: {'filmGrain': _filmGrain, 'dreamyGlow': _dreamyGlow, 'beauty': _beauty},
    );
    if (mounted) {
      setState(() { _filteredPreviewPath = path; _isGeneratingPreview = false; });
    }
  }

  Widget _buildTopOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _darkCircleBtn(Icons.close_rounded, () => Navigator.of(context).pop()),
            _darkPillBtn('저장', _saveImage),
          ],
        ),
      ),
    );
  }

  Widget _darkCircleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _darkPillBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildFullScreenImage() {
    if (widget.imagePath == null) {
      return const Center(
          child: Icon(Icons.add_photo_alternate_outlined,
              color: Colors.white38, size: 64));
    }
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (_showSplitView) {
          final width = MediaQuery.of(context).size.width;
          setState(() {
            _splitPosition = (details.globalPosition.dx / width).clamp(0.0, 1.0);
          });
        }
      },
      child: _showSplitView ? _buildSplitView() : _buildMainPreview(),
    );
  }

  Widget _buildMainPreview() {
    return Image.file(
      key: ValueKey(_filteredPreviewPath ?? widget.imagePath!),
      File(_filteredPreviewPath ?? widget.imagePath!),
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
    );
  }

  Widget _buildBottomPanel() {
    const panelH = 260.0;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 패널 콘텐츠 (아래서 슬라이드업 애니메이션)
            ClipRect(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                height: _activePanel != null ? panelH : 0,
                child: _activePanel != null
                    ? OverflowBox(
                        alignment: Alignment.bottomCenter,
                        maxHeight: panelH,
                        child: Container(
                          height: panelH,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent,
                                  Colors.black.withValues(alpha: 0.85)],
                              stops: const [0.0, 0.3],
                            ),
                          ),
                          child: _buildPanelContent(panelH),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            // 하단 탭 버튼 바
            _buildBottomTabBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelContent(double height) {
    switch (_activePanel) {
      case 'filter':
        return SizedBox(
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilterScrollBar(
                isNoFilterSelected: _editorNoFilter,
                onNoFilterSelected: () {
                  ref.read(cameraProvider.notifier).clearFilter();
                  setState(() {
                    _editorNoFilter = true;
                    _filteredPreviewPath = null;
                  });
                },
              ),
            ],
          ),
        );
      case 'adjust':
        return SizedBox(
          height: height,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                AppDimensions.paddingM, 12, AppDimensions.paddingM, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('기본'),
                _buildSlider('노출', _exposure, -1.0, 1.0,
                    (v) => setState(() => _exposure = v),
                    onChangeEnd: (_) => _generatePreview()),
                _buildSlider('대비', _contrast, -1.0, 1.0,
                    (v) => setState(() => _contrast = v),
                    onChangeEnd: (_) => _generatePreview()),
                _buildSlider('채도', _saturation, -1.0, 1.0,
                    (v) => setState(() => _saturation = v),
                    onChangeEnd: (_) => _generatePreview()),
                _buildSlider('하이라이트', _highlights, -1.0, 1.0,
                    (v) => setState(() => _highlights = v),
                    onChangeEnd: (_) => _generatePreview()),
                _buildSlider('그림자', _shadows, -1.0, 1.0,
                    (v) => setState(() => _shadows = v),
                    onChangeEnd: (_) => _generatePreview()),
                const SizedBox(height: 4),
                _sectionLabel('색온도'),
                _buildSlider('온도', _temperature, -1.0, 1.0,
                    (v) => setState(() => _temperature = v),
                    onChangeEnd: (_) => _generatePreview()),
                _buildSlider('틴트', _tint, -1.0, 1.0,
                    (v) => setState(() => _tint = v),
                    onChangeEnd: (_) => _generatePreview()),
                _buildSlider('피부톤', _skinTone, -1.0, 1.0,
                    (v) => setState(() => _skinTone = v),
                    onChangeEnd: (_) => _generatePreview()),
                const SizedBox(height: 4),
                _sectionLabel('디테일'),
                _buildSlider('선명도', _sharpness, -1.0, 1.0,
                    (v) => setState(() => _sharpness = v),
                    onChangeEnd: (_) => _generatePreview()),
                _buildSlider('페이드', _fade, 0.0, 1.0,
                    (v) => setState(() => _fade = v),
                    onChangeEnd: (_) => _generatePreview()),
                _buildSlider('비네트', _vignette, 0.0, 1.0,
                    (v) => setState(() => _vignette = v),
                    onChangeEnd: (_) => _generatePreview()),
              ],
            ),
          ),
        );
      case 'effect':
        return SizedBox(
          height: height,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                AppDimensions.paddingM, 24, AppDimensions.paddingM, 8),
            child: Column(
              children: [
                _buildEffectRow('Dreamy Glow', Icons.flare_rounded,
                    _dreamyGlow, (v) => setState(() => _dreamyGlow = v),
                    onChangeEnd: (_) => _generatePreview()),
                const SizedBox(height: 16),
                _buildEffectRow('Film Grain', Icons.grain_rounded,
                    _filmGrain, (v) => setState(() => _filmGrain = v),
                    onChangeEnd: (_) => _generatePreview()),
                const SizedBox(height: 16),
                _buildEffectRow('Beauty', Icons.face_retouching_natural_rounded,
                    _beauty, (v) => setState(() => _beauty = v),
                    onChangeEnd: (_) => _generatePreview()),
              ],
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabButton('필터', Icons.auto_awesome_rounded, 'filter'),
          _buildTabButton('조정', Icons.tune_rounded, 'adjust',
              hasChanges: _hasAdjustments()),
          _buildTabButton('이펙트', Icons.flare_rounded, 'effect',
              hasChanges: _hasEffects()),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, String panelId,
      {bool hasChanges = false}) {
    final isActive = _activePanel == panelId;
    return GestureDetector(
      onTap: () => setState(() {
        _activePanel = isActive ? null : panelId;
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.accent.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? AppColors.accent.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: Icon(icon,
                    color: isActive ? AppColors.accent : Colors.white,
                    size: 22),
              ),
              if (hasChanges)
                Positioned(
                  top: 2, right: 2,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.accent, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                color: isActive ? AppColors.accent : Colors.white60,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              )),
        ],
      ),
    );
  }

  Widget _buildSplitView() {
    final camera = ref.read(cameraProvider);
    final filterName = camera.activeFilter?.name ?? '효과';
    // 배경: 원본 / 왼쪽 클립: 필터 적용본
    final filtered = _filteredPreviewPath ?? widget.imagePath!;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final lineX = screenWidth * _splitPosition;

    return Stack(
      children: [
        // 배경 = 원본
        SizedBox.expand(child: Image.file(File(widget.imagePath!), fit: BoxFit.cover)),
        // 왼쪽 클립 = 필터 적용본
        ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: _splitPosition,
            child: Image.file(File(filtered), fit: BoxFit.cover,
                width: screenWidth),
          ),
        ),
        // 분할선 + 핸들
        Positioned(
          left: lineX - 1,
          top: 0, bottom: 0,
          child: Container(
            width: 2, color: Colors.white,
            child: Center(
              child: Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.compare_arrows_rounded,
                    color: AppColors.textPrimary, size: 16),
              ),
            ),
          ),
        ),
        // 왼쪽 라벨: 필터이름 (원 왼쪽)
        Positioned(
          right: (screenWidth - lineX + 10).clamp(10.0, screenWidth - 20),
          top: screenHeight * 0.5 + 20,
          child: _splitLabel(filterName),
        ),
        // 오른쪽 라벨: 원본 (원 오른쪽)
        Positioned(
          left: (lineX + 10).clamp(10.0, screenWidth - 60),
          top: screenHeight * 0.5 + 20,
          child: _splitLabel('원본'),
        ),
      ],
    );
  }

  Widget _splitLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.black54, borderRadius: BorderRadius.circular(100)),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 11,
              fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildEffectRow(String label, IconData icon, double value,
      ValueChanged<double> onChanged, {ValueChanged<double>? onChangeEnd}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: value, min: 0.0, max: 1.0,
              onChanged: onChanged, onChangeEnd: onChangeEnd,
              activeColor: AppColors.accent, inactiveColor: Colors.white24,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text('${(value * 100).toInt()}%',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Map<String, double> _buildAdjustments() => {
    'exposure': _exposure,
    'contrast': _contrast,
    'highlights': _highlights,
    'shadows': _shadows,
    'saturation': _saturation,
    'temperature': _temperature,
    'tint': _tint,
    'sharpness': _sharpness,
    'fade': _fade,
    'vignette': _vignette,
    'skinTone': _skinTone,
  };

  Widget _buildEditPanel() => const SizedBox.shrink(); // 미사용 (호환성용)

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged, {ValueChanged<double>? onChangeEnd}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: AppTypography.filterName.copyWith(color: Colors.white70)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: value, min: min, max: max,
                onChanged: onChanged, onChangeEnd: onChangeEnd,
                activeColor: AppColors.accent, inactiveColor: Colors.white24,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              value >= 0 ? '+${(value * 100).toInt()}' : '${(value * 100).toInt()}',
              style: AppTypography.caption.copyWith(color: Colors.white60),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _saveImage() async {
    if (widget.imagePath == null) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('저장 중...'), backgroundColor: AppColors.darkSurface,
      behavior: SnackBarBehavior.floating, duration: Duration(seconds: 10),
    ));
    try {
      final camera = ref.read(cameraProvider);
      final outputPath = await FilterEngine.processImage(
        sourcePath: widget.imagePath!,
        lutFileName: _editorNoFilter ? '' : (camera.activeFilter?.lutFileName ?? ''),
        intensity: _editorNoFilter ? 0.0 : camera.filterIntensity,
        adjustments: _buildAdjustments(),
        effects: {'filmGrain': _filmGrain, 'dreamyGlow': _dreamyGlow, 'beauty': _beauty},
        saveToGallery: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (outputPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('갤러리에 저장되었습니다'), backgroundColor: AppColors.darkSurface,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('저장에 실패했습니다'), backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('오류: $e'), backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}
