import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/liquid_glass_decoration.dart';

/// 노출 조정 시 나타나는 EV floating indicator
/// 상하 스와이프 → 노출 ±2EV 표시
class ExposureIndicator extends StatelessWidget {
  const ExposureIndicator({
    super.key,
    required this.ev,
    required this.isVisible,
  });

  final double ev;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: LiquidGlassPill(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ev >= 0 ? Icons.wb_sunny_outlined : Icons.brightness_3_outlined,
              color: AppColors.shutter,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              ev >= 0 ? '+${ev.toStringAsFixed(1)}' : ev.toStringAsFixed(1),
              style: const TextStyle(
                color: AppColors.shutter,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
