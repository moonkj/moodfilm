import 'package:flutter/material.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/haptic_utils.dart';

/// 서터 버튼 — scale bounce 0.92→1.0 150ms spring(0.6)
class ShutterButton extends StatefulWidget {
  const ShutterButton({
    super.key,
    required this.onTap,
    this.isCapturing = false,
  });

  final VoidCallback onTap;
  final bool isCapturing;

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion 대응: 시스템 설정에 따라 애니메이션 비활성화
    final disable = MediaQuery.of(context).disableAnimations;
    _controller.duration = disable ? Duration.zero : const Duration(milliseconds: 150);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    HapticUtils.shutter();
    _controller.forward();
  }

  void _onTapUp(_) {
    _controller.reverse().then((_) => widget.onTap());
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.isCapturing ? '촬영 중' : '촬영',
      button: true,
      child: GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: SizedBox(
          width: AppDimensions.shutterButtonSize + 4,
          height: AppDimensions.shutterButtonSize + 4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 민트 외곽 링 (얇게)
              Container(
                width: AppDimensions.shutterButtonSize + 4,
                height: AppDimensions.shutterButtonSize + 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF5CE8D8), // bright mint
                      Color(0xFF8FF5EC), // light mint
                    ],
                  ),
                ),
              ),
              // 내부 원 (촬영 시 축소) — 링 두께 ~3.5px
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: widget.isCapturing
                    ? AppDimensions.shutterButtonInner * 0.85
                    : AppDimensions.shutterButtonInner + 9,
                height: widget.isCapturing
                    ? AppDimensions.shutterButtonInner * 0.85
                    : AppDimensions.shutterButtonInner + 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isCapturing
                        ? [const Color(0xFFE8E0D8), const Color(0xFFD8D0C8)]
                        : [Colors.white, const Color(0xFFF5EEE8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC8A2D0).withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
