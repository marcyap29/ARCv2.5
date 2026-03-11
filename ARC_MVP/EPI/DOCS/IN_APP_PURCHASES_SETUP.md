# In-App Purchases and Subscription Setup

**Last Updated:** March 10, 2026

---

## 1. Where do users go for in-app purchases (Apple Store)?

The app **already sends users to Apple in-app purchase** on iOS:

- **Path:** **Settings → Subscription & Account → Subscription Management** → tap **Continue with Annual** (or Monthly).
- On **iOS**, that flow uses **RevenueCat** (Apple StoreKit). The paywall and purchase sheet are the standard Apple in-app purchase experience.
- You do **not** add a separate “Buy on App Store” section in the app. The “Subscription Management” screen is the entry point; the app chooses IAP on iOS and Stripe on web automatically.

**What you must do in App Store Connect and RevenueCat:**

1. **App Store Connect**
   - Create your app (if not already).
   - **App Store Connect → Your App → In-App Purchases** (or **Subscriptions**): create subscription products (e.g. monthly, annual) and a subscription group.
   - Use the same product identifiers you configure in RevenueCat (e.g. `monthly`, `yearly`).

2. **RevenueCat**
   - Create a project and link your iOS app (bundle ID, App Store Connect credentials).
   - Add products and map them to your **entitlement** (e.g. **ARC Pro**).
   - In the app, use the **live** RevenueCat API key for production (see `lib/services/revenuecat_service.dart`; replace the test key with your live key).

See **[DOCS/revenuecat/REVENUECAT_INTEGRATION.md](revenuecat/REVENUECAT_INTEGRATION.md)** for full setup.

---

## 2. “Error 23” or “issue with your configuration”

This message can come from **two places**:

### 2a. Error 23 from RevenueCat (In-App Purchase on iOS)

If the user sees **“Error 23: There is an issue with your configuration…”** when tapping **Continue with Annual/Monthly** on **iOS**, it is usually from **RevenueCat**, not Stripe. It means: **none of the products registered in the RevenueCat dashboard could be fetched from App Store Connect.**

**Fixes:**

1. **App Store Connect**
   - Ensure subscription (or IAP) products exist and use the **exact same product identifiers** as in RevenueCat (e.g. `monthly`, `yearly`, `lifetime`).
   - Products must be in a valid state (e.g. “Ready to Submit” or approved). Draft or missing products will cause this.
   - Complete **Agreements, Tax, and Banking** in App Store Connect if not already done.

2. **RevenueCat Dashboard**
   - **Product Setup → Products**: Add each product and link to the **ARC Pro** entitlement.
   - **Offerings**: Create an offering (e.g. “Default”) with packages that reference these products; set it as current.
   - Ensure the app’s **bundle ID** and **App Store Connect** integration are correct and the project uses the **live** iOS API key for production.

3. **In the app**
   - Use the **live** RevenueCat API key for production builds (see `lib/services/revenuecat_service.dart`). The test key may not have products/offerings configured for your App Store Connect app.

The app now shows a friendlier dialog (**“In-App Purchases Unavailable”**) when this configuration error is detected, and does not fall back to Stripe on iOS for this case.

See also: [RevenueCat – Why are offerings empty?](https://rev.cat/why-are-offerings-empty)

### 2b. Error 23 / configuration from Stripe (web or fallback)

If the error appears when using **Stripe** (web, or after RevenueCat is skipped), it comes from the **Stripe** path (Firebase Cloud Function `createCheckoutSession`).

- On iOS, the app tries **RevenueCat first**. If that fails or is not configured, it falls back to **Stripe**. So you may see a Stripe configuration error if RevenueCat failed and Stripe is also not configured.

**Fix:** Configure Stripe for the Cloud Function:

1. **Google Cloud Secret Manager** (or Firebase Functions config): set these secrets for the function that runs `createCheckoutSession`:
   - `STRIPE_SECRET_KEY`
   - `STRIPE_PRICE_ID_MONTHLY`
   - `STRIPE_PRICE_ID_ANNUAL`
   - `STRIPE_FOUNDER_PRICE_ID_UPFRONT` (if you use Founders)
2. Ensure the Cloud Function has access to read these secrets.
3. Redeploy the function.

See **[DOCS/stripe/README.md](stripe/README.md)** and the `functions/` Stripe setup for details.

The app now maps this backend “configuration” error to a user-friendly message: *“Subscription service is not properly configured. Please contact support.”*

---

## Summary

| Question | Answer |
|----------|--------|
| Where do users go for Apple in-app purchases? | **Settings → Subscription & Account → Subscription Management** → choose plan. On iOS this uses Apple IAP (RevenueCat). |
| Do I need to do something in App Store Connect? | Yes: create subscription products and subscription group, then link them in RevenueCat. |
| Why do I see “Error 23” / configuration error? | **On iOS:** Usually RevenueCat – products in RevenueCat must match App Store Connect; complete Apple agreements; use live RevenueCat API key. **From Stripe:** Backend Stripe secrets missing – configure and redeploy. See §2 above. |
