# RevenueCat Setup Checklist – ARC App (iOS)

**Last Updated:** March 10, 2026

Use this checklist to set up RevenueCat so in-app purchases work and **Error 23** is resolved. Order matters: do **App Store Connect** first, then **RevenueCat**, then the app.

---

## Values used by the app (do not change unless you update code)

| Item | Value |
|------|--------|
| **Bundle ID** | `com.epi.arcmvp` |
| **Entitlement** | `ARC Pro` |
| **Product IDs** | `monthly`, `yearly`, `lifetime` |

---

## Part 1: App Store Connect

1. **Sign in:** [App Store Connect](https://appstoreconnect.apple.com) → your app (or create an app with bundle ID `com.epi.arcmvp`).

2. **Agreements, Tax, and Banking**
   - Go to **Agreements, Tax, and Banking** (under your account/team).
   - Complete **Paid Apps** agreement and **Banking** and **Tax** if not already done. Without this, in-app products cannot be sold.

3. **Create a Subscription Group** (for monthly/yearly)
   - In your app → **Subscriptions** (or **In-App Purchases**).
   - Create a **Subscription Group** (e.g. "ARC Pro").
   - Inside that group, create two **auto-renewable subscriptions**:
     - **Product ID:** `monthly` (e.g. $20/month).
     - **Product ID:** `yearly` (e.g. $200/year).
   - Set reference name, duration, price; submit for review when ready. Products must be in **Ready to Submit** (or approved) for RevenueCat to fetch them.

4. **Create a non-consumable (lifetime)**  
   - **In-App Purchases** → **Manage** → add **Non-Consumable** (or non-renewing subscription, per Apple’s rules).
   - **Product ID:** `lifetime`.
   - Configure price and submit.

5. **Note exact Product IDs**  
   They must be exactly: `monthly`, `yearly`, `lifetime` (same in RevenueCat and in the app).

---

## Part 2: RevenueCat Dashboard

1. **Account & project**
   - Sign up / sign in at [RevenueCat](https://www.revenuecat.com).
   - Create a **Project** (e.g. "ARC") if you don’t have one.

2. **Add iOS app**
   - In the project: **Apps** → **+ New**.
   - **Platform:** Apple App Store.
   - **App name:** e.g. "ARC" or your app name.
   - **Bundle ID:** `com.epi.arcmvp` (must match Xcode).
   - **App Store Connect API Key (optional but recommended):** In App Store Connect → Users and Access → Keys → create an key with **App Manager** role; in RevenueCat paste the Key ID, Issuer ID, and the `.p8` private key so RevenueCat can validate receipts.

3. **Entitlement**
   - **Product Setup** → **Entitlements** → **+ New**.
   - **Identifier:** `ARC Pro` (exactly; the app checks this).

4. **Products**
   - **Product Setup** → **Products** → **+ New** for each:
     - **Identifier:** `monthly` → attach to entitlement **ARC Pro**.
     - **Identifier:** `yearly` → attach to entitlement **ARC Pro**.
     - **Identifier:** `lifetime` → attach to entitlement **ARC Pro**.
   - Identifiers must match App Store Connect exactly.

5. **Offerings**
   - **Offerings** → **+ New Offering** (e.g. "Default").
   - Add **Packages** that reference the products:
     - Package identifier: e.g. `monthly` → product `monthly`.
     - Package identifier: e.g. `yearly` → product `yearly`.
     - Package identifier: e.g. `lifetime` → product `lifetime`.
   - Set this offering as **Current** (default).

6. **Paywall**
   - **Paywalls** → create or edit a paywall.
   - Attach the **Current** offering so the paywall shows monthly/yearly/lifetime.
   - Design layout and copy; save.

7. **Customer Center** (optional)
   - **Customer Center** → enable so “Manage subscription” and “Restore” work from the app.

8. **API keys**
   - **Project Settings** → **API Keys**.
   - Copy the **Public iOS** key (use **Sandbox** for testing, **Production** for release).
   - You’ll put this in the app (see Part 3).

---

## Part 3: App (Xcode / Flutter)

1. **In-App Purchase capability**
   - In Xcode: open `ios/Runner.xcworkspace` → select **Runner** target → **Signing & Capabilities**.
   - Click **+ Capability** → add **In-App Purchase**. Save.

2. **RevenueCat API key in the app**
   - Open `lib/services/revenuecat_service.dart`.
   - For **testing:** you can keep the test key `test_bvEOhrZwfzRusfKcJYIFzYghpCK` if your RevenueCat project is the one that has this key and has the same products/offerings.
   - For **production:** replace with your **live** iOS API key from RevenueCat (Project Settings → API Keys → Public iOS key for production).
   - Example: add a constant and use it in `Purchases.configure(...)`:
     - `const String kRevenueCatIosApiKeyLive = 'appl_xxxxxxxxxxxx';`
     - Use the live key for release builds (e.g. via flavor or `kReleaseMode`).

3. **Run and test**
   - Use a **Sandbox** Apple ID (App Store Connect → Users and Access → Sandbox → Testers) on device or simulator.
   - In the app: **Settings → Subscription & Account → Subscription Management** → tap **Continue with Annual** (or Monthly). The RevenueCat paywall should open; no **Error 23** if App Store Connect and RevenueCat match.

---

## Quick verification

- **Error 23** = “None of the products registered in RevenueCat could be fetched from App Store Connect.”
- Checklist:
  - [ ] App Store Connect: Agreements/Tax/Banking complete.
  - [ ] App Store Connect: Products `monthly`, `yearly`, `lifetime` exist and are Ready to Submit or approved.
  - [ ] RevenueCat: App added with bundle ID `com.epi.arcmvp`.
  - [ ] RevenueCat: Entitlement `ARC Pro` and products `monthly`, `yearly`, `lifetime` linked to it.
  - [ ] RevenueCat: Current offering has packages for those products.
  - [ ] RevenueCat: Paywall uses that offering.
  - [ ] App: In-App Purchase capability enabled in Xcode.
  - [ ] App: Correct RevenueCat API key in `revenuecat_service.dart` (live for production).

---

## Links

- [RevenueCat: Why are offerings empty?](https://rev.cat/why-are-offerings-empty)
- [RevenueCat Flutter SDK](https://www.revenuecat.com/docs/getting-started/installation/flutter)
- [Full integration guide](REVENUECAT_INTEGRATION.md)
