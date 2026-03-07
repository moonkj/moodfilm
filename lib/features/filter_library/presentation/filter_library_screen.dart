import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/filter_model.dart';
import '../../../core/services/storage_service.dart';
import '../../camera/providers/camera_provider.dart';


/// 필터 라이브러리 화면
/// 카테고리 탭 + 2열 그리드 + 즐겨찾기
class FilterLibraryScreen extends ConsumerStatefulWidget {
  const FilterLibraryScreen({super.key});

  @override
  ConsumerState<FilterLibraryScreen> createState() =>
      _FilterLibraryScreenState();
}

class _FilterLibraryScreenState
    extends ConsumerState<FilterLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Warm | Cool | Film | Aesthetic | Favorites
  static const _tabs = ['Warm', 'Cool', 'Film', 'Aesthetic', 'Favorites'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<FilterModel> _filtersForTab(int index) {
    final prefs = StorageService.prefs;
    switch (index) {
      case 0:
        return FilterData.byCategory(FilterCategory.warm);
      case 1:
        return FilterData.byCategory(FilterCategory.cool);
      case 2:
        return FilterData.byCategory(FilterCategory.film);
      case 3:
        return FilterData.byCategory(FilterCategory.aesthetic);
      case 4:
        return FilterData.all
            .where((f) => prefs.favoriteFilterIds.contains(f.id))
            .toList();
      default:
        return [];
    }
  }

  void _onFilterTap(FilterModel filter) {
    ref.read(cameraProvider.notifier).selectFilter(filter);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Filter Library'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs
              .map((t) => Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (t == 'Favorites')
                          const Icon(Icons.favorite_rounded, size: 14),
                        if (t == 'Favorites') const SizedBox(width: 4),
                        Text(t),
                      ],
                    ),
                  ))
              .toList(),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(
          _tabs.length,
          (index) => _FilterGrid(
            filters: _filtersForTab(index),
            onFilterTap: _onFilterTap,
            onFavoriteToggle: (filterId) {
              StorageService.prefs.toggleFavorite(filterId);
              ref.read(cameraProvider.notifier).refreshFavorites();
              setState(() {});
            },
          ),
        ),
      ),
    );
  }
}

class _FilterGrid extends StatelessWidget {
  const _FilterGrid({
    required this.filters,
    required this.onFilterTap,
    required this.onFavoriteToggle,
  });

  final List<FilterModel> filters;
  final void Function(FilterModel filter) onFilterTap;
  final void Function(String filterId) onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) {
      return const Center(
        child: Text('즐겨찾기한 필터가 없습니다', style: AppTypography.body),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filters.length,
      itemBuilder: (context, index) {
        return _FilterGridItem(
          filter: filters[index],
          onTap: () => onFilterTap(filters[index]),
          onFavoriteToggle: () => onFavoriteToggle(filters[index].id),
        );
      },
    );
  }
}

class _FilterGridItem extends StatelessWidget {
  const _FilterGridItem({
    required this.filter,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  final FilterModel filter;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final prefs = StorageService.prefs;
    final isFavorite = prefs.favoriteFilterIds.contains(filter.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        ),
        child: Stack(
          children: [
            // 썸네일
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              child: Column(
                children: [
                  // 이미지 영역 (70%)
                  Expanded(
                    flex: 7,
                    child: Image.asset(
                      filter.thumbnailAssetPath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.warmTone,
                      ),
                    ),
                  ),
                  // 필터명 영역 (30%)
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(filter.name, style: AppTypography.filterName),
                                Text(filter.description,
                                    style: AppTypography.caption,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1),
                              ],
                            ),
                          ),
                          // 즐겨찾기 버튼
                          GestureDetector(
                            onTap: onFavoriteToggle,
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFavorite
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // NEW 배지
            if (filter.isNew)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text('NEW', style: AppTypography.proBadge),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
