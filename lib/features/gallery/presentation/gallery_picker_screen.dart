import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/filter_model.dart';
import '../../../l10n/app_localizations.dart';
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

  // 페이지네이션
  static const int _pageSize = 80;
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  AssetPathEntity? _album;
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.addListener(_onScroll);
    PhotoManager.addChangeCallback(_onPhotosChanged);
    PhotoManager.startChangeNotify();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    PhotoManager.removeChangeCallback(_onPhotosChanged);
    PhotoManager.stopChangeNotify();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
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
    final assets = await albums.first.getAssetListPaged(page: 0, size: _pageSize);
    if (mounted) {
      setState(() {
        _album = albums.first;
        _assets = assets;
        _currentPage = 0;
        _hasMore = assets.length == _pageSize;
      });
    }
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

    final album = albums.first;
    final assets = await album.getAssetListPaged(page: 0, size: _pageSize);
    if (mounted) {
      setState(() {
        _album = album;
        _assets = assets;
        _currentPage = 0;
        _hasMore = assets.length == _pageSize;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _album == null) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final more = await _album!.getAssetListPaged(page: nextPage, size: _pageSize);
    if (mounted) {
      setState(() {
        _assets.addAll(more);
        _currentPage = nextPage;
        _hasMore = more.length == _pageSize;
        _isLoadingMore = false;
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
        builder: (_) => VideoPlayerScreen(videoPath: file.path, assetId: asset.id),
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

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: Text(l10n.deleteCountTitle(count),
            style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: Text(l10n.deleteSelectedConfirm,
            style: const TextStyle(color: Colors.white60, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
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
        content: Text(AppLocalizations.of(context).deletedCount(ids.length)),
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

    final result = await showModalBottomSheet<(FilterModel, double)>(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterPickerSheet(),
    );

    if (result == null || !mounted) return;
    await _applyBatchFilter(result.$1, result.$2);
  }

  Future<void> _applyBatchFilter(FilterModel filter, double intensity) async {
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
        intensity: intensity,
        adjustments: {},
        effects: {},
        saveToGallery: true,
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
        content: Text(AppLocalizations.of(context).batchSavedCount(successCount)),
        backgroundColor: AppColors.darkSurface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildBody()),
            _buildBottomTabBar(),
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
              color: const Color(0xFF3D3531),
              size: 20,
            ),
            onPressed: _isMultiSelectMode ? _toggleMultiSelectMode : () => context.pop(),
          ),
          Expanded(
            child: _isMultiSelectMode
                ? Text(
                    AppLocalizations.of(context).selectedCount(_selectedIds.length),
                    style: const TextStyle(
                      color: Color(0xFF3D3531),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Like it',
                          style: GoogleFonts.nunito(
                            color: const Color(0xFF3D3531),
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        TextSpan(
                          text: '!',
                          style: GoogleFonts.nunito(
                            color: AppColors.accent,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (!_isMultiSelectMode)
            TextButton(
              onPressed: _toggleMultiSelectMode,
              child: Text(AppLocalizations.of(context).select, style: const TextStyle(color: AppColors.accent, fontSize: 15)),
            ),
          if (_isMultiSelectMode && _selectedIds.isNotEmpty) ...[
            _topCircleBtn(Icons.ios_share_rounded, color: const Color(0xFF3D3531), onTap: _shareSelected),
            const SizedBox(width: 8),
            _topCircleBtn(Icons.delete_outline_rounded, color: Colors.red, onTap: _confirmAndDelete),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _showBatchFilterPicker,
              child: Text(AppLocalizations.of(context).filterTab, style: const TextStyle(color: AppColors.accent, fontSize: 15)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _topCircleBtn(IconData icon, {required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0EC),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE0DAD4), width: 0.5),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildBottomTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEDE8E4), width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _bottomTab(Icons.photo_library_rounded, AppLocalizations.of(context).album, selected: true),
          GestureDetector(
            onTap: () => context.pop(),
            child: _bottomTab(Icons.camera_alt_rounded, AppLocalizations.of(context).camera, selected: false),
          ),
        ],
      ),
    );
  }

  Widget _bottomTab(IconData icon, String label, {required bool selected}) {
    final color = selected ? const Color(0xFF3D3531) : const Color(0xFFBBB6B2);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            )),
      ],
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
              AppLocalizations.of(context).processingProgress(_processedCount, _selectedIds.length),
              style: const TextStyle(color: Color(0xFF8A8480), fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_permissionDenied) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined, color: Color(0xFFCCC8C4), size: 48),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).galleryPermissionRequired,
                style: const TextStyle(color: Color(0xFF8A8480), fontSize: 16)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => PhotoManager.openSetting(),
              child: Text(AppLocalizations.of(context).allowInSettings,
                  style: const TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
    }

    if (_assets.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).noPhotos,
            style: const TextStyle(color: Color(0xFFCCC8C4))),
      );
    }

    return _buildMasonryGrid();
  }

  // MARK: - 3컬럼 균등 격자 그리드

  Widget _buildMasonryGrid() {
    // 마지막 셀: 로딩 인디케이터용 슬롯
    final itemCount = _assets.length + (_isLoadingMore ? 1 : 0);

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // 마지막 슬롯 = 로딩 스피너
        if (index >= _assets.length) {
          return const Center(
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                color: AppColors.accent, strokeWidth: 2),
            ),
          );
        }

        final asset = _assets[index];
        final isSelected = _selectedIds.contains(asset.id);
        return _AssetThumbnail(
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
        );
      },
    );
  }
}

// MARK: - 필터 선택 바텀시트

class _FilterPickerSheet extends StatefulWidget {
  @override
  State<_FilterPickerSheet> createState() => _FilterPickerSheetState();
}

class _FilterPickerSheetState extends State<_FilterPickerSheet> {
  FilterModel? _selected;
  double _intensity = 1.0;

  @override
  Widget build(BuildContext context) {
    final filters = FilterData.all;
    final intensityPct = (_intensity * 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 핸들
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // 필터 가로 스크롤
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemCount: filters.length,
            itemBuilder: (ctx, i) {
              final f = filters[i];
              final isActive = _selected?.id == f.id;
              return GestureDetector(
                onTap: () => setState(() => _selected = f),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive ? AppColors.accent : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          f.thumbnailAssetPath,
                          width: 60, height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, err, st) => Container(
                            width: 60, height: 60,
                            color: AppColors.darkBg,
                            child: const Icon(Icons.filter_rounded,
                                color: Colors.white38, size: 24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      f.name,
                      style: TextStyle(
                        color: isActive ? AppColors.accent : Colors.white54,
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // 강도 슬라이더
        if (_selected != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                const Text('강도', style: TextStyle(color: Colors.white60, fontSize: 13)),
                const Spacer(),
                Text(
                  '$intensityPct%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: _intensity,
              min: 0.0,
              max: 1.0,
              onChanged: (v) => setState(() => _intensity = v),
            ),
          ),
        ] else
          const SizedBox(height: 16),
        // 적용 버튼
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16,
              MediaQuery.of(context).padding.bottom + 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context).pop((_selected!, _intensity)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _selected == null ? '필터를 선택하세요' : '적용',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
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
      const ThumbnailSize(180, 180),
      quality: 70,
    );
    if (mounted) setState(() => _bytes = bytes);
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
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
                : const ColoredBox(color: Color(0xFFF0EDEA)),

            // 동영상: 재생시간 뱃지
            if (widget.asset.type == AssetType.video)
              Positioned(
                bottom: 5,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(widget.asset.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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
