# OAuth Configuration Guide

**Last Updated:** December 6, 2025  
**Priority:** 1.5  
**Status:** Configuration Required

---

## Overview

This guide provides step-by-step instructions for configuring OAuth authentication for EPI MVP. OAuth integration is critical for:

1. **Google Sign-In** - User authentication via Google accounts
2. **Stripe Payments** - Subscription management for Premium tier (\$30/month)

---

## Part 1: Google OAuth Configuration

### Prerequisites

- Firebase project set up (`arc-epi`)
- iOS app registered with bundle ID: `com.epi.arcmvp`
- Android app registered
- Access to Firebase Console

### Step 1: Enable Google Sign-In in Firebase

1. **Open Firebase Console**
   - Navigate to: https://console.firebase.google.com
   - Select project: `arc-epi`

2. **Go to Authentication Settings**
   - Click "Authentication" in left sidebar
   - Click "Sign-in method" tab
   - Find "Google" provider in the list

3. **Enable Google Provider**
   - Click on "Google" provider
   - Toggle "Enable" switch to ON
   - Provide support email (your email address)
   - Click "Save"

### Step 2: Configure iOS OAuth Client

1. **In Firebase Console → Authentication → Sign-in method → Google**
   - Under "iOS Client ID" section
   - Click "Configure OAuth client ID"

2. **Create iOS OAuth 2.0 Client ID**
   - Go to Google Cloud Console: https://console.cloud.google.com
   - Select project: `arc-epi`
   - Navigate to: APIs & Services → Credentials
   - Click "+ CREATE CREDENTIALS"
   - Select "OAuth 2.0 Client ID"

3. **Configure iOS Client**
   - Application type: **iOS**
   - Name: `EPI iOS Client`
   - Bundle ID: `com.epi.arcmvp`
   - Click "CREATE"

4. **Note Your Client ID**
   - Copy the **Client ID** (format: `xxxxx.apps.googleusercontent.com`)
   - Keep this for the next step

### Step 3: Download Updated GoogleService-Info.plist

1. **In Firebase Console**
   - Go to Project Settings (gear icon)
   - Select your iOS app
   - Scroll down to "Your apps" section
   - Click the iOS app (`com.epi.arcmvp`)

2. **Download Configuration File**
   - Click "GoogleService-Info.plist" download button
   - **Important:** This new file will now include:
     - `CLIENT_ID` - For Google Sign-In
     - `REVERSED_CLIENT_ID` - URL scheme for OAuth callback

3. **Replace Existing File**
   ```bash
   # Navigate to iOS project directory
   cd "ARC MVP/EPI/ios/Runner"
   
   # Backup existing file
   mv GoogleService-Info.plist GoogleService-Info.plist.backup
   
   # Copy new file
   cp ~/Downloads/GoogleService-Info.plist ./
   ```

4. **Verify File Contents**
   - Open the new `GoogleService-Info.plist`
   - Verify these keys exist:
     - `CLIENT_ID`
     - `REVERSED_CLIENT_ID`
     - `API_KEY`
     - `GCM_SENDER_ID`
     - `PROJECT_ID`
     - `BUNDLE_ID`

### Step 4: Configure URL Schemes in Xcode

1. **Open Xcode Project**
   ```bash
   cd "ARC MVP/EPI/ios"
   open Runner.xcworkspace
   ```

2. **Add URL Scheme**
   - Select "Runner" target
   - Go to "Info" tab
   - Expand "URL Types"
   - Click "+" to add new URL Type
   - **Identifier:** `com.googleusercontent.apps`
   - **URL Schemes:** Your `REVERSED_CLIENT_ID` value from plist
     - Format: `com.googleusercontent.apps.xxxxx-xxxxx`

3. **Save Changes**
   - Build and verify no errors

### Step 5: Enable Google Sign-In Button

1. **Update Sign-In Screen**
   - Location: `lib/ui/auth/sign_in_screen.dart`
   - Find the Google Sign-In button (currently disabled)

2. **Re-enable Button**
   ```dart
   ElevatedButton.icon(
     onPressed: () => _signInWithGoogle(), // Re-enable
     icon: const Icon(Icons.login),
     label: const Text('Sign in with Google'),
     style: ElevatedButton.styleFrom(
       backgroundColor: kcPrimaryColor,
       foregroundColor: Colors.white,
       // ... rest of styling
     ),
   )
   ```

