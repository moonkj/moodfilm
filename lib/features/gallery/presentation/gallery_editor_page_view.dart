import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../editor/presentation/editor_screen.dart';
import 'video_player_screen.dart';

/// 갤러리 에디터 스와이프 뷰
/// 사진/동영상 목록을 PageView로 감싸 좌우 스와이프로 이동
class GalleryEditorPageView extends StatefulWidget {
  const GalleryEditorPageView({
    super.key,
    required this.assets,
    required this.initialIndex,
  });

  final List<AssetEntity> assets;
  final int initialIndex;

  @override
  State<GalleryEditorPageView> createState() => _GalleryEditorPageViewState();
}

class _GalleryEditorPageViewState extends State<GalleryEditorPageView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.assets.length,
      itemBuilder: (context, index) {
        return _GalleryEditorPage(asset: widget.assets[index]);
      },
    );
  }
}

/// 개별 페이지 — 에셋 파일 로드 후 타입에 따라 EditorScreen / VideoPlayerScreen 렌더
class _GalleryEditorPage extends StatefulWidget {
  const _GalleryEditorPage({required this.asset});
  final AssetEntity asset;

  @override
  State<_GalleryEditorPage> createState() => _GalleryEditorPageState();
}

class _GalleryEditorPageState extends State<_GalleryEditorPage> {
  String? _filePath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    final file = await widget.asset.file;
    if (mounted) {
      setState(() {
        _filePath = file?.path;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_filePath == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('파일을 불러올 수 없습니다', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    if (widget.asset.type == AssetType.video) {
      return VideoPlayerScreen(
        videoPath: _filePath!,
        assetId: widget.asset.id,
      );
    }

    return EditorScreen(
      imagePath: _filePath!,
      assetId: widget.asset.id,
    );
  }
}
