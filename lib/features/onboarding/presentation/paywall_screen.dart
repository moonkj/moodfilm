import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/iap_service.dart';

/// Paywall 화면
/// 1회 구매 → 모든 필터 무제한 (₩29,900)
/// RevenueCat product ID: 'lifetime'
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.source});
  final String source; // 진입 경로 (analytics용)

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isPurchasing = false;
  bool _isRestoring = false;
  String? _errorMessage;

  static const _features = [
    ('필터 20종 전체 해금', Icons.auto_awesome_rounded),
    ('Dreamy Glow · Film Grain 이펙트', Icons.blur_on_rounded),
    ('동영상 필터 녹화', Icons.videocam_rounded),
    ('갤러리 일괄 필터 적용', Icons.photo_library_rounded),
    ('향후 추가 필터 무료 업데이트', Icons.update_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // 닫기 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 타이틀
            const Text(
              'MoodFilm Pro',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '모든 필터 · 한 번만 구매',
              style: AppTypography.body.copyWith(color: Colors.white60),
            ),

            const SizedBox(height: 32),

            // 기능 목록
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: _features
                    .map((f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(f.$2, color: AppColors.accent, size: 18),
                              const SizedBox(width: 12),
                              Text(
                                f.$1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),

            const SizedBox(height: 32),

            // 가격 카드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent, width: 1.5),
                ),
                child: const Column(
                  children: [
                    Text(
                      '₩29,900',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '1회 구매 · 영구 사용',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            // 오류 메시지
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),

            const Spacer(),

            // 구매 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPurchasing || _isRestoring ? null : _purchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isPurchasing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '지금 구매하기',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isPurchasing || _isRestoring ? null : _restore,
              child: _isRestoring
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white38,
                        strokeWidth: 1.5,
                      ),
                    )
                  : const Text(
                      '구매 복원',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _purchase() async {
    setState(() { _isPurchasing = true; _errorMessage = null; });
    try {
      final success = await IapService.purchaseLifetime();
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true); // true = 구매 성공
      }
    } on PurchasesErrorCode catch (e) {
      if (mounted && e != PurchasesErrorCode.purchaseCancelledError) {
        setState(() => _errorMessage = '구매에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (_) {
      if (mounted) setState(() => _errorMessage = '구매에 실패했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() { _isRestoring = true; _errorMessage = null; });
    try {
      final success = await IapService.restorePurchases();
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _errorMessage = '복원할 구매 내역이 없습니다.');
      }
    } catch (_) {
      if (mounted) setState(() => _errorMessage = '복원에 실패했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }
}
