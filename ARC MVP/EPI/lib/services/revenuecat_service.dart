// RevenueCat in-app purchases (iOS / Android).
// Stripe = web; IAP = in-app. See DOCS/PAYMENTS_CLARIFICATION.md and DOCS/revenuecat/REVENUECAT_INTEGRATION.md.

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Entitlement identifier used in RevenueCat dashboard and for ARC Pro access.
const String kRevenueCatEntitlementArcPro = 'ARC Pro';

/// Test iOS API key. Replace with live key in production (e.g. via flavor/env).
const String kRevenueCatIosApiKeyTest = 'test_bvEOhrZwfzRusfKcJYIFzYghpCK';

class RevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  bool _configured = false;

  /// Configure RevenueCat once at app startup. Safe to call multiple times; only configures once.
  /// Call after Firebase/auth is ready; pass [appUserId] (e.g. Firebase UID) to sync with web/Stripe.
  Future<void> configure({String? appUserId}) async {
    if (_configured) return;
    if (kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Purchases.configure(
        PurchasesConfiguration(kRevenueCatIosApiKeyTest)..appUserID = appUserId,
      );
      _configured = true;
      debugPrint('RevenueCat: Configured (iOS)');
    }
    // Add Android when supporting Android IAP:
    // if (defaultTargetPlatform == TargetPlatform.android) { ... }
  }

  /// Call after user signs in (e.g. with Firebase UID) for cross-device entitlement sync.
  Future<void> logIn(String appUserId) async {
    if (!_configured) return;
    try {
      final result = await Purchases.logIn(appUserId);
      debugPrint('RevenueCat: Logged in ${result.customerInfo.originalAppUserId}');
    } catch (e) {
      debugPrint('RevenueCat: logIn error $e');
    }
  }

  /// Call on sign-out so the next purchaser is not attributed to the previous user.
  Future<void> logOut() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('RevenueCat: logOut error $e');
    }
  }

  String get entitlementId => kRevenueCatEntitlementArcPro;

  /// Returns whether the user has active ARC Pro entitlement from in-app purchase.
  Future<bool> hasArcProAccess() async {
    if (!_configured) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[kRevenueCatEntitlementArcPro]?.isActive ?? false;
    } catch (e) {
      debugPrint('RevenueCat: getCustomerInfo error $e');
      return false;
    }
  }

  /// Get latest customer info (entitlements, active subscriptions, etc.).
  Future<CustomerInfo?> getCustomerInfo() async {
    if (!_configured) return null;
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('RevenueCat: getCustomerInfo $e');
      return null;
    }
  }

  /// Add listener for customer info updates (e.g. after purchase/restore). Call removeCustomerInfoUpdateListener when done.
  void addCustomerInfoUpdateListener(void Function(CustomerInfo) listener) {
    if (!_configured) return;
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  void removeCustomerInfoUpdateListener(void Function(CustomerInfo) listener) {
    if (!_configured) return;
    Purchases.removeCustomerInfoUpdateListener(listener);
  }

  /// Restore purchases. Use from Customer Center or a "Restore" button.
  Future<CustomerInfo?> restorePurchases() async {
    if (!_configured) return null;
    try {
      return await Purchases.restorePurchases();
    } catch (e) {
      debugPrint('RevenueCat: restorePurchases $e');
      rethrow;
    }
  }

  /// Present RevenueCat paywall (design in RevenueCat dashboard).
  Future<void> presentPaywall() async {
    if (!_configured) return;
    await RevenueCatUI.presentPaywall();
  }

  /// Present paywall only if user does not have [entitlementId]. Returns true if user has access (no paywall shown).
  Future<bool> presentPaywallIfNeeded({String? entitlementId}) async {
    if (!_configured) return false;
    final result = await RevenueCatUI.presentPaywallIfNeeded(
      entitlementId ?? kRevenueCatEntitlementArcPro,
    );
    return result == PaywallResult.notPresented ||
        result == PaywallResult.purchased ||
        result == PaywallResult.restored;
  }

  /// Present Customer Center (manage subscription, restore). Use for in-app purchase users.
  Future<void> presentCustomerCenter() async {
    if (!_configured) return;
    await RevenueCatUI.presentCustomerCenter();
  }
}
