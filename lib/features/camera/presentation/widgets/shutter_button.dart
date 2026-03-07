import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
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
          width: AppDimensions.shutterButtonSize,
          height: AppDimensions.shutterButtonSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 외곽 크림 링
              Container(
                width: AppDimensions.shutterButtonSize,
                height: AppDimensions.shutterButtonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.shutter.withValues(alpha:0.6),
                    width: 3,
                  ),
                ),
              ),
              // 내부 흰 원 — Liquid Glass 효과
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: widget.isCapturing
                    ? AppDimensions.shutterButtonInner * 0.85
                    : AppDimensions.shutterButtonInner,
                height: widget.isCapturing
                    ? AppDimensions.shutterButtonInner * 0.85
                    : AppDimensions.shutterButtonInner,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.shutter,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha:0.3),
                      blurRadius: 8,
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
