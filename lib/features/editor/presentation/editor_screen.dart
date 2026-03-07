import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/theme/liquid_glass_decoration.dart';
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

class _EditorScreenState extends ConsumerState<EditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  double _exposure = 0;
  double _contrast = 0;
  double _warmth = 0;
  double _saturation = 0;
  double _grain = 0;
  double _fade = 0;
  double _dreamyGlow = 0;
  double _filmGrain = 0;
  double _beauty = 0;

  // 기본 "효과 없음" 상태 — 찍은 사진에 이미 필터가 베이크되어 있으므로
  bool _editorNoFilter = true;

  String? _filteredPreviewPath;
  bool _isGeneratingPreview = false;
  bool _showSplitView = false;
  double _splitPosition = 0.5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 자동 preview 생성 없음: 찍은 사진에 이미 필터가 적용되어 있음
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _hasAdjustments() =>
      _exposure != 0 || _contrast != 0 || _warmth != 0 ||
      _saturation != 0 || _grain != 0 || _fade != 0;

  bool _hasEffects() => _dreamyGlow != 0 || _filmGrain != 0 || _beauty != 0;

  void _resetAdjustments() {
    setState(() {
      _exposure = 0; _contrast = 0; _warmth = 0;
      _saturation = 0; _grain = 0; _fade = 0;
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
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(flex: 5, child: _buildImagePreview()),
            Expanded(flex: 4, child: _buildEditPanel()),
          ],
        ),
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
      adjustments: {
        'exposure': _exposure, 'contrast': _contrast,
        'warmth': _warmth, 'saturation': _saturation, 'fade': _fade,
      },
      effects: {'filmGrain': _filmGrain, 'dreamyGlow': _dreamyGlow, 'beauty': _beauty},
    );
    if (mounted) {
      setState(() { _filteredPreviewPath = path; _isGeneratingPreview = false; });
    }
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
          ),
          const Spacer(),
          Text('Edit', style: AppTypography.h2.copyWith(color: Colors.white)),
          const Spacer(),
          GestureDetector(
            onTap: _saveImage,
            child: LiquidGlassPill(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text('Save',
                  style: TextStyle(color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onLongPressStart: (_) => setState(() => _showSplitView = true),
      onLongPressEnd: (_) => setState(() => _showSplitView = false),
      onHorizontalDragUpdate: (details) {
        if (_showSplitView) {
          final width = MediaQuery.of(context).size.width;
          setState(() {
            _splitPosition = (details.globalPosition.dx / width).clamp(0.0, 1.0);
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          child: widget.imagePath != null
              ? _showSplitView ? _buildSplitView() : _buildMainPreview()
              : const Center(
                  child: Icon(Icons.add_photo_alternate_outlined,
                      color: Colors.white38, size: 48)),
        ),
      ),
    );
  }

  Widget _buildMainPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          key: ValueKey(_filteredPreviewPath ?? widget.imagePath!),
          File(_filteredPreviewPath ?? widget.imagePath!),
          fit: BoxFit.cover, width: double.infinity,
        ),
        if (_isGeneratingPreview)
          const ColoredBox(
            color: Colors.black26,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildSplitView() {
    final filtered = _filteredPreviewPath ?? widget.imagePath!;
    return Stack(
      children: [
        SizedBox.expand(child: Image.file(File(filtered), fit: BoxFit.cover)),
        ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: _splitPosition,
            child: Image.file(File(widget.imagePath!), fit: BoxFit.cover,
                width: MediaQuery.of(context).size.width),
          ),
        ),
        Positioned(
          left: MediaQuery.of(context).size.width * _splitPosition - 1,
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
        Positioned(
          top: 12, left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.black45, borderRadius: BorderRadius.circular(100)),
            child: const Text('원본',
                style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Widget _buildEditPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              const Tab(text: '필터'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('조정'),
                    if (_hasAdjustments()) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _resetAdjustments,
                        child: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.accent),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('이펙트'),
                    if (_hasEffects()) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _resetEffects,
                        child: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.accent),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            labelStyle: AppTypography.filterName,
            indicatorColor: AppColors.accent,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            dividerColor: Colors.transparent,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
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
                _buildAdjustmentSliders(),
                _buildEffectPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentSliders() {
    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
      children: [
        _buildSlider('Exposure', _exposure, -1.0, 1.0,
            (v) => setState(() => _exposure = v),
            onChangeEnd: (_) => _generatePreview()),
        _buildSlider('Contrast', _contrast, -1.0, 1.0,
            (v) => setState(() => _contrast = v),
            onChangeEnd: (_) => _generatePreview()),
        _buildSlider('Warmth', _warmth, -1.0, 1.0,
            (v) => setState(() => _warmth = v),
            onChangeEnd: (_) => _generatePreview()),
        _buildSlider('Saturation', _saturation, -1.0, 1.0,
            (v) => setState(() => _saturation = v),
            onChangeEnd: (_) => _generatePreview()),
        _buildSlider('Grain', _grain, 0.0, 1.0,
            (v) => setState(() => _grain = v),
            onChangeEnd: (_) => _generatePreview()),
        _buildSlider('Fade', _fade, 0.0, 1.0,
            (v) => setState(() => _fade = v),
            onChangeEnd: (_) => _generatePreview()),
      ],
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

  Widget _buildEffectPanel() {
    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
      children: [
        _buildEffectTile(
          icon: Icons.flare_rounded, label: 'Dreamy Glow', description: '몽환적인 빛번짐',
          value: _dreamyGlow, onChanged: (v) => setState(() => _dreamyGlow = v),
          onChangeEnd: (_) => _generatePreview(),
        ),
        const SizedBox(height: 8),
        _buildEffectTile(
          icon: Icons.grain_rounded, label: 'Film Grain', description: '필름 노이즈 텍스처',
          value: _filmGrain, onChanged: (v) => setState(() => _filmGrain = v),
          onChangeEnd: (_) => _generatePreview(),
        ),
        const SizedBox(height: 8),
        _buildEffectTile(
          icon: Icons.face_retouching_natural_rounded, label: 'Beauty', description: '뽀샤시 피부 보정',
          value: _beauty, onChanged: (v) => setState(() => _beauty = v),
          onChangeEnd: (_) => _generatePreview(),
        ),
      ],
    );
  }

  Widget _buildEffectTile({
    required IconData icon, required String label, required String description,
    required double value, required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.darkBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.filterName.copyWith(color: Colors.white)),
                  Text(description, style: AppTypography.caption),
                ],
              ),
              const Spacer(),
              Text('${(value * 100).toInt()}%',
                  style: AppTypography.caption.copyWith(color: Colors.white60)),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value, min: 0.0, max: 1.0,
              onChanged: onChanged, onChangeEnd: onChangeEnd,
              activeColor: AppColors.accent, inactiveColor: Colors.white24,
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
        adjustments: {
          'exposure': _exposure, 'contrast': _contrast,
          'warmth': _warmth, 'saturation': _saturation, 'fade': _fade,
        },
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
