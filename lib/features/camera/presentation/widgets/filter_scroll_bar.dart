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
                    // 썸네일 이미지 (없으면 필터별 그라디언트 fallback)
                    Image.asset(
                      filter.thumbnailAssetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _filterFallbackGradient(filter),
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

  // 필터별 (base, highlight) 그라디언트 컬러
  (Color, Color) _filterColors(FilterModel filter) {
    switch (filter.id) {
      case 'mood':        return (const Color(0xFFD4A88C), const Color(0xFFF2D4B8));
      case 'dream':       return (const Color(0xFF9070C0), const Color(0xFFD0B8F0));
      case 'milk':        return (const Color(0xFFE8DDD0), const Color(0xFFFBF7F2));
      case 'cream':       return (const Color(0xFFD4A870), const Color(0xFFF5E0B8));
      case 'butter':      return (const Color(0xFFD4B840), const Color(0xFFEED888));
      case 'honey':       return (const Color(0xFFA86820), const Color(0xFFD49040));
      case 'peach':       return (const Color(0xFFD07858), const Color(0xFFF0B898));
      case 'sky':         return (const Color(0xFF5090C8), const Color(0xFFB0D8F0));
      case 'ocean':       return (const Color(0xFF245878), const Color(0xFF5090B8));
      case 'mint':        return (const Color(0xFF40A880), const Color(0xFF90D8B8));
      case 'cloud':       return (const Color(0xFF90B8D8), const Color(0xFFD8EEF8));
      case 'ice':         return (const Color(0xFF70B0D8), const Color(0xFFB8DDF0));
      case 'film98':      return (const Color(0xFF907050), const Color(0xFFCAAA80));
      case 'film03':      return (const Color(0xFFA09060), const Color(0xFFD0BC88));
      case 'disposable':  return (const Color(0xFF988040), const Color(0xFFD0B470));
      case 'retro_ccd':   return (const Color(0xFF607060), const Color(0xFF9AAC9A));
      case 'kodak_soft':  return (const Color(0xFF908870), const Color(0xFFC8C0A0));
      case 'soft_pink':   return (const Color(0xFFD07898), const Color(0xFFF4B8CC));
      case 'lavender':    return (const Color(0xFF8870B8), const Color(0xFFCCB8E8));
      case 'dusty_blue':  return (const Color(0xFF506090), const Color(0xFF8098C0));
      case 'cafe_mood':   return (const Color(0xFF805030), const Color(0xFFC09060));
      case 'seoul_night': return (const Color(0xFF202060), const Color(0xFF5858A8));
      default:
        switch (filter.category) {
          case FilterCategory.warm:      return (AppColors.warmTone, const Color(0xFFF5E0C0));
          case FilterCategory.cool:      return (AppColors.coolTone, const Color(0xFFB0D8F0));
          case FilterCategory.film:      return (AppColors.filmTone, const Color(0xFFD0B880));
          case FilterCategory.aesthetic: return (AppColors.aestheticTone, const Color(0xFFD8B8E8));
        }
    }
  }

  Widget _filterFallbackGradient(FilterModel filter) {
    final (base, highlight) = _filterColors(filter);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [highlight, base],
          stops: const [0.0, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // 미세 질감 오버레이 (필름 감성)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.3, -0.3),
                  radius: 1.2,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
