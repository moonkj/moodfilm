import 'package:purchases_flutter/purchases_flutter.dart';
import 'storage_service.dart';

/// RevenueCat 기반 인앱결제 서비스
/// 상품: lifetime (non-consumable, ₩29,900)
/// Entitlement: pro
class IapService {
  IapService._();

  static const String _entitlementId = 'pro';
  static const String _productId = 'lifetime';

  // ── 초기화 (앱 시작 시 1회 호출) ─────────────────────────────────────────

  /// [apiKey] RevenueCat iOS API Key (App Store Connect 연동)
  static Future<void> configure({required String apiKey}) async {
    await Purchases.setLogLevel(LogLevel.warn);
    final configuration = PurchasesConfiguration(apiKey);
    await Purchases.configure(configuration);

    // 기존 Pro 상태 동기화 (앱 재설치 후 복원 보장)
    await _syncProStatus();
  }

  // ── 구매 ─────────────────────────────────────────────────────────────────

  /// lifetime 패키지 구매
  /// Returns: 구매 성공 여부
  static Future<bool> purchaseLifetime() async {
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.lifetime
          ?? offerings.current?.availablePackages
              .where((p) => p.storeProduct.identifier == _productId)
              .firstOrNull;

      if (package == null) {
        // 오퍼링 없을 때 product 직접 구매 시도
        final products = await Purchases.getProducts([_productId]);
        if (products.isEmpty) return false;
        final result = await Purchases.purchaseStoreProduct(products.first);
        return _handlePurchaseResult(result);
      }

      final result = await Purchases.purchasePackage(package);
      return _handlePurchaseResult(result);
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  // ── 복원 ─────────────────────────────────────────────────────────────────

  /// 이전 구매 복원 (기기 교체, 재설치 시)
  /// Returns: Pro 복원 성공 여부
  static Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      return _applyCustomerInfo(info);
    } catch (_) {
      return false;
    }
  }

  // ── 상태 확인 ─────────────────────────────────────────────────────────────

  /// 현재 RevenueCat 상태로 로컬 isProUser 동기화
  static Future<bool> _syncProStatus() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return _applyCustomerInfo(info);
    } catch (_) {
      return StorageService.prefs.isProUser;
    }
  }

  static bool _handlePurchaseResult(CustomerInfo info) {
    return _applyCustomerInfo(info);
  }

  static bool _applyCustomerInfo(CustomerInfo info) {
    final isPro = info.entitlements.active.containsKey(_entitlementId);
    if (StorageService.prefs.isProUser != isPro) {
      StorageService.prefs.isProUser = isPro;
      StorageService.prefs.save();
    }
    return isPro;
  }

  // ── 현재 Pro 상태 (로컬 캐시) ────────────────────────────────────────────
  static bool get isProUser => StorageService.prefs.isProUser;
}