3. **Test Google Sign-In**
   - Run app on physical device or simulator
   - Tap "Sign in with Google"
   - Should open Google account picker
   - Complete sign-in flow
   - Verify user is authenticated

### Step 6: Configure Android OAuth (Optional)

1. **Get SHA-1 Certificate Fingerprint**
   ```bash
   cd "ARC MVP/EPI/android"
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   - Copy SHA-1 fingerprint

2. **Add SHA-1 to Firebase**
   - Firebase Console → Project Settings
   - Select Android app
   - Click "Add fingerprint"
   - Paste SHA-1 fingerprint
   - Click "Save"

3. **Download google-services.json**
   - Download updated `google-services.json`
   - Replace file in `android/app/google-services.json`

---

## Part 2: Stripe Integration Configuration

### Prerequisites

- Stripe account created
- Firebase Functions deployed
- Backend functions ready (`createCheckoutSession`, `getUserSubscription`)

### Step 1: Create Stripe Account & Products

1. **Sign Up for Stripe**
   - Go to: https://dashboard.stripe.com/register
   - Complete registration

2. **Create Product**
   - Dashboard → Products → "+ Add product"
   - Name: `EPI Premium Subscription`
   - Description: `Full access to LUMARA AI, unlimited requests, and complete phase history`
   - Pricing: `$30.00 USD / month`
   - Billing period: `Monthly`
   - Click "Save product"

3. **Get Price ID**
   - After creating product, click on the pricing
   - Copy the **Price ID** (format: `price_xxxxx`)
   - Save this for Firebase Functions configuration

### Step 2: Configure Stripe API Keys

1. **Get API Keys**
   - Dashboard → Developers → API keys
   - **Publishable key** (starts with `pk_test_` or `pk_live_`)
   - **Secret key** (starts with `sk_test_` or `sk_live_`)

2. **Store Secret Key in Firebase**
   ```bash
   cd "ARCv.04"
   firebase functions:secrets:set STRIPE_SECRET_KEY
   # Paste your secret key when prompted
   ```

3. **Update Firebase Functions**
   - Edit `functions/src/functions/createCheckoutSession.ts`
   - Update the price ID:
   ```typescript
   const priceId = data.priceId || 'price_YOUR_ACTUAL_PRICE_ID';
   ```

### Step 3: Configure Stripe Webhook

1. **Create Webhook in Stripe Dashboard**
   - Dashboard → Developers → Webhooks
   - Click "+ Add endpoint"
   - Endpoint URL: `https://us-central1-arc-epi.cloudfunctions.net/stripeWebhook`
   - Select events to listen to:
     - `checkout.session.completed`
     - `invoice.payment_succeeded`
     - `invoice.payment_failed`
     - `customer.subscription.deleted`
   - Click "Add endpoint"

2. **Get Webhook Secret**
   - After creating webhook, click on it
   - Click "Reveal" under "Signing secret"
   - Copy the webhook secret (starts with `whsec_`)

3. **Store Webhook Secret in Firebase**
   ```bash
   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
   # Paste your webhook secret when prompted
   ```

### Step 4: Initialize Stripe in Firebase Functions

1. **Install Stripe Package**
   ```bash
   cd functions
   npm install stripe
   ```

2. **Update createCheckoutSession.ts**
   ```typescript
   import Stripe from 'stripe';
   import { defineSecret } from 'firebase-functions/params';
   
   const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
   
   export const createCheckoutSession = onCall(
     { secrets: [stripeSecretKey] },
     async (request) => {
       const stripe = new Stripe(stripeSecretKey.value(), {
         apiVersion: '2023-10-16',
       });
       
       // ... rest of implementation
     }
   );
   ```

3. **Deploy Updated Functions**
   ```bash
   cd "ARCv.04"
   firebase deploy --only functions
   ```

### Step 5: Test Stripe Integration

1. **Use Test Mode**
   - Ensure you're in Stripe test mode (toggle in top-right)
   - Use test card: `4242 4242 4242 4242`
   - Any future expiry date
   - Any 3-digit CVC

2. **Test Checkout Flow**
   - Run EPI app
   - Go to Settings → Subscription
   - Tap "Upgrade to Premium"
   - Complete checkout with test card
   - Verify subscription is activated

