import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../native_plugins/filter_engine/filter_engine.dart';
import '../../camera/presentation/widgets/filter_scroll_bar.dart';
import '../../camera/providers/camera_provider.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.imagePath, this.assetId});
  final String? imagePath;
  final String? assetId; // 갤러리 삭제용 (nullable)

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  // 기본 조정값
  double _exposure = 0;
  double _contrast = 0;
  double _highlights = 0;
  double _shadows = 0;
  double _saturation = 0;
  double _temperature = 0;
  double _tint = 0;
  double _sharpness = 0;
  double _fade = 0;
  double _vignette = 0;
  double _skinTone = 0;
  // 이펙트
  double _beauty = 0;
  double _dreamyGlow = 0;
  double _lightLeak = 0;
  double _filmGrain = 0;

  bool _editorNoFilter = true;
  String? _filteredPreviewPath;
  bool _isGeneratingPreview = false;

  double _splitPosition = 0.5;

  // 하단 탭: 'filter' | 'effect'
  String _activeTab = 'effect';

  // 효과 탭 선택된 파라미터 인덱스
  int _activeParamIndex = 0;

  // 효과 파라미터 목록
  static const _params = [
    (label: '밝기',  icon: Icons.wb_sunny_outlined,               min: -1.0, max: 1.0),
    (label: '대비',  icon: Icons.contrast,                         min: -1.0, max: 1.0),
    (label: '채도',  icon: Icons.palette_outlined,                 min: -1.0, max: 1.0),
    (label: '솜결',  icon: Icons.face_retouching_natural_rounded,  min: 0.0,  max: 1.0),
    (label: '뽀얀',  icon: Icons.blur_circular_rounded,            min: 0.0,  max: 1.0),
    (label: '글로우', icon: Icons.flare_rounded,                    min: 0.0,  max: 1.0),
  ];

  double _getParamValue(int i) {
    switch (i) {
      case 0: return _exposure;
      case 1: return _contrast;
      case 2: return _saturation;
      case 3: return _beauty;
      case 4: return _fade;
      case 5: return _dreamyGlow;
      default: return 0;
    }
  }

  String _formatValue(int i) {
    final v = _getParamValue(i);
    final n = (v * 100).round();
    return n >= 0 ? '+$n' : '$n';
  }

  bool get _hasChanges =>
      _exposure != 0 || _contrast != 0 || _saturation != 0 || _beauty != 0 ||
      _dreamyGlow != 0 || _lightLeak != 0 || _filmGrain != 0 ||
      _highlights != 0 || _shadows != 0 || _temperature != 0 ||
      _tint != 0 || _sharpness != 0 || _fade != 0 || _vignette != 0 || _skinTone != 0;

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    ref.listen(cameraProvider, (prev, next) {
      final prevId = prev?.activeFilter?.id;
      final nextId = next.activeFilter?.id;
      if (prevId != nextId) {
        if (nextId == null) {
          setState(() { _editorNoFilter = true; _filteredPreviewPath = null; });
        } else {
          setState(() => _editorNoFilter = false);
          _generatePreview();
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _buildImageSection(),
                  ),
                ),
                if (_activeTab == 'effect') ...[
                  _buildEffectRow(),
                  _buildTickSlider(),
                  const SizedBox(height: 4),
                ] else
                  _buildFilterSection(),
                _buildBottomTabBar(),
              ],
            ),
            if (_isGeneratingPreview)
              const IgnorePointer(
                child: ColoredBox(
                  color: Colors.black12,
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

  Widget _buildTopBar() {
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
          if (widget.assetId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFF3D3531), size: 22),
              onPressed: _deletePhoto,
            ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _saveImage,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0EC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE0DAD4), width: 0.5),
              ),
              child: const Icon(Icons.download_rounded,
                  color: Color(0xFF3D3531), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - 이미지 섹션 (Before/After 스플릿)

  Widget _buildImageSection() {
    if (widget.imagePath == null) {
      return const Center(
        child: Icon(Icons.add_photo_alternate_outlined,
            color: Colors.black26, size: 64),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GestureDetector(
        onHorizontalDragUpdate: (d) {
          final w = MediaQuery.sizeOf(context).width - 32;
          setState(() {
            _splitPosition = (_splitPosition + d.delta.dx / w).clamp(0.05, 0.95);
          });
        },
        child: LayoutBuilder(
          builder: (ctx, constraints) =>
              _buildSplitView(constraints.maxWidth, constraints.maxHeight),
        ),
      ),
    );
  }

  Widget _buildSplitView(double w, double h) {
    final original = widget.imagePath!;
    final filtered = _filteredPreviewPath ?? original;
    final lineX = w * _splitPosition;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
        // 오른쪽 (After = 필터 적용)
        Positioned.fill(
          child: Image.file(File(filtered), fit: BoxFit.cover),
        ),
        // 왼쪽 (Before = 원본)
        ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: _splitPosition,
            child: SizedBox(
              width: w,
              height: h,
              child: Image.file(File(original), fit: BoxFit.cover),
            ),
          ),
        ),
        // 분할선
        Positioned(
          left: lineX - 1, top: 0, bottom: 0,
          child: Container(
            width: 2,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        // 핸들
        Positioned(
          left: lineX - 14,
          top: h / 2 - 14,
          child: Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.compare_arrows_rounded,
                color: Colors.black54, size: 16),
          ),
        ),
        // Before 라벨 (분할선 왼쪽)
        Positioned(
          right: (w - lineX + 8).clamp(8.0, w - 8),
          top: h / 2 + 18,
          child: _splitLabel('Before'),
        ),
        // After 라벨 (분할선 오른쪽)
        Positioned(
          left: (lineX + 8).clamp(8.0, w - 56),
          top: h / 2 + 18,
          child: _splitLabel('After'),
        ),
        ],
      ),
    );
  }

  Widget _splitLabel(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(text,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
  );

  // MARK: - 효과 파라미터 행

  Widget _buildEffectRow() {
    return SizedBox(
      height: 68,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_params.length, (i) {
          final isActive = i == _activeParamIndex;
          final param = _params[i];
          return GestureDetector(
            onTap: () => setState(() => _activeParamIndex = i),
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
                          _formatValue(i),
                          style: const TextStyle(
                            color: Color(0xFFB06878),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : Icon(param.icon,
                        color: const Color(0xFF8A8480), size: 20),
                const SizedBox(height: 4),
                Text(
                  param.label,
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
    );
  }

  // MARK: - 틱 슬라이더

  Widget _buildTickSlider() {
    final param = _params[_activeParamIndex];
    final value = _getParamValue(_activeParamIndex);
    return Padding(
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
          value: value,
          min: param.min,
          max: param.max,
          divisions: 200,
          onChanged: (v) {
            setState(() => _setParamValueDirectly(_activeParamIndex, v));
          },
          onChangeEnd: (_) => _generatePreview(),
        ),
      ),
    );
  }

  void _setParamValueDirectly(int i, double v) {
    switch (i) {
      case 0: _exposure = v;
      case 1: _contrast = v;
      case 2: _saturation = v;
      case 3: _beauty = v;
      case 4: _fade = v;
      case 5: _dreamyGlow = v;
    }
  }

  // MARK: - 필터 섹션

  Widget _buildFilterSection() {
    return SizedBox(
      height: 116,
      child: FilterScrollBar(
        isNoFilterSelected: _editorNoFilter,
        onNoFilterSelected: () {
          ref.read(cameraProvider.notifier).clearFilter();
          setState(() {
            _editorNoFilter = true;
            _filteredPreviewPath = null;
          });
        },
      ),
    );
  }

  // MARK: - 하단 탭 바

  Widget _buildBottomTabBar() {
    final hasFilterChange = !_editorNoFilter;
    final hasEffectChange = _hasChanges;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      decoration: const BoxDecoration(
        border: Border(
            top: BorderSide(color: Color(0xFFEDE8E4), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTab('필터', Icons.auto_awesome_rounded, 'filter',
              hasDot: hasFilterChange),
          _buildTab('효과', Icons.flare_rounded, 'effect',
              hasDot: hasEffectChange),
        ],
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, String tabId,
      {bool hasDot = false}) {
    final isActive = _activeTab == tabId;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tabId),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                    )),
              ],
            ),
          ),
          if (hasDot)
            Positioned(
              top: -2,
              right: 16,
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

  // MARK: - 프리뷰 생성

  Future<void> _generatePreview() async {
    if (widget.imagePath == null || _isGeneratingPreview) return;

    final camera = ref.read(cameraProvider);
    final hasFilter = !_editorNoFilter && camera.activeFilter != null;
    if (!hasFilter && !_hasChanges) {
      setState(() => _filteredPreviewPath = null);
      return;
    }

    setState(() => _isGeneratingPreview = true);
    final path = await FilterEngine.processImage(
      sourcePath: widget.imagePath!,
      lutFileName:
          _editorNoFilter ? '' : (camera.activeFilter?.lutFileName ?? ''),
      intensity: _editorNoFilter ? 0.0 : camera.filterIntensity,
      adjustments: {
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
      },
      effects: {
        'filmGrain': _filmGrain,
        'dreamyGlow': _dreamyGlow,
        'beauty': _beauty,
        'lightLeak': _lightLeak,
      },
    );
    if (mounted) {
      setState(() {
        _filteredPreviewPath = path;
        _isGeneratingPreview = false;
      });
    }
  }

  // MARK: - 저장

  Future<void> _saveImage() async {
    if (widget.imagePath == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('저장 중...'),
      backgroundColor: Color(0xFF3D3531),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 10),
    ));
    try {
      final camera = ref.read(cameraProvider);
      final outputPath = await FilterEngine.processImage(
        sourcePath: widget.imagePath!,
        lutFileName:
            _editorNoFilter ? '' : (camera.activeFilter?.lutFileName ?? ''),
        intensity: _editorNoFilter ? 0.0 : camera.filterIntensity,
        adjustments: {
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
        },
        effects: {
          'filmGrain': _filmGrain,
          'dreamyGlow': _dreamyGlow,
          'beauty': _beauty,
          'lightLeak': _lightLeak,
        },
        saveToGallery: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (outputPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('갤러리에 저장되었습니다'),
          backgroundColor: Color(0xFF3D3531),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('저장에 실패했습니다'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('오류: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // MARK: - 삭제

  Future<void> _deletePhoto() async {
    if (widget.imagePath == null || widget.assetId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('사진 삭제',
            style: TextStyle(
                color: Color(0xFF3D3531),
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        content: const Text('갤러리에서 이 사진을 삭제할까요?',
            style: TextStyle(color: Color(0xFF8A8480), fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소',
                style: TextStyle(color: Color(0xFF8A8480))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await PhotoManager.editor.deleteWithIds([widget.assetId!]);
    if (mounted) Navigator.of(context).pop();
  }
}
