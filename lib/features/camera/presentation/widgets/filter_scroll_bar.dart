import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/models/filter_model.dart';
import '../../../../core/services/storage_service.dart';
import '../../providers/camera_provider.dart';

/// 하단 필터 스크롤 바 (카메라 프리뷰 위에 반투명 오버레이)
/// 좌우 스와이프로 필터 전환, 선택 시 < 100ms 전환
class FilterScrollBar extends ConsumerStatefulWidget {
  const FilterScrollBar({
    super.key,
    this.onNoFilterSelected,
    this.isNoFilterSelected = false,
  });

  /// null이 아니면 "효과 없음" 항목을 맨 앞에 표시
  final VoidCallback? onNoFilterSelected;
  final bool isNoFilterSelected;

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

    final hasNoFilter = widget.onNoFilterSelected != null;
    // hasNoFilter이면 index 0 = "효과 없음", 나머지 +1 offset
    final itemCount = filters.length + 1 + (hasNoFilter ? 1 : 0);

    return SizedBox(
      height: AppDimensions.filterBarHeight,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.filterBarPaddingV,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // "효과 없음" 버튼 (첫 번째)
          if (hasNoFilter && index == 0) {
            return _NoFilterItem(
              isSelected: widget.isNoFilterSelected,
              onTap: widget.onNoFilterSelected!,
            );
          }

          final filterIndex = hasNoFilter ? index - 1 : index;

          // 마지막 아이템: "전체" 버튼
          if (filterIndex == filters.length) {
            return _AllFiltersButton(onTap: () => context.push('/library'));
          }

          final filter = filters[filterIndex];
          final isSelected = !widget.isNoFilterSelected &&
              cameraState.activeFilter?.id == filter.id;

          return _FilterItem(
            filter: filter,
            isSelected: isSelected,
            onTap: () {
              ref.read(cameraProvider.notifier).selectFilter(filter);
              _scrollToFilter(filterIndex);
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
    return Semantics(
      label: '${filter.name} 필터',
      button: true,
      selected: isSelected,
      child: GestureDetector(
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
                          color: Colors.white.withValues(alpha:0.3),
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
                    // 썸네일 이미지 (없으면 필터별 대표 컬러 fallback)
                    Image.asset(
                      filter.thumbnailAssetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _filterFallbackColor(filter),
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
                color: isSelected ? AppColors.shutter : AppColors.shutter.withValues(alpha:0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      ),
    );
  }

  Color _filterFallbackColor(FilterModel filter) {
    // 썸네일 없을 때 필터별 대표 컬러 (각 필터의 실제 색감 기준)
    switch (filter.id) {
      // Signature
      case 'mood':        return const Color(0xFFD4A88C); // 따뜻한 드리미 베이지
      case 'dream':       return const Color(0xFFB898D0); // 보랏빛 안개
      // Warm
      case 'milk':        return const Color(0xFFF8F2EC);
      case 'cream':       return const Color(0xFFF5E0B8);
      case 'butter':      return const Color(0xFFEED888);
      case 'honey':       return const Color(0xFFD49040);
      case 'peach':       return const Color(0xFFF0A880);
      // Cool
      case 'sky':         return const Color(0xFF88C0E8);
      case 'ocean':       return const Color(0xFF3C7498);
      case 'mint':        return const Color(0xFF80D4B0);
      case 'cloud':       return const Color(0xFFD4ECF8);
      case 'ice':         return const Color(0xFFB0DCF4);
      // Film
      case 'film98':      return const Color(0xFFC0A880);
      case 'film03':      return const Color(0xFFD0BC88);
      case 'disposable':  return const Color(0xFFD0B470);
      case 'retro_ccd':   return const Color(0xFF8CA08C);
      case 'kodak_soft':  return const Color(0xFFC8C0A0);
      // Aesthetic
      case 'soft_pink':   return const Color(0xFFF4A8C0);
      case 'lavender':    return const Color(0xFFC0A0DC);
      case 'dusty_blue':  return const Color(0xFF7890B8);
      case 'cafe_mood':   return const Color(0xFFC09060);
      case 'seoul_night': return const Color(0xFF3C3C7C);
      default:
        switch (filter.category) {
          case FilterCategory.warm:      return AppColors.warmTone;
          case FilterCategory.cool:      return AppColors.coolTone;
          case FilterCategory.film:      return AppColors.filmTone;
          case FilterCategory.aesthetic: return AppColors.aestheticTone;
        }
    }
  }
}

/// 필터 없음 버튼
class _NoFilterItem extends StatelessWidget {
  const _NoFilterItem({required this.isSelected, required this.onTap});
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
                    : Border.all(
                        color: AppColors.shutter.withValues(alpha: 0.4),
                        width: 1.5),
                color: Colors.black.withValues(alpha: 0.4),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 6)]
                    : null,
              ),
              child: Center(
                child: Icon(
                  Icons.block_rounded,
                  color: isSelected ? AppColors.shutter : AppColors.shutter.withValues(alpha: 0.7),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '없음',
              style: AppTypography.filterLabel.copyWith(
                color: isSelected ? AppColors.shutter : AppColors.shutter.withValues(alpha: 0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 필터 스크롤바 끝 "전체" 버튼 → 필터 라이브러리 이동
class _AllFiltersButton extends StatelessWidget {
  const _AllFiltersButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: AppDimensions.filterThumbnailSize,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppDimensions.filterThumbnailSize,
              height: AppDimensions.filterThumbnailSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.shutter.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: const Icon(
                Icons.apps_rounded,
                color: AppColors.shutter,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '전체',
              style: AppTypography.filterLabel.copyWith(
                color: AppColors.shutter.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
