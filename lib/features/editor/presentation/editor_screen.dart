import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/filter_model.dart';
import '../../../core/theme/liquid_glass_decoration.dart';
import '../../../native_plugins/filter_engine/filter_engine.dart';
import '../../camera/presentation/widgets/filter_scroll_bar.dart';

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

  FilterModel? _selectedFilter;
  double _filterIntensity = 1.0;

  // 조정 슬라이더 값
  double _exposure = 0;
  double _contrast = 0;
  double _warmth = 0;
  double _saturation = 0;
  double _grain = 0;
  double _fade = 0;

  // 이펙트 값
  double _dreamyGlow = 0;
  double _filmGrain = 0;

  // Before/After Split View
  bool _showSplitView = false;
  double _splitPosition = 0.5; // 0.0 ~ 1.0

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedFilter = FilterData.all.first;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 네비게이션
            _buildTopBar(),

            // 이미지 프리뷰 (16:9 비율)
            Expanded(
              flex: 5,
              child: _buildImagePreview(),
            ),

            // 하단 편집 도구
            Expanded(
              flex: 4,
              child: _buildEditPanel(),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - 상단 바

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
          ),
          const Spacer(),
          Text(
            'Edit',
            style: AppTypography.h2.copyWith(color: Colors.white),
          ),
          const Spacer(),
          // 저장 버튼
          GestureDetector(
            onTap: _saveImage,
            child: LiquidGlassPill(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - 이미지 프리뷰

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
              ? _showSplitView
                  ? _buildSplitView()
                  : Image.file(
                      File(widget.imagePath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
              : const Center(
                  child: Icon(Icons.add_photo_alternate_outlined,
                      color: Colors.white38, size: 48),
                ),
        ),
      ),
    );
  }

  /// [추가 아이디어 5] Split-View Before/After 드래그 비교
  Widget _buildSplitView() {
    return Stack(
      children: [
        // After (필터 적용)
        SizedBox.expand(
          child: Image.file(File(widget.imagePath!), fit: BoxFit.cover),
        ),
        // Before (원본) — 분할선 왼쪽
        ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: _splitPosition,
            child: Image.file(File(widget.imagePath!), fit: BoxFit.cover,
                width: MediaQuery.of(context).size.width),
          ),
        ),
        // 분할선
        Positioned(
          left: MediaQuery.of(context).size.width * _splitPosition - 1,
          top: 0,
          bottom: 0,
          child: Container(
            width: 2,
            color: Colors.white,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.compare_arrows_rounded,
                    color: AppColors.textPrimary, size: 16),
              ),
            ),
          ),
        ),
        // 레이블
        Positioned(
          top: 12,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Text('원본', style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ),
      ],
    );
  }

  // MARK: - 편집 패널

  Widget _buildEditPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 탭 바 (필터 / 조정 / 이펙트)
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '필터'),
              Tab(text: '조정'),
              Tab(text: '이펙트'),
            ],
            labelStyle: AppTypography.filterName,
            indicatorColor: AppColors.accent,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            dividerColor: Colors.transparent,
          ),
          // 탭 콘텐츠
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 필터 탭 — 동일한 필터 스크롤 바
                const FilterScrollBar(),
                // 조정 탭 — 슬라이더 패널
                _buildAdjustmentSliders(),
                // 이펙트 탭
                _buildEffectPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - 조정 슬라이더 (Exposure, Contrast, Warmth, Saturation, Grain, Fade)

  Widget _buildAdjustmentSliders() {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      children: [
        _buildSlider('Exposure', _exposure, -1.0, 1.0, (v) => setState(() => _exposure = v)),
        _buildSlider('Contrast', _contrast, -1.0, 1.0, (v) => setState(() => _contrast = v)),
        _buildSlider('Warmth', _warmth, -1.0, 1.0, (v) => setState(() => _warmth = v)),
        _buildSlider('Saturation', _saturation, -1.0, 1.0, (v) => setState(() => _saturation = v)),
        _buildSlider('Grain', _grain, 0.0, 1.0, (v) => setState(() => _grain = v)),
        _buildSlider('Fade', _fade, 0.0, 1.0, (v) => setState(() => _fade = v)),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.filterName.copyWith(color: Colors.white70),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
                activeColor: AppColors.accent,
                inactiveColor: Colors.white24,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              value >= 0
                  ? '+${(value * 100).toInt()}'
                  : '${(value * 100).toInt()}',
              style: AppTypography.caption.copyWith(color: Colors.white60),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - 이펙트 패널

  Widget _buildEffectPanel() {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      children: [
        _buildEffectTile(
          icon: Icons.flare_rounded,
          label: 'Dreamy Glow',
          description: '몽환적인 빛번짐',
          value: _dreamyGlow,
          onChanged: (v) => setState(() => _dreamyGlow = v),
        ),
        const SizedBox(height: 8),
        _buildEffectTile(
          icon: Icons.grain_rounded,
          label: 'Film Grain',
          description: '필름 노이즈 텍스처',
          value: _filmGrain,
          onChanged: (v) => setState(() => _filmGrain = v),
        ),
      ],
    );
  }

  Widget _buildEffectTile({
    required IconData icon,
    required String label,
    required String description,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(12),
      ),
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
                  Text(label, style: AppTypography.filterName.copyWith(color: Colors.white)),
                  Text(description, style: AppTypography.caption),
                ],
              ),
              const Spacer(),
              Text(
                '${(value * 100).toInt()}%',
                style: AppTypography.caption.copyWith(color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value,
              min: 0.0,
              max: 1.0,
              onChanged: onChanged,
              activeColor: AppColors.accent,
              inactiveColor: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - 저장

  Future<void> _saveImage() async {
    if (widget.imagePath == null) return;

    // 저장 중 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('저장 중...'),
        backgroundColor: AppColors.darkSurface,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 10),
      ),
    );

    try {
      final outputPath = await FilterEngine.processImage(
        sourcePath: widget.imagePath!,
        lutFileName: _selectedFilter?.lutFileName ?? 'milk.cube',
        intensity: _filterIntensity,
        adjustments: {
          'exposure': _exposure,
          'contrast': _contrast,
          'warmth': _warmth,
          'saturation': _saturation,
          'fade': _fade,
        },
        effects: {
          'filmGrain': _filmGrain,
          'dreamyGlow': _dreamyGlow,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (outputPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('갤러리에 저장되었습니다'),
            backgroundColor: AppColors.darkSurface,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장에 실패했습니다'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
