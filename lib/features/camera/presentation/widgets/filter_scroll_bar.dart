import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/models/filter_model.dart';
import '../../../../core/services/storage_service.dart';
import '../../providers/camera_provider.dart';

/// 하단 필터 스크롤 바 (카메라 프리뷰 위에 반투명 오버레이)
/// 좌우 스와이프로 필터 전환, 선택 시 < 100ms 전환
class FilterScrollBar extends ConsumerStatefulWidget {
  const FilterScrollBar({super.key});

  @override
  ConsumerState<FilterScrollBar> createState() => _FilterScrollBarState();
}

class _FilterScrollBarState extends ConsumerState<FilterScrollBar> {
  late ScrollController _scrollController;
  static const double _itemWidth = AppDimensions.filterThumbnailSize + 16;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToFilter(int index) {
    final offset = (index * _itemWidth) - (MediaQuery.of(context).size.width / 2) + (_itemWidth / 2);
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);
    final prefs = StorageService.prefs;

    // 즐겨찾기 우선 정렬
    final filters = [
      ...FilterData.all.where((f) => prefs.favoriteFilterIds.contains(f.id)),
      ...FilterData.all.where((f) => !prefs.favoriteFilterIds.contains(f.id)),
    ];

    return SizedBox(
      height: AppDimensions.filterBarHeight,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.filterBarPaddingV,
        ),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = cameraState.activeFilter?.id == filter.id;

          return _FilterItem(
            filter: filter,
            isSelected: isSelected,
            onTap: () {
              ref.read(cameraProvider.notifier).selectFilter(filter);
              _scrollToFilter(index);
            },
          );
        },
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  const _FilterItem({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  final FilterModel filter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: isSelected
            ? AppDimensions.filterThumbnailSizeSelected
            : AppDimensions.filterThumbnailSize,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 썸네일
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: isSelected
                  ? AppDimensions.filterThumbnailSizeSelected
                  : AppDimensions.filterThumbnailSize,
              height: isSelected
                  ? AppDimensions.filterThumbnailSizeSelected
                  : AppDimensions.filterThumbnailSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isSelected ? 14 : 12),
                border: isSelected
                    ? Border.all(color: AppColors.shutter, width: 2)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 6,
                        )
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isSelected ? 12 : 10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 썸네일 이미지 (없으면 컬러 fallback)
                    Image.asset(
                      filter.thumbnailAssetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _categoryColor(filter.category),
                      ),
                    ),
                    // Pro 잠금 오버레이
                    if (filter.isPro && !_isProUser())
                      Container(
                        color: Colors.black.withOpacity(0.4),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    // NEW 배지
                    if (filter.isNew)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'NEW',
                            style: AppTypography.proBadge,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 필터 이름
            Text(
              filter.name,
              style: AppTypography.filterLabel.copyWith(
                color: isSelected ? AppColors.shutter : AppColors.shutter.withOpacity(0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  bool _isProUser() => StorageService.prefs.isProUser;

  Color _categoryColor(FilterCategory category) {
    switch (category) {
      case FilterCategory.warm:
        return AppColors.warmTone;
      case FilterCategory.cool:
        return AppColors.coolTone;
      case FilterCategory.film:
        return AppColors.filmTone;
      case FilterCategory.aesthetic:
        return AppColors.aestheticTone;
    }
  }
}
