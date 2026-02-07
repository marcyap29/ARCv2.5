# RevenueCat Integration Guide – ARC App

**Last Updated:** February 7, 2026

This guide covers integrating RevenueCat for **Apple in-app purchases** (subscriptions and lifetime) in the ARC Flutter app, with optional reference for native iOS (SwiftUI + Swift Package Manager).

---

## Table of contents

1. [Prerequisites](#1-prerequisites)
2. [Flutter: Install the SDK](#2-flutter-install-the-sdk)
3. [iOS native dependency (CocoaPods)](#3-ios-native-dependency-cocoapods)
4. [Configure RevenueCat (API key, user ID)](#4-configure-revenuecat-api-key-user-id)
5. [Entitlement: ARC Pro](#5-entitlement-arc-pro)
6. [Products: Monthly, Yearly, Lifetime](#6-products-monthly-yearly-lifetime)
7. [Subscription logic and entitlement checking](#7-subscription-logic-and-entitlement-checking)
8. [Present RevenueCat Paywall](#8-present-revenuecat-paywall)
9. [Customer Center](#9-customer-center)
10. [Customer info and purchases](#10-customer-info-and-purchases)
11. [Error handling and best practices](#11-error-handling-and-best-practices)
12. [Unify with Stripe (SubscriptionService)](#12-unify-with-stripe-subscriptionservice)
13. [Optional: Native iOS (SwiftUI + SPM)](#13-optional-native-ios-swiftui--spm)
14. [Dashboard: Offerings and product setup](#14-dashboard-offerings-and-product-setup)

---

## 1. Prerequisites

- Flutter project (e.g. ARC MVP/EPI) with iOS (and optionally Android) targets.
- [RevenueCat](https://www.revenuecat.com) account.
- Apple Developer account; App Store Connect app and **In-App Purchases** created (monthly, yearly, lifetime).
- **Clarification:** Stripe = web purchases; in-app purchases = RevenueCat (this app). See [PAYMENTS_CLARIFICATION.md](../PAYMENTS_CLARIFICATION.md).

---

## 2. Flutter: Install the SDK

Add the core SDK and the UI package (paywalls + Customer Center):

```yaml
# pubspec.yaml
dependencies:
  purchases_flutter: ^8.0.0   # or latest from pub.dev
  purchases_ui_flutter: ^8.0.0
```

Then:

```bash
flutter pub get
```

- **Docs:** [Flutter installation](https://www.revenuecat.com/docs/getting-started/installation/flutter)
- Use **public** API keys only (iOS and Android keys from RevenueCat Dashboard → Project Settings → API Keys).

---

## 3. iOS native dependency (CocoaPods)

The Flutter plugin uses CocoaPods on iOS. After adding the packages:

```bash
cd ios && pod install && cd ..
```

If you use a minimum iOS version, ensure it’s at least **iOS 11.0** (Xcode 14+ recommended for paywalls). No manual Swift Package add is required for the Flutter path; the plugin brings the native SDK.

---

## 4. Configure RevenueCat (API key, user ID)

Configure once at app startup (e.g. after Firebase/auth is ready). Use **platform-specific public API keys** from the RevenueCat dashboard.

**Example: initialization service**

```dart
// lib/services/revenuecat_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  static RevenueCatService get instance => _instance;

  static const String _entitlementId = 'ARC Pro';

  /// Call once at app startup (e.g. after Firebase init / auth ready).
  Future<void> configure({String? appUserId}) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Purchases.configure(
        PurchasesConfiguration('test_bvEOhrZwfzRusfKcJYIFzYghpCK')
          ..appUserID = appUserId, // Optional: sync with Firebase UID for cross-platform
      );
      debugPrint('RevenueCat: Configured (iOS)');
    }
    // Add Android block with Android API key when supporting Android IAP.
  }

  /// Update user ID after login (e.g. Firebase UID) for consistent subscription across devices.
  Future<void> logIn(String appUserId) async {
    try {
      final result = await Purchases.logIn(appUserId);
      debugPrint('RevenueCat: Logged in ${result.customerInfo.originalAppUserId}');
    } catch (e) {
      debugPrint('RevenueCat: logIn error $e');
    }
  }

  /// Call on logout so RevenueCat doesn’t attribute next purchaser to previous user.
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('RevenueCat: logOut error $e');
    }
  }

  String get entitlementId => _entitlementId;
}
```

**Important:** Replace `test_bvEOhrZwfzRusfKcJYIFzYghpCK` with your **live** iOS API key in production. Use a flavor or environment config so test vs live is not hardcoded.

---

## 5. Entitlement: ARC Pro

- In RevenueCat Dashboard: **Product Setup → Entitlements** → create an entitlement with identifier **`ARC Pro`**.
- Attach your products (monthly, yearly, lifetime) to this entitlement so any of them unlocks **ARC Pro**.

In code, always use the same identifier:

```dart
const String entitlementId = 'ARC Pro';
```

---

## 6. Products: Monthly, Yearly, Lifetime

- In **App Store Connect**: create three in-app products (e.g. auto-renewable subscriptions for monthly/yearly, non-consumable or non-renewing for lifetime, per Apple’s rules).
- In **RevenueCat**: **Product Setup → Products** → add these products and link them to the **ARC Pro** entitlement.
- Use **Offerings** to group them for the paywall (e.g. default offering with packages `monthly`, `yearly`, `lifetime`).

Product identifiers (must match App Store Connect and RevenueCat):

- `monthly` – monthly subscription  
- `yearly` – yearly subscription  
- `lifetime` – lifetime (non-consumable / non-renewing)

---

## 7. Subscription functionality and entitlement checking

**Check if the user has ARC Pro:**

```dart
Future<bool> hasArcProAccess() async {
  try {
    final customerInfo = await Purchases.getCustomerInfo();
    final hasAccess = customerInfo.entitlements.all['ARC Pro']?.isActive ?? false;
    return hasAccess;
  } catch (e) {
    debugPrint('RevenueCat: getCustomerInfo error $e');
    return false;
  }
}
```

**Stream of customer info (e.g. for reactive UI):**

```dart
Stream<CustomerInfo> get customerInfoStream => Purchases.getCustomerInfo().asStream();
// Prefer Purchases.addCustomerInfoUpdateListener for continuous updates (see below).
```

**Listen for customer info updates (recommended):**

```dart
void addCustomerInfoUpdateListener(void Function(CustomerInfo) listener) {
  Purchases.addCustomerInfoUpdateListener(listener);
}
```

Use this to refresh your “premium” state whenever RevenueCat updates (e.g. after purchase or restore).

---

## 8. Present RevenueCat Paywall

Use **RevenueCat UI** to show the paywall (configured in RevenueCat dashboard).

**Show paywall once (e.g. from a “Upgrade” button):**

```dart
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

Future<void> presentPaywall(BuildContext context) async {
  try {
    await RevenueCatUI.presentPaywall();
  } catch (e) {
    debugPrint('RevenueCat: presentPaywall error $e');
    // Fallback: e.g. show in-app message or navigate to subscription screen
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load paywall: $e')),
      );
    }
  }
}
```

**Show paywall only when user doesn’t have ARC Pro (e.g. before a premium feature):**

```dart
Future<bool> presentPaywallIfNeeded(BuildContext context) async {
  try {
    return await RevenueCatUI.presentPaywallIfNeeded(
      requiredEntitlementIdentifier: RevenueCatService.instance.entitlementId,
    );
  } catch (e) {
    debugPrint('RevenueCat: presentPaywallIfNeeded error $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load paywall: $e')),
      );
    }
    return false;
  }
}
```

- **Docs:** [Paywalls](https://www.revenuecat.com/docs/tools/paywalls)  
- Design and copy are managed in the RevenueCat dashboard (Paywalls).

---

## 9. Customer Center

Let users manage subscription and restore purchases in-app:

```dart
Future<void> presentCustomerCenter(BuildContext context) async {
  try {
    await RevenueCatUI.presentCustomerCenter();
  } catch (e) {
    debugPrint('RevenueCat: presentCustomerCenter error $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open customer center: $e')),
      );
    }
  }
}
```

Use this from **Settings** or **Subscription Management** (e.g. “Manage subscription” for IAP users). For web/Stripe users, keep using your existing Stripe Customer Portal.

- **Docs:** [Customer Center (Flutter)](https://www.revenuecat.com/docs/tools/customer-center/customer-center-flutter)

---

## 10. Customer info and purchases

**Get latest customer info:**

```dart
Future<CustomerInfo?> getCustomerInfo() async {
  try {
    return await Purchases.getCustomerInfo();
  } catch (e) {
    debugPrint('RevenueCat: getCustomerInfo $e');
    return null;
  }
}
```

**Inspect entitlements and active subscriptions:**

```dart
final info = await Purchases.getCustomerInfo();
final arcPro = info.entitlements.all['ARC Pro'];
if (arcPro != null && arcPro.isActive) {
  // Product ID, expiration, etc.
  final productId = arcPro.productIdentifier;
  final expiration = arcPro.expirationDate;
}
```

**Restore purchases** (e.g. from Customer Center or a “Restore” button):

```dart
Future<void> restorePurchases() async {
  try {
    final customerInfo = await Purchases.restorePurchases();
    final hasPro = customerInfo.entitlements.all['ARC Pro']?.isActive ?? false;
    if (hasPro) {
      // Refresh UI / clear cache
    }
  } catch (e) {
    debugPrint('RevenueCat: restorePurchases $e');
    rethrow;
  }
}
```

---

## 11. Error handling and best practices

- **Use `PurchasesErrorException`** from `purchases_flutter` to detect purchase/user errors and avoid exposing internal messages.
- **Never log or send raw API keys**; use public SDK keys only; keep secret keys server-side if you add webhooks/backend.
- **User identity:** Call `Purchases.logIn(firebaseUid)` after sign-in and `Purchases.logOut()` on sign-out so RevenueCat aligns with your auth.
- **Offline:** RevenueCat caches entitlements; your app can rely on last `CustomerInfo` until the next update.
- **Subscription management:** Prefer **Customer Center** for cancel/change subscription (App Store rules) instead of custom flows.
- **Testing:** Use sandbox Apple IDs and RevenueCat test API key; switch to live key and production App Store for release.

**Example error handling:**

```dart
import 'package:purchases_flutter/purchases_flutter.dart';

void handleRevenueCatError(dynamic e) {
  if (e is PurchasesErrorException) {
    debugPrint('RevenueCat error: ${e.message} (${e.code})');
    // Map to user-friendly message
  } else {
    debugPrint('RevenueCat error: $e');
  }
}
```

---

## 12. Unify with Stripe (SubscriptionService)

Your app already has `SubscriptionService` that uses Firebase/Stripe for web. To treat **either** Stripe **or** RevenueCat as “premium”:

1. **Option A – In `SubscriptionService.getSubscriptionTier()`:**  
   - First call Firebase (Stripe) as today.  
   - If tier is not premium, on **iOS** (and Android when you add it), call `RevenueCatService.instance.hasArcProAccess()`.  
   - If either is true, return `SubscriptionTier.premium`.

2. **Option B – Dedicated helper:**  
   - Add e.g. `SubscriptionService.hasPremiumAccessAnySource()` that returns true if Stripe says premium **or** RevenueCat entitles **ARC Pro**.

3. **Cache:** When you refresh RevenueCat (e.g. after purchase/restore), call `SubscriptionService.instance.clearCache()` so the next `getSubscriptionTier()` re-evaluates both sources.

4. **UI:**  
   - **Web/Stripe:** Keep “Subscribe” opening Stripe Checkout and “Manage” opening Stripe Customer Portal.  
   - **In-app:** Use “Upgrade” → RevenueCat paywall and “Manage subscription” → RevenueCat Customer Center (or App Store subscription management).

---

## 13. Optional: Native iOS (SwiftUI + SPM)

If you ever add a **native iOS-only** target (SwiftUI) and want RevenueCat there without Flutter:

### 13.1 Add Swift Package

1. In Xcode: **File → Add Package Dependencies...**
2. URL: `https://github.com/RevenueCat/purchases-ios-spm.git`
3. Rule: “Up to next major” (e.g. `5.0.0` .. `< 6.0.0`)
4. Add **RevenueCat** and **RevenueCatUI** to your app target.

### 13.2 Configure (e.g. in `@main` App or AppDelegate)

```swift
import RevenueCat

// At app launch
Purchases.logLevel = .debug // only for debug
Purchases.configure(withAPIKey: "test_bvEOhrZwfzRusfKcJYIFzYghpCK")
```

### 13.3 Entitlement check (ARC Pro)

```swift
Purchases.shared.getCustomerInfo { customerInfo, error in
    let hasPro = customerInfo?.entitlements["ARC Pro"]?.isActive ?? false
}
```

### 13.4 Present Paywall (SwiftUI)

```swift
import RevenueCatUI

// Present paywall
RevenueCatUI.presentPaywallIfNeeded(requiredEntitlementIdentifier: "ARC Pro")
// Or
RevenueCatUI.presentPaywall()
```

### 13.5 Customer Center

```swift
RevenueCatUI.presentCustomerCenter()
```

Use the same entitlement **ARC Pro** and product IDs (`monthly`, `yearly`, `lifetime`) in the RevenueCat dashboard for both Flutter and native iOS.

---

## 14. Dashboard: Offerings and product setup

1. **Products:** RevenueCat → **Product Setup → Products** → add products that match App Store Connect (e.g. `monthly`, `yearly`, `lifetime`) and attach them to entitlement **ARC Pro**.
2. **Offerings:** Create at least one **Offering** (e.g. “Default”) with **Packages** that reference these products; set as default if you use “current offering” in the paywall.
3. **Paywalls:** In **Paywalls**, design the paywall and attach the offering; the Flutter/RevenueCat UI will show it when you call `presentPaywall()` / `presentPaywallIfNeeded`.
4. **Customer Center:** Enable and optionally customize in the dashboard so `presentCustomerCenter()` works as expected.

---

## Summary

| Item | Value |
|------|--------|
| **Entitlement** | `ARC Pro` |
| **Products** | `monthly`, `yearly`, `lifetime` |
| **Flutter packages** | `purchases_flutter`, `purchases_ui_flutter` |
| **Configure** | `Purchases.configure(...)` with public iOS (and Android) API key |
| **Check access** | `CustomerInfo.entitlements.all['ARC Pro']?.isActive` |
| **Paywall** | `RevenueCatUI.presentPaywall()` or `presentPaywallIfNeeded(requiredEntitlementIdentifier: 'ARC Pro')` |
| **Customer Center** | `RevenueCatUI.presentCustomerCenter()` |
| **Stripe vs IAP** | Stripe = web; RevenueCat = in-app; treat user as premium if either grants access |

For payments clarification, see [PAYMENTS_CLARIFICATION.md](../PAYMENTS_CLARIFICATION.md). For Stripe (web), see [stripe/README.md](../stripe/README.md).
