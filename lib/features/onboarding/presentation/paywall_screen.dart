import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';


/// Paywall 화면
/// Free → Pro 업그레이드 (₩2,900/월 | ₩14,900/년 | ₩29,900 평생)
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.source});
  final String source; // 진입 경로 (analytics용)

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedPlan = 1; // 0: 월간, 1: 연간(추천), 2: Lifetime

  static const _plans = [
    {'label': '월간', 'price': '₩2,900', 'period': '/월', 'highlight': false},
    {'label': '연간', 'price': '₩14,900', 'period': '/년', 'highlight': true, 'badge': '57% 할인'},
    {'label': '평생', 'price': '₩29,900', 'period': '한 번만', 'highlight': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // 닫기
            Padding(
              padding: const EdgeInsets.all(16),
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
            const Text('MoodFilm Pro',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              '모든 필터 & 이펙트 무제한',
              style: AppTypography.body.copyWith(color: Colors.white60),
            ),
            const SizedBox(height: 32),
            // 플랜 선택
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(
                  _plans.length,
                  (i) => Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPlan = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _selectedPlan == i
                              ? AppColors.accent.withOpacity(0.2)
                              : AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedPlan == i
                                ? AppColors.accent
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (_plans[i]['badge'] != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  _plans[i]['badge'] as String,
                                  style: AppTypography.proBadge,
                                ),
                              ),
                            Text(_plans[i]['label'] as String,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(_plans[i]['price'] as String,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            Text(_plans[i]['period'] as String,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            // 구독 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _subscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _selectedPlan == 1 ? '7일 무료 체험 시작' : '구독하기',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {},
              child: const Text('구독 복원',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ),
            const SizedBox(height: 8),
            const Text(
              '구독은 언제든지 취소 가능합니다',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _subscribe() async {
    // TODO: RevenueCat purchases_flutter 구독 처리
    Navigator.of(context).pop();
  }
}
