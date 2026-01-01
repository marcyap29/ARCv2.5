# Stripe Integration Analysis - EPI Flutter App

## Overview
This document provides a comprehensive analysis of the current Stripe integration in the EPI Flutter application, documenting the architecture, implementation status, and requirements for completing the payment system.

---

## 1. CURRENT STRIPE ARCHITECTURE

### File Structure
```
lib/
├── services/
│   ├── subscription_service.dart          # Core subscription management
│   ├── firebase_auth_service.dart         # Authentication integration
│   └── firebase_service.dart              # Firebase initialization
├── ui/subscription/
│   ├── subscription_management_view.dart  # Full subscription UI
│   └── lumara_subscription_status.dart    # Status widget
└── shared/ui/settings/
    └── settings_view.dart                 # Settings entry point

functions/lib/functions/
├── createCheckoutSession.js               # Stripe checkout creation
├── getUserSubscription.js                 # Subscription status retrieval
└── stripeWebhook.js                      # Webhook handler
```

### Subscription System
**Two-Tier Structure:**
- **Free Tier**: 50 LUMARA requests/day, 3/minute rate limit, limited phase history
- **Premium Tier**: Unlimited access, no rate limits, full phase history, $30/month

### Payment Flow Architecture
```
User Clicks Upgrade → SubscriptionService.createStripeCheckoutSession()
                  → Firebase Cloud Function: createCheckoutSession
                  → Stripe Checkout Session Created
                  → User Pays → Stripe Webhook
                  → Firebase Function: stripeWebhook
                  → Firestore User Document Updated
                  → Client Subscription Status Refreshed
```

---

## 2. IMPLEMENTATION STATUS

### ✅ **COMPLETED COMPONENTS**

#### Frontend (Flutter/Dart)
- **SubscriptionService**: Complete singleton with caching (5-minute TTL)
- **UI Components**: Full subscription management interface
- **Status Widget**: Compact and full views with tier badges
- **Settings Integration**: Navigation from Settings → Subscription
- **Rate Limiting**: Enforced for LUMARA chat (20/day, 3/min for free)
- **Feature Flags**: Subscription-based feature access control
- **Authentication**: Firebase Auth integration
- **Local Caching**: 24-hour offline fallback support

#### Backend (Cloud Functions)
- **getUserSubscription()**: Retrieves tier from Firestore
- **stripeWebhook()**: Handles all subscription webhook events
- **Database Schema**: Firestore user document structure
- **Auth Guards**: Function-level authentication enforcement
- **Admin System**: Privilege management

#### Database Schema (Firestore)
```javascript
users/{userId}: {
  subscriptionTier: "free" | "premium",
  subscriptionStatus: "active" | "canceled" | "trial",
  stripeCustomerId: "cus_XXXXX",
  stripeSubscriptionId: "sub_XXXXX",
  currentPeriodEnd: timestamp,
  lastCheckoutAttempt: timestamp,
  createdAt: timestamp
}
```

### 🚧 **INCOMPLETE/TODO ITEMS**

#### Critical Missing Components
1. **Real Stripe Integration**
   - Current: Mock implementation in `createCheckoutSession()`
   - Location: `functions/lib/functions/createCheckoutSession.js`
   - Status: Returns placeholder URL, no actual Stripe SDK usage

2. **Checkout URL Handling**
   - Issue: Generated checkout URL not opened in browser/webview
   - Location: `lib/services/subscription_service.dart:295`
   - Comment: `// TODO: Open checkout URL in webview or browser`

3. **Webhook Signature Verification**
   - Security Issue: Webhook events accepted without Stripe signature verification
   - Production Risk: Vulnerable to malicious webhook calls
   - Location: `functions/lib/functions/stripeWebhook.js`

4. **Subscription Cancellation**
   - UI: Cancel button exists but non-functional
   - Backend: Function defined but incomplete implementation
   - Missing: Actual Stripe subscription cancellation API calls

#### Functional Gaps
- No payment method management
- No billing history/invoice retrieval
- No payment failure handling
- No subscription pause/resume
- No pro-rating for mid-cycle changes
- No free trial implementation
- No renewal reminders

---

## 3. SUBSCRIPTION FEATURE INTEGRATION

### Rate Limiting System
**LUMARA Chat Integration:**
```dart
// File: lib/arc/chat/ui/lumara_assistant_screen.dart
SubscriptionFeatures features = await SubscriptionService.instance.getSubscriptionFeatures();

if (features.lumaraThrottled) {
  // Apply rate limits: 20/day, 3/minute
  // Show throttle warnings
} else {
  // Unlimited access for premium users
}
```

### Phase History Access Control
```dart
// File: lib/services/phase_history_access_control.dart
if (features.phaseHistoryRestricted) {
  // Free: Limited to recent phases
} else {
  // Premium: Full historical access
}
```

### Favorites Management
```dart
// Different limits based on subscription tier
// Free: 25 items per category
// Premium: Unlimited
```

---

## 4. CONFIGURATION REQUIREMENTS

### Firebase Setup Checklist
- [ ] **Stripe Secret Key** in Firebase Secret Manager
- [ ] **Stripe Webhook Secret** in Firebase Secret Manager
- [ ] **Cloud Functions** deployed to `us-central1`
- [ ] **Firestore Rules** configured for user documents

