// RevenueCat in-app purchases (iOS / Android).
// Stripe = web; IAP = in-app. See DOCS/PAYMENTS_CLARIFICATION.md and DOCS/revenuecat/REVENUECAT_INTEGRATION.md.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Entitlement identifier used in RevenueCat dashboard and for ARC Pro access.
const String kRevenueCatEntitlementArcPro = 'ARC Pro';

/// Test/sandbox iOS API key (RevenueCat → Project → API Keys → Public iOS Sandbox).
/// Replace with your own after setup. See DOCS/revenuecat/REVENUECAT_SETUP.md.
const String kRevenueCatIosApiKeyTest = 'test_bvEOhrZwfzRusfKcJYIFzYghpCK';

/// Live iOS API key for production (RevenueCat → API Keys → Public Apple App Store).
/// Prefer passing the real key at build time so it is not committed:
/// `flutter build ipa --dart-define=REVENUECAT_IOS_API_KEY=appl_xxxxx`
const String kRevenueCatIosApiKeyLive = 'test_bvEOhrZwfzRusfKcJYIFzYghpCK';

/// Non-empty value from `--dart-define=REVENUECAT_IOS_API_KEY=...` overrides [kRevenueCatIosApiKeyLive] / [kRevenueCatIosApiKeyTest].
const String kRevenueCatIosApiKeyFromEnvironment =
    String.fromEnvironment('REVENUECAT_IOS_API_KEY', defaultValue: '');

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
      final apiKey = _iosPublicApiKey();
      if (kReleaseMode &&
          kRevenueCatIosApiKeyFromEnvironment.isEmpty &&
          apiKey.startsWith('test_')) {
        debugPrint(
          'RevenueCat: Release build is using a test_* API key. '
          'App Store / TestFlight purchases need Public Apple App Store (appl_*). '
          'Set --dart-define=REVENUECAT_IOS_API_KEY=appl_... or update kRevenueCatIosApiKeyLive.',
        );
      }
      await Purchases.configure(
        PurchasesConfiguration(apiKey)..appUserID = appUserId,
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

  /// Returns true if the exception is RevenueCat "Error 23" / configuration error
  /// (products in RevenueCat dashboard could not be fetched from App Store Connect).
  static bool isConfigurationError(dynamic e) {
    if (e == null) return false;
    final str = e.toString().toLowerCase();
    if (str.contains('error 23') ||
        str.contains('error 22') ||
        str.contains('configuration') && str.contains('issue')) {
      return true;
    }
    if (e is PlatformException) {
      final code = e.code.toString();
      if (code == '22' || code == '23') return true;
    }
    return false;
  }

  /// Check if offerings/products are available (no Error 23). Call before presenting paywall to show a friendly message instead of RevenueCat's generic dialog.
  Future<bool> areOfferingsAvailable() async {
    if (!_configured) return false;
    try {
      final offering = await _resolveOfferingWithPackages();
      return offering != null;
    } on PlatformException catch (e) {
      final code = e.code.toString();
      if (code == '22' || code == '23') return false;
      rethrow;
    } catch (e) {
      debugPrint('RevenueCat: areOfferingsAvailable $e');
      return false;
    }
  }

  /// Present RevenueCat paywall (design in RevenueCat dashboard).
  /// May throw; use [isConfigurationError] on catch to show a friendly message.
  Future<void> presentPaywall() async {
    if (!_configured) return;
    final offering = await _resolveOfferingWithPackages();
    await RevenueCatUI.presentPaywall(offering: offering);
  }

  /// Present paywall only if user does not have [entitlementId]. Returns true if user has access (no paywall shown).
  Future<bool> presentPaywallIfNeeded({String? entitlementId}) async {
    if (!_configured) return false;
    final offering = await _resolveOfferingWithPackages();
    final result = await RevenueCatUI.presentPaywallIfNeeded(
      entitlementId ?? kRevenueCatEntitlementArcPro,
      offering: offering,
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

  String _iosPublicApiKey() {
    if (kRevenueCatIosApiKeyFromEnvironment.isNotEmpty) {
      return kRevenueCatIosApiKeyFromEnvironment;
    }
    return kReleaseMode ? kRevenueCatIosApiKeyLive : kRevenueCatIosApiKeyTest;
  }

  /// Prefer [Offerings.current]; if it has no packages, use the first offering in [Offerings.all] that does.
  /// Fixes empty paywalls when the dashboard offering exists but is not set as **Current**.
  Future<Offering?> _resolveOfferingWithPackages() async {
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current != null && current.availablePackages.isNotEmpty) {
      return current;
    }
    for (final o in offerings.all.values) {
      if (o.availablePackages.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            'RevenueCat: using offering "${o.identifier}" (not Current in dashboard). '
            'Set it as Current under Offerings for consistency.',
          );
        }
        return o;
      }
    }
    if (kDebugMode) {
      debugPrint(
        'RevenueCat: no offering has packages. '
        'current=${offerings.current?.identifier}, '
        'all=[${offerings.all.keys.join(', ')}]',
      );
    }
    return null;
  }
}
