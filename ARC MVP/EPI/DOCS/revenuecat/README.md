# RevenueCat (In-App Purchases) Documentation

**Last Updated:** February 7, 2026

---

## Overview

RevenueCat powers **in-app purchases** for ARC on iOS (and optionally Android). Stripe is used for **web** purchases. See [stripe/README.md](../stripe/README.md) for web payments.

---

## Documentation Index

1. **[REVENUECAT_INTEGRATION.md](REVENUECAT_INTEGRATION.md)** – Full integration guide
   - Flutter SDK installation (`purchases_flutter` + `purchases_ui_flutter`)
   - Configuration with API key and entitlement **ARC Pro**
   - Products: Monthly, Yearly, Lifetime
   - Paywall and Customer Center
   - Customer info, error handling, and best practices
   - Optional: Native iOS SwiftUI + Swift Package Manager
   - Unifying with existing `SubscriptionService` (Stripe + RevenueCat = premium)

---

## Quick reference

- **Entitlement:** `ARC Pro`
- **Products (identifiers):** `monthly`, `yearly`, `lifetime`
- **Test API key (iOS):** `test_bvEOhrZwfzRusfKcJYIFzYghpCK` (replace with live key for production)
- **Docs:** [RevenueCat Flutter](https://www.revenuecat.com/docs/getting-started/installation/flutter) · [Paywalls](https://www.revenuecat.com/docs/tools/paywalls) · [Customer Center](https://www.revenuecat.com/docs/tools/customer-center)