### Stripe Setup Checklist
- [ ] **Stripe Account** created
- [ ] **Product**: Premium Subscription created
- [ ] **Price ID**: `price_premium_monthly` ($30/month)
- [ ] **API Keys**: Publishable and Secret keys obtained
- [ ] **Webhook Endpoint**: `https://us-central1-arc-epi.cloudfunctions.net/stripeWebhook`
- [ ] **Webhook Events**:
  - `checkout.session.completed`
  - `invoice.payment_succeeded`
  - `invoice.payment_failed`
  - `customer.subscription.created`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`

### Dependencies Required
```yaml
# pubspec.yaml - Already included
firebase_core: ^3.11.0
cloud_firestore: ^5.6.3
firebase_auth: ^5.4.2
cloud_functions: ^5.1.3
url_launcher: ^6.3.1  # For opening checkout URLs
```

---

## 5. CURRENT PRICING STRUCTURE

| Feature | Free | Premium ($30/month) |
|---------|------|-------------------|
| LUMARA Requests | 50/day | Unlimited |
| Rate Limiting | 3/minute | None |
| Phase History | Limited | Full Access |
| Favorites Limit | 25/category | Unlimited |
| Support Level | Community | Priority |

**Price Configuration:**
- Hardcoded in UI: `lumara_subscription_status.dart:226`
- Stripe Price ID: `price_premium_monthly`
- Amount: $3000 cents = $30.00/month

---

## 6. INTEGRATION POINTS

### LUMARA AI Assistant
- **File**: `lib/arc/chat/ui/lumara_assistant_screen.dart`
- **Function**: Rate limiting based on subscription tier
- **Free Users**: Shows throttle warnings, enforces daily/minute limits
- **Premium Users**: Unlimited access, no rate limiting UI

### Settings Screen
- **File**: `lib/shared/ui/settings/settings_view.dart`
- **Navigation**: Settings → Subscription & Account → Subscription Management
- **Shows**: Current tier, usage stats, billing info

### Phase Data Access
- **File**: `lib/services/phase_history_access_control.dart`
- **Function**: Controls access to historical phase data
- **Free**: Recent phases only
- **Premium**: Full timeline access

---

## 7. ERROR HANDLING & EDGE CASES

### Current Limitations
- **Generic Error Messages**: No detailed Stripe error mapping
- **No Declined Card Handling**: Payment failures not gracefully handled
- **No Loading States**: UI doesn't show payment processing status
- **No Success Confirmation**: No payment confirmation flow
- **No Retry Logic**: Failed payments don't offer retry options

### Security Concerns
- **Webhook Verification**: Production deployment vulnerable without signature verification
- **API Key Exposure**: Need proper secrets management
- **Auth Bypass**: Ensure all payment functions properly authenticate users

---

## 8. NEXT STEPS FOR COMPLETION

### Phase 1: Core Payment Flow
1. **Implement Real Stripe SDK** in `createCheckoutSession.js`
2. **Add URL Launcher** to open checkout in browser/webview
3. **Webhook Signature Verification** for security
4. **End-to-end Testing** of payment flow

### Phase 2: Subscription Management
1. **Cancellation Flow** - Connect to Stripe API
2. **Payment Method Management** - Update cards, billing info
3. **Billing History** - Show invoices and receipts
4. **Error Handling** - Proper payment failure flows

### Phase 3: Enhanced Features
1. **Free Trial** implementation (7-14 days)
2. **Pro-rating** for mid-cycle changes
3. **Pause/Resume** subscriptions
4. **Multiple Payment Methods** backup options
5. **Renewal Reminders** and dunning management

---

## 9. TESTING STRATEGY

### Development Testing
- [ ] Stripe Test Mode setup with test cards
- [ ] Webhook testing with Stripe CLI
- [ ] Firebase Functions local emulation
- [ ] End-to-end payment simulation

### Production Testing
- [ ] Real Stripe account with live keys
- [ ] Webhook endpoint SSL verification
- [ ] Payment flow with real cards (small amounts)
- [ ] Subscription lifecycle testing (create → cancel → renew)

---

## 10. DEPLOYMENT CHECKLIST

### Pre-Production
- [ ] Stripe webhook endpoint configured and tested
- [ ] Firebase Secret Manager populated with API keys
- [ ] Cloud Functions deployed to production environment
- [ ] Firestore security rules updated for subscription data
- [ ] Rate limiting tested with real subscription tiers

### Production Launch
- [ ] Switch from Stripe Test Mode to Live Mode
- [ ] Monitor webhook delivery and error rates
- [ ] Set up Stripe Dashboard alerts for failed payments
- [ ] Configure customer support workflow for billing issues

---

## 11. KEY FILES FOR IMPLEMENTATION

### Priority Files to Modify
1. **`functions/lib/functions/createCheckoutSession.js`** - Implement real Stripe checkout
2. **`lib/services/subscription_service.dart:295`** - Add URL launcher
3. **`functions/lib/functions/stripeWebhook.js`** - Add signature verification
4. **`functions/lib/functions/cancelSubscription.js`** - Complete cancellation flow

### Supporting Files
- `lib/ui/subscription/subscription_management_view.dart` - Enhanced error handling
- `lib/ui/subscription/lumara_subscription_status.dart` - Loading states
- `lib/services/firebase_service.dart` - Configuration updates

---

This analysis provides a complete foundation for implementing the remaining Stripe integration components. The architecture is solid, but requires completion of the core payment processing and security features for production deployment.