3. **Verify in Firebase**
   - Check Firestore → `users` collection
   - User document should have:
     - `plan: "premium"`
     - `stripeSubscriptionId: "sub_xxxxx"`

---

## Part 3: Testing & Verification

### Test Google OAuth

1. **Sign In Flow**
   ```bash
   # Clean build
   cd "ARC MVP/EPI"
   flutter clean && flutter pub get
   flutter run -d <device-id>
   ```

2. **Test Cases**
   - ✅ Tap "Sign in with Google"
   - ✅ Google account picker appears
   - ✅ Select account
   - ✅ App receives authentication token
   - ✅ User navigated to main app screen
   - ✅ Sign out and sign in again (should work)

### Test Subscription System

1. **Free Tier Limits**
   - Sign in with new account
   - Verify LUMARA shows "Free" tier badge
   - Make 20 LUMARA requests in one day
   - Verify 21st request is blocked
   - Check error message about rate limit

2. **Premium Upgrade**
   - Go to Settings → Subscription
   - Tap "Upgrade to Premium"
   - Complete Stripe checkout (test mode)
   - Return to app
   - Verify tier badge shows "Premium"
   - Make 25+ LUMARA requests
   - Verify no rate limiting

3. **Phase History Access**
   - As free user: Create entries over 40 days
   - Verify only last 30 days visible in phase history
   - Upgrade to Premium
   - Verify all 40 days now accessible

### Verify Backend Integration

1. **Check Firebase Functions Logs**
   ```bash
   firebase functions:log --only getUserSubscription,createCheckoutSession
   ```

2. **Test Rate Limiting**
   - Use Firebase Emulator for local testing:
   ```bash
   firebase emulators:start --only functions
   ```
   - Make rapid API calls
   - Verify rate limiting enforced

---

## Troubleshooting

### Google Sign-In Issues

**Problem:** "CLIENT_ID not found" error
- **Solution:** Verify `GoogleService-Info.plist` contains `CLIENT_ID` key
- Download fresh plist from Firebase Console

**Problem:** "Invalid client" error
- **Solution:** Verify Bundle ID matches in:
  - Xcode project
  - Firebase Console
  - Google Cloud Console OAuth client

**Problem:** "Redirect URI mismatch"
- **Solution:** Verify `REVERSED_CLIENT_ID` is added to URL schemes in Xcode

### Stripe Issues

**Problem:** Checkout session not creating
- **Solution:** 
  - Check Firebase Functions logs
  - Verify STRIPE_SECRET_KEY is set
  - Ensure user is authenticated

**Problem:** Webhook not receiving events
- **Solution:**
  - Verify webhook URL is correct
  - Check webhook signing secret
  - Review Stripe Dashboard → Developers → Webhooks → Recent deliveries

**Problem:** Subscription not updating in Firestore
- **Solution:**
  - Check stripeWebhook function logs
  - Verify Firestore rules allow writes
  - Manually trigger webhook in Stripe Dashboard

### Backend Issues

**Problem:** Rate limiting not working
- **Solution:**
  - Check user document has `plan` field
  - Verify getUserSubscription function returns correct tier
  - Review Firebase Functions logs

**Problem:** Phase history still showing all entries for free tier
- **Solution:**
  - Verify `PhaseHistoryAccessControl` is being used instead of direct repository calls
  - Check subscription service returns correct tier

---

## Security Checklist

Before going to production:

- [ ] Switch Stripe from test mode to live mode
- [ ] Update Stripe API keys to live keys
- [ ] Use production GoogleService-Info.plist
- [ ] Review Firebase security rules
- [ ] Test all OAuth flows with production credentials
- [ ] Enable Firebase App Check for additional security
- [ ] Set up monitoring and alerting for auth failures
- [ ] Review and test subscription cancellation flow
- [ ] Implement proper error handling for payment failures
- [ ] Add logging for security events

---

## Additional Resources

- [Firebase Authentication Docs](https://firebase.google.com/docs/auth)
- [Google Sign-In iOS Guide](https://developers.google.com/identity/sign-in/ios)
- [Stripe Subscriptions Guide](https://stripe.com/docs/billing/subscriptions/overview)
- [Firebase Functions Secrets](https://firebase.google.com/docs/functions/config-env#secret-manager)

---

**Configuration Status:** ⏳ Pending Setup  
**Estimated Setup Time:** 45-60 minutes  
**Priority:** High - Required for Priority 1.5 completion

