import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/filter_model.dart';
import '../../../native_plugins/filter_engine/filter_engine.dart';
import 'video_player_screen.dart';

/// 갤러리에서 사진 선택
/// - 단일 탭: EditorScreen으로 이동
/// - 우측 상단 "선택" 버튼: 다중 선택 모드 → 일괄 필터 적용
class GalleryPickerScreen extends StatefulWidget {
  const GalleryPickerScreen({super.key});

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> {
  List<AssetEntity> _assets = [];
  bool _isLoading = true;
  bool _permissionDenied = false;

  // 다중 선택 모드
  bool _isMultiSelectMode = false;
  final Set<String> _selectedIds = {};

  // 일괄 처리 상태
  bool _isBatchProcessing = false;
  int _processedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    PhotoManager.addChangeCallback(_onPhotosChanged);
    PhotoManager.startChangeNotify();
  }

  @override
  void dispose() {
    PhotoManager.removeChangeCallback(_onPhotosChanged);
    PhotoManager.stopChangeNotify();
    super.dispose();
  }

  void _onPhotosChanged(MethodCall call) {
    if (mounted && !_isLoading && !_isBatchProcessing) {
      _quietReload();
    }
  }

  Future<void> _quietReload() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );
    if (albums.isEmpty || !mounted) return;
    final assets = await albums.first.getAssetListPaged(page: 0, size: 200);
    if (mounted) setState(() => _assets = assets);
  }

  Future<void> _loadPhotos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      if (mounted) setState(() { _permissionDenied = true; _isLoading = false; });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );

    if (albums.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final assets = await albums.first.getAssetListPaged(page: 0, size: 200);
    if (mounted) {
      setState(() {
        _assets = assets;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectAsset(AssetEntity asset) async {
    if (_isMultiSelectMode) {
      setState(() {
        if (_selectedIds.contains(asset.id)) {
          _selectedIds.remove(asset.id);
        } else {
          _selectedIds.add(asset.id);
        }
      });
      return;
    }

    final file = await asset.file;
    if (file == null) return;
    if (!mounted) return;

    if (asset.type == AssetType.video) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(videoPath: file.path),
      ));
      return;
    }

    context.push('/editor', extra: <String, String?>{
      'path': file.path,
      'assetId': asset.id,
    });
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      _selectedIds.clear();
    });
  }

  Future<void> _confirmAndDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: Text('$count개 삭제',
            style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text('선택한 항목을 갤러리에서 삭제합니다.\n이 작업은 되돌릴 수 없습니다.',
            style: TextStyle(color: Colors.white60, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ids = _selectedIds.toList();
    await PhotoManager.editor.deleteWithIds(ids);
    if (!mounted) return;

    final idsToRemove = ids.toSet();
    setState(() {
      _assets.removeWhere((a) => idsToRemove.contains(a.id));
      _isMultiSelectMode = false;
      _selectedIds.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${ids.length}개를 삭제했습니다'),
        backgroundColor: AppColors.darkSurface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareSelected() async {
    if (_selectedIds.isEmpty) return;
    final selected = _assets.where((a) => _selectedIds.contains(a.id)).toList();

    final files = <XFile>[];
    for (final asset in selected) {
      final file = await asset.file;
      if (file != null) files.add(XFile(file.path));
    }
    if (files.isEmpty) return;
    await Share.shareXFiles(files);
  }

  Future<void> _showBatchFilterPicker() async {
    if (_selectedIds.isEmpty) return;

    final selectedFilter = await showModalBottomSheet<FilterModel>(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterPickerSheet(),
    );

    if (selectedFilter == null || !mounted) return;
    await _applyBatchFilter(selectedFilter);
  }

  Future<void> _applyBatchFilter(FilterModel filter) async {
    final selected = _assets.where((a) => _selectedIds.contains(a.id)).toList();

    setState(() {
      _isBatchProcessing = true;
      _processedCount = 0;
    });

    int successCount = 0;
    for (final asset in selected) {
      if (asset.type == AssetType.video) {
        if (mounted) setState(() => _processedCount++);
        continue;
      }

      final file = await asset.file;
      if (file == null) continue;

      final result = await FilterEngine.processImage(
        sourcePath: file.path,
        lutFileName: filter.lutFileName,
        intensity: 1.0,
        adjustments: {},
        effects: {},
      );

      if (result != null) successCount++;

      if (mounted) setState(() => _processedCount++);
    }

    if (!mounted) return;
    setState(() {
      _isBatchProcessing = false;
      _isMultiSelectMode = false;
      _selectedIds.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$successCount장을 갤러리에 저장했습니다'),
        backgroundColor: AppColors.darkSurface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // MARK: - 상단 바

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isMultiSelectMode ? Icons.close_rounded : Icons.arrow_back_ios_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _isMultiSelectMode ? _toggleMultiSelectMode : () => context.pop(),
          ),
          Expanded(
            child: _isMultiSelectMode
                ? Text(
                    '${_selectedIds.length}장 선택됨',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Like it',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: '!',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (!_isMultiSelectMode)
            TextButton(
              onPressed: _toggleMultiSelectMode,
              child: const Text('선택', style: TextStyle(color: AppColors.accent, fontSize: 15)),
            ),
          if (_isMultiSelectMode && _selectedIds.isNotEmpty) ...[
            IconButton(
              onPressed: _shareSelected,
              icon: const Icon(Icons.ios_share_rounded, color: AppColors.accent, size: 22),
            ),
            IconButton(
              onPressed: _confirmAndDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
            ),
            TextButton(
              onPressed: _showBatchFilterPicker,
              child: const Text('필터', style: TextStyle(color: AppColors.accent, fontSize: 15)),
            ),
          ],
        ],
      ),
    );
  }

  // MARK: - 바디

  Widget _buildBody() {
    if (_isBatchProcessing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 20),
            Text(
              '$_processedCount / ${_selectedIds.length} 처리 중...',
              style: const TextStyle(color: Colors.white60, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white38));
    }

    if (_permissionDenied) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined, color: Colors.white38, size: 48),
            const SizedBox(height: 16),
            const Text('갤러리 접근 권한이 필요합니다',
                style: TextStyle(color: Colors.white60, fontSize: 16)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => PhotoManager.openSetting(),
              child: const Text('설정에서 허용하기',
                  style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
    }

    if (_assets.isEmpty) {
      return const Center(
        child: Text('사진이 없습니다', style: TextStyle(color: Colors.white38)),
      );
    }

    return _buildMasonryGrid();
  }

  // MARK: - 벽돌 격자 (Masonry Grid)

  Widget _buildMasonryGrid() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        const gap = 3.0;
        final colWidth = (constraints.maxWidth - gap) / 2;

        // 두 컬럼에 자산 분배 (높이 합산이 짧은 쪽에 추가)
        final List<(AssetEntity, double)> leftCol = [];
        final List<(AssetEntity, double)> rightCol = [];
        double leftH = 0, rightH = 0;

        for (final asset in _assets) {
          final ar = (asset.width > 0 && asset.height > 0)
              ? asset.width / asset.height
              : 1.0;
          final cellH = colWidth / ar;

          if (leftH <= rightH) {
            leftCol.add((asset, cellH));
            leftH += cellH + gap;
          } else {
            rightCol.add((asset, cellH));
            rightH += cellH + gap;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildColumn(leftCol, colWidth, gap),
              SizedBox(width: gap),
              _buildColumn(rightCol, colWidth, gap),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColumn(List<(AssetEntity, double)> items, double width, double gap) {
    return SizedBox(
      width: width,
      child: Column(
        children: items.map((item) {
          final (asset, height) = item;
          final isSelected = _selectedIds.contains(asset.id);
          return Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: SizedBox(
              height: height,
              child: _AssetThumbnail(
                key: ValueKey(asset.id),
                asset: asset,
                isSelected: isSelected,
                isMultiSelectMode: _isMultiSelectMode,
                onTap: () => _selectAsset(asset),
                onLongPress: () async {
                  final file = await asset.file;
                  if (file == null || !mounted) return;
                  await Share.shareXFiles([XFile(file.path)]);
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// MARK: - 필터 선택 바텀시트

class _FilterPickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final filters = FilterData.all.where((f) => !f.isPro).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('필터 선택', style: AppTypography.h2),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemCount: filters.length,
            itemBuilder: (ctx, i) {
              final f = filters[i];
              return GestureDetector(
                onTap: () => Navigator.of(ctx).pop(f),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.darkBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.filter_rounded,
                          color: Colors.white38, size: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(f.name, style: AppTypography.caption),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// MARK: - 썸네일 위젯

class _AssetThumbnail extends StatefulWidget {
  const _AssetThumbnail({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onTap,
    this.onLongPress,
  });
  final AssetEntity asset;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(_AssetThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      setState(() => _bytes = null);
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final bytes = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(400, 400),
      quality: 80,
    );
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _bytes != null
                ? Image.memory(_bytes!, fit: BoxFit.cover)
                : const ColoredBox(color: AppColors.darkSurface),

            // 동영상 플레이 아이콘
            if (widget.asset.type == AssetType.video)
              const Positioned(
                bottom: 6,
                left: 6,
                child: Icon(Icons.play_circle_outline_rounded,
                    color: Colors.white, size: 22),
              ),

            // 다중 선택 체크박스
            if (widget.isMultiSelectMode)
              Positioned(
                top: 6,
                right: 6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isSelected ? AppColors.accent : Colors.transparent,
                    border: Border.all(
                      color: widget.isSelected ? AppColors.accent : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: widget.isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : null,
                ),
              ),

            // 선택 시 어두운 오버레이
            if (widget.isMultiSelectMode && widget.isSelected)
              const ColoredBox(color: Color(0x44000000)),
          ],
        ),
      ),
    );
  }
}
