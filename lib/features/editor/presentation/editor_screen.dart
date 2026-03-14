import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import '../../gallery/presentation/video_player_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../native_plugins/filter_engine/filter_engine.dart';
import '../../camera/presentation/widgets/filter_scroll_bar.dart';
import '../../camera/providers/camera_provider.dart';

enum _CropHandle { tl, tr, bl, br }

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    this.imagePath,
    this.assetId,
    this.assets,
    this.currentIndex = 0,
  });
  final String? imagePath;
  final String? assetId; // 갤러리 삭제용 (nullable)
  final List<AssetEntity>? assets;
  final int currentIndex;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  // 공유 버튼 위치 (iOS sharePositionOrigin)
  final _shareButtonKey = GlobalKey();

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
  ProviderSubscription<dynamic>? _filterSubscription;

  // 인접 에셋 스와이프 내비게이션
  bool _isNavigating = false;

  // 실시간 이미지 프리뷰 텍스처
  int? _imageTextureId;
  int _imageTextureW = 1;
  int _imageTextureH = 1;

  // 하단 탭: 'filter' | 'effect' | 'crop'
  String _activeTab = 'effect';

  // 자르기
  String? _croppedSourcePath;
  Size? _sourceImageSize;
  Rect _cropNorm = const Rect.fromLTRB(0, 0, 1, 1);
  int _aspectIndex = 0;
  _CropHandle? _activeCropHandle;
  bool _draggingCropInterior = false;
  Offset? _cropDragStart;
  Rect? _cropDragStartNorm;

  static const _aspectRatios = [
    null as double?,
    1.0,
    4.0 / 5,
    9.0 / 16,
    3.0 / 4,
    16.0 / 9,
    4.0 / 3,
  ];

  List<String> _aspectLabels(AppLocalizations l10n) => [
    l10n.freeform, l10n.square, '4:5', '9:16', '3:4', '16:9', '4:3',
  ];

  // 효과 탭 선택된 파라미터 인덱스
  int _activeParamIndex = 0;

  // 효과 파라미터 목록 (label 제거 → _paramLabel로 현지화)
  static const _params = [
    (icon: Icons.face_retouching_natural_rounded, min: 0.0,  max: 1.0),
    (icon: Icons.blur_circular_rounded,           min: 0.0,  max: 1.0),
    (icon: Icons.wb_sunny_outlined,               min: -1.0, max: 1.0),
    (icon: Icons.contrast,                        min: -1.0, max: 1.0),
    (icon: Icons.palette_outlined,                min: -1.0, max: 1.0),
    (icon: Icons.flare_rounded,                   min: 0.0,  max: 1.0),
  ];

  String _paramLabel(int i, AppLocalizations l10n) {
    switch (i) {
      case 0: return l10n.softness;
      case 1: return l10n.beauty;
      case 2: return l10n.brightness;
      case 3: return l10n.contrast;
      case 4: return l10n.saturation;
      case 5: return l10n.glow;
      default: return '';
    }
  }

  double _getParamValue(int i) {
    switch (i) {
      case 0: return _beauty;
      case 1: return _fade;
      case 2: return _exposure;
      case 3: return _contrast;
      case 4: return _saturation;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initImagePreview());
    _filterSubscription = ref.listenManual(cameraProvider, (prev, next) {
      final prevId = prev?.activeFilter?.id;
      final nextId = next.activeFilter?.id;
      if (prevId != nextId) {
        if (nextId == null) {
          setState(() => _editorNoFilter = true);
        } else {
          setState(() => _editorNoFilter = false);
        }
        _updateImagePreview();
      }
    });
  }

  @override
  void dispose() {
    _filterSubscription?.close();
    FilterEngine.disposeImagePreview();
    super.dispose();
  }

  // MARK: - 이미지 프리뷰 텍스처

  Future<void> _initImagePreview() async {
    if (widget.imagePath == null) return;
    await FilterEngine.disposeImagePreview();
    final cam = ref.read(cameraProvider);
    final result = await FilterEngine.initImagePreview(
      sourcePath: _effectiveSourcePath,
      lutFileName: _editorNoFilter ? '' : (cam.activeFilter?.lutFileName ?? ''),
      intensity: _editorNoFilter ? 0.0 : cam.filterIntensity,
      adjustments: _adjustmentsMap,
      effects: _effectsMap,
    );
    if (!mounted || result == null) return;
    setState(() {
      _imageTextureId = result['textureId'] as int?;
      _imageTextureW  = result['width']     as int? ?? 1;
      _imageTextureH  = result['height']    as int? ?? 1;
    });
  }

  void _updateImagePreview() {
    if (_imageTextureId == null) return;
    final cam = ref.read(cameraProvider);
    FilterEngine.updateImagePreview(
      lutFileName: _editorNoFilter ? '' : (cam.activeFilter?.lutFileName ?? ''),
      intensity: _editorNoFilter ? 0.0 : cam.filterIntensity,
      adjustments: _adjustmentsMap,
      effects: _effectsMap,
    );
  }

  // MARK: - 스와이프 내비게이션

  Future<void> _goToAdjacent(int delta) async {
    final assets = widget.assets;
    if (assets == null || _isNavigating) return;
    final newIdx = widget.currentIndex + delta;
    if (newIdx < 0 || newIdx >= assets.length) return;

    setState(() => _isNavigating = true);
    final asset = assets[newIdx];
    final file = await asset.file;
    if (!mounted || file == null) {
      if (mounted) setState(() => _isNavigating = false);
      return;
    }

    final isForward = delta > 0;
    final Widget nextScreen = asset.type == AssetType.video
        ? VideoPlayerScreen(
            videoPath: file.path,
            assetId: asset.id,
            assets: assets,
            currentIndex: newIdx,
          )
        : EditorScreen(
            imagePath: file.path,
            assetId: asset.id,
            assets: assets,
            currentIndex: newIdx,
          );

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, a1, a2) => nextScreen,
        transitionsBuilder: (context, anim, a2, child) => SlideTransition(
          position: Tween<Offset>(
            begin: Offset(isForward ? 1 : -1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
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
                    child: _activeTab == 'crop' || widget.assets == null
                        ? _buildImageSection()
                        : GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragEnd: (d) {
                              final v = d.primaryVelocity ?? 0;
                              if (v < -500) { _goToAdjacent(1); }
                              else if (v > 500) { _goToAdjacent(-1); }
                            },
                            child: _buildImageSection(),
                          ),
                  ),
                ),
                SizedBox(
                  height: 152,
                  child: _activeTab == 'effect'
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildEffectRow(),
                            _buildTickSlider(),
                            const SizedBox(height: 4),
                          ],
                        )
                      : _activeTab == 'crop'
                          ? _buildCropSection()
                          : _buildFilterSection(),
                ),
                _buildBottomTabBar(),
              ],
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
          // 전체 초기화 버튼 (필터 + 효과)
          if (!_editorNoFilter || _hasChanges) ...[
            GestureDetector(
              onTap: () {
                ref.read(cameraProvider.notifier).clearFilter();
                setState(() {
                  _editorNoFilter = true;
                  _exposure = 0; _contrast = 0; _saturation = 0;
                  _beauty = 0; _fade = 0; _dreamyGlow = 0;
                  _lightLeak = 0; _filmGrain = 0;
                  _highlights = 0; _shadows = 0; _temperature = 0;
                  _tint = 0; _sharpness = 0; _vignette = 0; _skinTone = 0;
                });
                _updateImagePreview();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F2EF),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFFE0DAD4), width: 0.5),
                ),
                child: Text(AppLocalizations.of(context).reset,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8A8480), fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.assetId != null) ...[
            GestureDetector(
              onTap: _deletePhoto,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0EC),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE0DAD4), width: 0.5),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // 공유 버튼
          GestureDetector(
            key: _shareButtonKey,
            onTap: _shareImage,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0EC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE0DAD4), width: 0.5),
              ),
              child: const Icon(Icons.ios_share_rounded,
                  color: Color(0xFF3D3531), size: 18),
            ),
          ),
          const SizedBox(width: 8),
          // 저장 버튼
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
    final displayPath = _croppedSourcePath ?? widget.imagePath!;
    return Stack(
      children: [
        // 배경: 사진이 contain으로 letterbox될 때 보이는 영역
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: const ColoredBox(color: Color(0xFFF5F2EF)),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: _imageTextureId != null && _activeTab != 'crop'
              // 실시간 텍스처 프리뷰 (효과 탭 / 필터 탭)
              ? FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _imageTextureW.toDouble(),
                    height: _imageTextureH.toDouble(),
                    child: Texture(textureId: _imageTextureId!),
                  ),
                )
              // 자르기 탭 or 텍스처 초기화 전: 파일 기반 표시
              : Image.file(
                  File(displayPath),
                  key: ValueKey(displayPath),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
        ),
        // 자르기 오버레이
        if (_activeTab == 'crop')
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _buildCropOverlay(),
            ),
          ),
      ],
    );
  }

  // MARK: - 효과 파라미터 행

  Widget _buildEffectRow() {
    final l10n = AppLocalizations.of(context);
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFADDE6),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  _formatValue(i),
                                  style: const TextStyle(
                                    color: Color(0xFFB06878),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : Icon(param.icon,
                                color: const Color(0xFF8A8480), size: 20),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _paramLabel(i, l10n),
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
              ),
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
            setState(() => _setParamValueDirectly(_activeParamIndex, v));
            _updateImagePreview();
          },
        ),
      ),
    );
  }

  void _setParamValueDirectly(int i, double v) {
    switch (i) {
      case 0: _beauty = v;
      case 1: _fade = v;
      case 2: _exposure = v;
      case 3: _contrast = v;
      case 4: _saturation = v;
      case 5: _dreamyGlow = v;
    }
  }

  // MARK: - 필터 섹션

  Widget _buildFilterSection() {
    final camera = ref.watch(cameraProvider);
    final intensity = _editorNoFilter ? 1.0 : camera.filterIntensity;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 100,
          child: FilterScrollBar(
            isNoFilterSelected: _editorNoFilter,
            onNoFilterSelected: () {
              ref.read(cameraProvider.notifier).clearFilter();
              setState(() => _editorNoFilter = true);
              _updateImagePreview();
            },
          ),
        ),
        if (!_editorNoFilter) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
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
                        _updateImagePreview();
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${(intensity * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A8480),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ] else
          const SizedBox(height: 36),
      ],
    );
  }

  // MARK: - 자르기

  Widget _buildCropOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widgetW = constraints.maxWidth;
        final widgetH = constraints.maxHeight;
        final imgSize = _sourceImageSize ?? const Size(1, 1);
        final imgAspect = imgSize.width / imgSize.height;
        final widgetAspect = widgetW / widgetH;

        late final double iW, iH, iX, iY;
        if (imgAspect > widgetAspect) {
          iW = widgetW; iH = widgetW / imgAspect;
        } else {
          iH = widgetH; iW = widgetH * imgAspect;
        }
        iX = (widgetW - iW) / 2;
        iY = (widgetH - iH) / 2;

        final cx = iX + _cropNorm.left * iW;
        final cy = iY + _cropNorm.top * iH;
        final cw = _cropNorm.width * iW;
        final ch = _cropNorm.height * iH;
        final cropDisplay = Rect.fromLTWH(cx, cy, cw, ch);

        return GestureDetector(
          onPanStart: (d) {
            final pos = d.localPosition;
            const r = 24.0;
            _CropHandle? hit;
            if ((pos - cropDisplay.topLeft).distance < r) {
              hit = _CropHandle.tl;
            } else if ((pos - cropDisplay.topRight).distance < r) {
              hit = _CropHandle.tr;
            } else if ((pos - cropDisplay.bottomLeft).distance < r) {
              hit = _CropHandle.bl;
            } else if ((pos - cropDisplay.bottomRight).distance < r) {
              hit = _CropHandle.br;
            }

            _activeCropHandle = hit;
            _draggingCropInterior = hit == null && cropDisplay.contains(pos);
            _cropDragStart = pos;
            _cropDragStartNorm = _cropNorm;
          },
          onPanUpdate: (d) {
            if (_cropDragStart == null || _cropDragStartNorm == null) return;
            final delta = d.localPosition - _cropDragStart!;
            final dx = delta.dx / iW;
            final dy = delta.dy / iH;
            final startNorm = _cropDragStartNorm!;
            final ratio = _aspectRatios[_aspectIndex];

            setState(() {
              if (_draggingCropInterior) {
                final newL = (startNorm.left + dx).clamp(0.0, 1.0 - startNorm.width);
                final newT = (startNorm.top + dy).clamp(0.0, 1.0 - startNorm.height);
                _cropNorm = Rect.fromLTWH(newL, newT, startNorm.width, startNorm.height);
              } else if (_activeCropHandle != null) {
                double l = startNorm.left, t = startNorm.top;
                double r = startNorm.right, b = startNorm.bottom;
                switch (_activeCropHandle!) {
                  case _CropHandle.tl: l += dx; t += dy;
                  case _CropHandle.tr: r += dx; t += dy;
                  case _CropHandle.bl: l += dx; b += dy;
                  case _CropHandle.br: r += dx; b += dy;
                }
                l = l.clamp(0.0, r - 0.05);
                t = t.clamp(0.0, b - 0.05);
                r = r.clamp(l + 0.05, 1.0);
                b = b.clamp(t + 0.05, 1.0);
                if (ratio != null) {
                  // 비율 유지 (normRatio 기준)
                  final srcSize = _sourceImageSize ?? const Size(1, 1);
                  final normRatio = ratio / (srcSize.width / srcSize.height);
                  double nw = r - l, nh = b - t;
                  if (_activeCropHandle == _CropHandle.tl || _activeCropHandle == _CropHandle.br) {
                    nh = nw / normRatio;
                  } else {
                    nw = nh * normRatio;
                  }
                  switch (_activeCropHandle!) {
                    case _CropHandle.tl: t = b - nh; l = r - nw;
                    case _CropHandle.tr: t = b - nh; r = l + nw;
                    case _CropHandle.bl: b = t + nh; l = r - nw;
                    case _CropHandle.br: b = t + nh; r = l + nw;
                  }
                  l = l.clamp(0.0, 1.0); t = t.clamp(0.0, 1.0);
                  r = r.clamp(0.0, 1.0); b = b.clamp(0.0, 1.0);
                }
                _cropNorm = Rect.fromLTRB(l, t, r, b);
              }
            });
          },
          onPanEnd: (_) {
            _activeCropHandle = null;
            _draggingCropInterior = false;
            _cropDragStart = null;
            _cropDragStartNorm = null;
          },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: widgetW,
            height: widgetH,
            child: CustomPaint(
              painter: _CropPainter(cropDisplay, widgetW, widgetH),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCropSection() {
    final l10n = AppLocalizations.of(context);
    final aspectLabels = _aspectLabels(l10n);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 68,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _aspectRatios.length,
            itemBuilder: (context, i) {
              final ratio = _aspectRatios[i];
              final isActive = i == _aspectIndex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _aspectIndex = i;
                    if (ratio != null) {
                      final srcSize = _sourceImageSize ?? const Size(1, 1);
                      final imgAspect = srcSize.width / srcSize.height;
                      // normRatio: 정규화 공간에서의 가로/세로 비율
                      final normRatio = ratio / imgAspect;
                      final cx = (_cropNorm.left + _cropNorm.right) / 2;
                      final cy = (_cropNorm.top + _cropNorm.bottom) / 2;
                      // 이미지를 최대한 채우는 크기 계산
                      double nw, nh;
                      if (normRatio <= 1.0) {
                        nh = 1.0; nw = nh * normRatio;
                      } else {
                        nw = 1.0; nh = nw / normRatio;
                      }
                      final l = (cx - nw / 2).clamp(0.0, 1.0 - nw);
                      final t = (cy - nh / 2).clamp(0.0, 1.0 - nh);
                      _cropNorm = Rect.fromLTWH(l, t, nw, nh);
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF3D3531) : const Color(0xFFF5F2EF),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        aspectLabels[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : const Color(0xFF3D3531),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _cropNorm = const Rect.fromLTRB(0, 0, 1, 1);
                  _aspectIndex = 0;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F2EF),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(AppLocalizations.of(context).reset, style: const TextStyle(fontSize: 13, color: Color(0xFF8A8480), fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _applyCrop,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D3531),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(AppLocalizations.of(context).apply, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _applyCrop() async {
    final sourcePath = _croppedSourcePath ?? widget.imagePath;
    if (sourcePath == null) return;

    // 이미지 디코딩
    final bytes = await File(sourcePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    final srcRect = Rect.fromLTWH(
      _cropNorm.left * imgW,
      _cropNorm.top * imgH,
      _cropNorm.width * imgW,
      _cropNorm.height * imgH,
    );

    final outW = srcRect.width.round();
    final outH = srcRect.height.round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()));
    canvas.drawImageRect(image, srcRect, Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()), Paint());
    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(outW, outH);
    final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(path).writeAsBytes(byteData!.buffer.asUint8List());

    // 이미지 크기 업데이트
    if (mounted) {
      setState(() {
        _croppedSourcePath = path;
        _sourceImageSize = Size(outW.toDouble(), outH.toDouble());
        _cropNorm = const Rect.fromLTRB(0, 0, 1, 1);
        _aspectIndex = 0;
        _imageTextureId = null; // 텍스처 재초기화 대기
        _activeTab = 'effect';
      });
      _initImagePreview(); // 크롭된 소스로 텍스처 재초기화
    }
  }

  Future<void> _loadImageSize() async {
    final sourcePath = _croppedSourcePath ?? widget.imagePath;
    if (sourcePath == null || _sourceImageSize != null) return;
    final bytes = await File(sourcePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    if (mounted) {
      setState(() => _sourceImageSize = Size(image.width.toDouble(), image.height.toDouble()));
    }
  }

  // MARK: - 하단 탭 바

  Widget _buildBottomTabBar() {
    final hasFilterChange = !_editorNoFilter;
    final hasEffectChange = _hasChanges;
    final hasCropChange = _croppedSourcePath != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      decoration: const BoxDecoration(
        border: Border(
            top: BorderSide(color: Color(0xFFEDE8E4), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTab(AppLocalizations.of(context).filterTab, Icons.auto_awesome_rounded, 'filter',
              hasDot: hasFilterChange),
          _buildTab(AppLocalizations.of(context).effectTab, Icons.flare_rounded, 'effect',
              hasDot: hasEffectChange),
          _buildTab(AppLocalizations.of(context).cropTab, Icons.crop_rounded, 'crop',
              hasDot: hasCropChange),
        ],
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, String tabId,
      {bool hasDot = false}) {
    final isActive = _activeTab == tabId;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _activeTab = tabId);
        if (tabId == 'crop') _loadImageSize();
      },
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
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                    )),
              ],
            ),
          ),
          if (hasDot)
            Positioned(
              top: 6,
              right: 24,
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

  String get _effectiveSourcePath =>
      _croppedSourcePath ?? widget.imagePath ?? '';

  Map<String, double> get _adjustmentsMap => {
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

  Map<String, double> get _effectsMap => {
    'filmGrain': _filmGrain,
    'dreamyGlow': _dreamyGlow,
    'beauty': _beauty,
    'lightLeak': _lightLeak,
  };

  // MARK: - 저장

  Future<void> _saveImage() async {
    if (widget.imagePath == null) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.saving),
      backgroundColor: const Color(0xFF3D3531),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 10),
    ));
    try {
      final camera = ref.read(cameraProvider);
      final outputPath = await FilterEngine.processImage(
        sourcePath: _effectiveSourcePath,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.savedToGallery),
          backgroundColor: const Color(0xFF3D3531),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.saveFailed),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${AppLocalizations.of(context).saveFailed}: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // MARK: - 공유

  /// 공유 버튼의 화면 위치를 Rect로 반환 (iOS sharePositionOrigin 용)
  Rect? _shareOriginRect() {
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final pos = box.localToGlobal(Offset.zero);
    return pos & box.size;
  }

  Future<void> _shareImage() async {
    if (widget.imagePath == null) return;

    final camera = ref.read(cameraProvider);
    final hasFilter = !_editorNoFilter && camera.activeFilter != null;
    final origin = _shareOriginRect();

    try {
      // 변경 없음 — 원본(또는 크롭본) 바로 공유
      if (!hasFilter && !_hasChanges) {
        final src = _effectiveSourcePath;
        if (!File(src).existsSync()) {
          _showSnackBar(AppLocalizations.of(context).fileNotFound, isError: true);
          return;
        }
        await Share.shareXFiles(
          [XFile(src, mimeType: _mimeType(src))],
          sharePositionOrigin: origin,
        );
        return;
      }

      if (!mounted) return;
      _showSnackBar(AppLocalizations.of(context).preparingShare, duration: 30);

      final path = await FilterEngine.processImage(
        sourcePath: _effectiveSourcePath,
        lutFileName: _editorNoFilter ? '' : (camera.activeFilter?.lutFileName ?? ''),
        intensity: _editorNoFilter ? 0.0 : camera.filterIntensity,
        adjustments: {
          'exposure': _exposure, 'contrast': _contrast,
          'highlights': _highlights, 'shadows': _shadows,
          'saturation': _saturation, 'temperature': _temperature,
          'tint': _tint, 'sharpness': _sharpness,
          'fade': _fade, 'vignette': _vignette, 'skinTone': _skinTone,
        },
        effects: {
          'filmGrain': _filmGrain, 'dreamyGlow': _dreamyGlow,
          'beauty': _beauty, 'lightLeak': _lightLeak,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (path != null) {
        await Share.shareXFiles(
          [XFile(path, mimeType: _mimeType(path))],
          sharePositionOrigin: origin,
        );
      } else {
        _showSnackBar(AppLocalizations.of(context).shareFailed, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnackBar('${AppLocalizations.of(context).shareFailed}: $e', isError: true);
    }
  }

  String _mimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'heic': case 'heif': return 'image/heic';
      default: return 'image/jpeg';
    }
  }

  void _showSnackBar(String msg, {bool isError = false, int duration = 4}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : const Color(0xFF3D3531),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: duration),
    ));
  }

  // MARK: - 삭제

  Future<void> _deletePhoto() async {
    if (widget.imagePath == null || widget.assetId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(AppLocalizations.of(context).deletePhoto,
            style: const TextStyle(
                color: Color(0xFF3D3531),
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        content: Text(AppLocalizations.of(context).deletePhotoConfirm,
            style: const TextStyle(color: Color(0xFF8A8480), fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel,
                style: const TextStyle(color: Color(0xFF8A8480))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).delete,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await PhotoManager.editor.deleteWithIds([widget.assetId!]);
    if (mounted) Navigator.of(context).pop();
  }
}

class _CropPainter extends CustomPainter {
  final Rect cropRect;
  final double w;
  final double h;

  const _CropPainter(this.cropRect, this.w, this.h);

  @override
  void paint(Canvas canvas, Size size) {
    final maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    // 크롭 영역 바깥 마스크 (4개 영역)
    canvas.drawRect(Rect.fromLTWH(0, 0, w, cropRect.top), maskPaint);
    canvas.drawRect(Rect.fromLTWH(0, cropRect.bottom, w, h - cropRect.bottom), maskPaint);
    canvas.drawRect(Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height), maskPaint);
    canvas.drawRect(Rect.fromLTWH(cropRect.right, cropRect.top, w - cropRect.right, cropRect.height), maskPaint);

    // 크롭 테두리
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(cropRect, borderPaint);

    // 3x3 가이드 라인
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 1; i <= 2; i++) {
      final x = cropRect.left + cropRect.width * i / 3;
      final y = cropRect.top + cropRect.height * i / 3;
      canvas.drawLine(Offset(x, cropRect.top), Offset(x, cropRect.bottom), guidePaint);
      canvas.drawLine(Offset(cropRect.left, y), Offset(cropRect.right, y), guidePaint);
    }

    // 코너 핸들
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const cs = 14.0; // corner size
    for (final corner in [cropRect.topLeft, cropRect.topRight, cropRect.bottomLeft, cropRect.bottomRight]) {
      final dx = corner == cropRect.topLeft || corner == cropRect.bottomLeft ? cs : -cs;
      final dy = corner == cropRect.topLeft || corner == cropRect.topRight ? cs : -cs;
      canvas.drawLine(Offset(corner.dx + dx, corner.dy), corner, cornerPaint);
      canvas.drawLine(corner, Offset(corner.dx, corner.dy + dy), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.cropRect != cropRect || old.w != w || old.h != h;
}
