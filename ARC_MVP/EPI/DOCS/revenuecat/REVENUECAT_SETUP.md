# RevenueCat setup – step-by-step

**Last Updated:** March 2026

This guide gets you from zero to a working in-app paywall on iOS. Your app already has the SDK and calls in place; you only need to create the project, products, and paste your API keys.

---

## Checklist (high level)

1. [x] Create RevenueCat account and project  
2. [ ] Add your iOS app in RevenueCat (bundle ID `com.epi.arcmvp`)  
3. [ ] Create subscription products in **App Store Connect**  
4. [ ] Create entitlement and products in **RevenueCat**  
5. [ ] Create an Offering and a Paywall in RevenueCat  
6. [ ] Paste **Sandbox** and **Live** API keys into the app  
7. [ ] Test on a real device with a Sandbox Apple ID  

---

## Step 1: RevenueCat account and project

1. Go to [revenuecat.com](https://www.revenuecat.com) and sign up (or log in).  
2. Create a **Project** (e.g. “LUMARA” or “ARC”).  
3. You’ll add the iOS app and products in the next steps.

---

## Step 2: Add your iOS app in RevenueCat

1. In RevenueCat: **Project Settings** (or **Apps**) → **+ New App**.  
2. Choose **Apple App Store**.  
3. **Bundle ID:** `com.epi.arcmvp` (must match your Xcode project).  
4. **App name:** e.g. LUMARA.  
5. **App Store Connect API Key (optional but recommended):**  
   - In **App Store Connect** → **Users and Access** → **Keys** → **In-App Purchase**, create a key with **App Manager** or **Admin** role.  
   - Download the `.p8` file once (you can’t download it again).  
   - In RevenueCat, upload the `.p8`, and enter **Key ID**, **Issuer ID**, and **Bundle ID**.  
   - This lets RevenueCat validate receipts without a shared secret.  
6. **Shared Secret (alternative):** If you don’t use the App Store Connect API key, you can use the **App-Specific Shared Secret** from App Store Connect → Your App → App Information → App-Specific Shared Secret. Enter it in RevenueCat when prompted.  
7. Save. RevenueCat will show **Public API Keys** for this app (Sandbox and Production). You’ll paste these into the app in Step 6.

---

## Step 3: Create subscription products in App Store Connect

1. In **App Store Connect** → your app (e.g. LUMARA) → **Features** → **In-App Purchases**.  
2. **Subscription Group:**  
   - Create a group (e.g. “Premium” or “LUMARA Premium”).  
   - You’ll attach all subscription products to this group.  
3. **Subscriptions:**  
   - Create at least two auto-renewable subscriptions (e.g. **Monthly** and **Annual**).  
   - **Reference name:** e.g. “LUMARA Monthly”, “LUMARA Annual” (for your eyes only).  
   - **Product ID:** must match what you’ll use in RevenueCat. Recommended:  
     - `monthly` (or e.g. `com.epi.arcmvp.premium.monthly`)  
     - `yearly` (or e.g. `com.epi.arcmvp.premium.yearly`)  
   - Set price, duration (1 month / 1 year), and localizations.  
   - Submit for review with your app (products are reviewed with the app).  
4. **Optional:** A non-consumable “Lifetime” product: Product ID e.g. `lifetime` if you want a one-time purchase.  
5. Write down the **exact Product IDs**; you’ll enter them in RevenueCat in Step 4.

---

## Step 4: Entitlement and products in RevenueCat

1. **Entitlement**  
   - RevenueCat → **Product Setup** → **Entitlements** → **+ New**.  
   - Identifier: **`ARC Pro`** (must be exactly this; the app uses this id).  
   - Save.  

2. **Products**  
   - **Product Setup** → **Products** → **+ New**.  
   - For each App Store product, add a product:  
     - **Identifier:** same as App Store Connect (e.g. `monthly`, `yearly`, or your `com.epi.arcmvp.premium.monthly`).  
     - **Store:** App Store.  
     - **Attach to entitlement:** **ARC Pro**.  
   - Save each.  

3. Products attached to **ARC Pro** will unlock premium in the app when purchased.

---

## Step 5: Offering and Paywall in RevenueCat

1. **Offering**  
   - **Product Setup** → **Offerings** → **+ New** (or use **Default**).  
   - Create packages that reference your products, e.g.:  
     - Package identifier: `monthly` → product `monthly`  
     - Package identifier: `yearly` → product `yearly`  
   - Set this offering as **Current** (default) so `RevenueCatUI.presentPaywall()` uses it.  

2. **Paywall**  
   - **Paywalls** → **+ New** (or use default).  
   - Attach the **Offering** you created.  
   - Design the paywall (title, buttons, pricing).  
   - The app calls `RevenueCatUI.presentPaywall()` and RevenueCat will show this paywall.  

3. **Customer Center**  
   - **Customer Center** → enable it so “Manage subscription” and “Restore” work in the app.

---

## Step 6: Paste API keys into the app

1. In RevenueCat → **Project Settings** → **API Keys** (or your app → API Keys).  
2. Copy:  
   - **Public iOS Sandbox** key (starts with `appl_` or `test_` – use for debug/dev).  
   - **Public iOS** (Production) key (for release builds).  

3. In the repo, open **`lib/services/revenuecat_service.dart`**.  

4. Replace the placeholders:  
   - **Sandbox (debug):** set `kRevenueCatIosApiKeyTest` to your **Public iOS Sandbox** key.  
   - **Production (release):** set `kRevenueCatIosApiKeyLive` to your **Public iOS** (Production) key.  

   The app uses the test key when not in release mode and the live key in release mode.

5. Save the file. Do not commit real production keys to a public repo; use environment variables or a private config if you prefer (see [REVENUECAT_INTEGRATION.md](REVENUECAT_INTEGRATION.md)).

---

## Step 7: Test on a real device

1. **Sandbox Apple ID**  
   - In **App Store Connect** → **Users and Access** → **Sandbox** → **Testers**, create a Sandbox tester account.  
   - On your iPhone: **Settings → App Store → Sandbox Account** and sign in with that tester (only for testing IAP).  

2. **Run the app**  
   - Build and run on a **real device** (simulator can’t complete real IAP).  
   - Sign in with your normal Firebase/Google sign-in.  

3. **Open the paywall**  
   - Go to **Settings → Subscription & Account → Subscription Management** and tap **Continue with Annual** (or Monthly).  
   - You should see the RevenueCat paywall (not Stripe).  
   - Complete a test purchase with the Sandbox account; the subscription should unlock **ARC Pro** in the app.  

4. If you see “offerings not available” or “configuration” errors, double-check:  
   - Bundle ID in RevenueCat matches `com.epi.arcmvp`.  
   - Product IDs in RevenueCat match App Store Connect exactly.  
   - App Store Connect products are in “Ready to Submit” (and the app is submitted so they’re available).  
   - You’re using the **Sandbox** API key when running in debug.

---

## Troubleshooting: "RevenueCat screen isn't connecting"

When the paywall doesn't show or the app falls through to Stripe, check in this order:

1. **API key is from your LUMARA project**  
   The app must use the **Public iOS Sandbox** key from **your** RevenueCat project (LUMARA), not a sample key.  
   - RevenueCat → **API keys** (sidebar) → copy **Public iOS Sandbox**.  
   - In code: `lib/services/revenuecat_service.dart` → set `kRevenueCatIosApiKeyTest` to that value.  
   - If you never replaced the placeholder, the app is talking to the wrong project and won't see your offering/paywall.

2. **Offerings and paywall in RevenueCat**  
   - **Product catalog**: Entitlement **ARC Pro** exists; products attached to it.  
   - **Build / Offerings**: One offering with packages, set as **Current**.  
   - **Paywalls**: Paywall created, attached to that offering, and **published**.

3. **Product IDs match**  
   - App Store Connect product IDs must match exactly what you added in RevenueCat.

4. **Bundle ID**  
   - RevenueCat app must have bundle ID **`com.epi.arcmvp`**.

5. **Real device + Sandbox**  
   - Test on a **real device**. Device: **Settings → App Store → Sandbox Account** → sign in with Sandbox tester.

6. **User signed in**  
   - Be signed in (Firebase) so RevenueCat gets a user ID at startup.

7. **Console**  
   - Run from Xcode and watch for `RevenueCat: Configured (iOS)` and any RevenueCat errors when you tap upgrade.

---

## Summary

| What | Where |
|------|--------|
| Bundle ID | `com.epi.arcmvp` |
| Entitlement ID | `ARC Pro` |
| Product IDs (example) | `monthly`, `yearly` (must match App Store Connect) |
| API keys | `lib/services/revenuecat_service.dart` → `kRevenueCatIosApiKeyTest` and `kRevenueCatIosApiKeyLive` |
| Configure / logIn | Already done in `bootstrap.dart` and `firebase_auth_service.dart` |

For more detail (Flutter API, Stripe vs IAP, error handling), see [REVENUECAT_INTEGRATION.md](REVENUECAT_INTEGRATION.md).
