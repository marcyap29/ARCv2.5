# Stripe Integration Documentation

**Last Updated:** January 15, 2026
**Status:** ✅ Production Ready

---

## Overview

This directory contains all documentation related to **Stripe** payment integration for ARC's subscription system. Stripe is used for **web** purchases (Checkout and Customer Portal). **In-app purchases** (Apple/Google) are handled by RevenueCat—see [PAYMENTS_CLARIFICATION.md](../PAYMENTS_CLARIFICATION.md) and [revenuecat/README.md](../revenuecat/README.md). This Stripe integration enables premium subscriptions (monthly/annual) and a Founders upfront commitment option on the web.

---

## Documentation Index

### Setup

1. **[STRIPE_SECRETS_SETUP.md](STRIPE_SECRETS_SETUP.md)** - Single comprehensive setup guide
   - Getting Stripe API keys (Test/Live mode)
   - Creating products and price IDs
   - Setting up webhooks and Customer Portal
   - Adding secrets to Firebase Secret Manager
   - Deploy and test flow
   - Local webhook testing (Stripe CLI)
   - Production checklist and troubleshooting

### Quick Reference Guides

2. **[STRIPE_TEST_VS_LIVE.md](STRIPE_TEST_VS_LIVE.md)** - Understanding Test Mode vs Live Mode
   - When to use each mode
   - How to switch between modes
   - Key differences

3. **[FIND_TEST_MODE.md](FIND_TEST_MODE.md)** - How to find and switch to Test Mode in Stripe Dashboard
   - Multiple methods to access Test Mode
   - Visual guide

4. **[STRIPE_DIRECT_TEST_MODE.md](STRIPE_DIRECT_TEST_MODE.md)** - Direct URL method to access Test Mode

5. **[STRIPE_WEBHOOK_SETUP_VISUAL.md](STRIPE_WEBHOOK_SETUP_VISUAL.md)** - Visual guide for webhook setup
   - Step-by-step event selection
   - API version selection

6. **[GET_WEBHOOK_SECRET.md](GET_WEBHOOK_SECRET.md)** - How to retrieve webhook signing secret
   - Visual guide to finding the secret
   - Security notes

### Technical Documentation

7. **[STRIPE_INTEGRATION_ANALYSIS.md](STRIPE_INTEGRATION_ANALYSIS.md)** - Technical analysis of Stripe integration
   - Architecture overview
   - Implementation status
   - Database schema
   - Security considerations

---

## Quick Start

**For first-time setup:**
1. Follow [STRIPE_SECRETS_SETUP.md](STRIPE_SECRETS_SETUP.md) (single setup guide)
2. Use [STRIPE_TEST_VS_LIVE.md](STRIPE_TEST_VS_LIVE.md) if you need help finding Test Mode
3. Reference [STRIPE_WEBHOOK_SETUP_VISUAL.md](STRIPE_WEBHOOK_SETUP_VISUAL.md) for webhook configuration

**For troubleshooting:**
- Can't find Test Mode? → [FIND_TEST_MODE.md](FIND_TEST_MODE.md)
- Need webhook secret? → [GET_WEBHOOK_SECRET.md](GET_WEBHOOK_SECRET.md)
- Understanding modes? → [STRIPE_TEST_VS_LIVE.md](STRIPE_TEST_VS_LIVE.md)

---

## Integration Status

✅ **Completed:**
- Stripe checkout session creation
- Customer portal integration
- Webhook handler with signature verification
- Subscription status management
- Firebase Secret Manager integration
- Test mode configuration
- **NEW**: Production deployment completed
- **NEW**: Live mode fully functional
- **NEW**: Critical bug fixes implemented
- **NEW**: Test/live mode migration handling

---

## Related Documentation

- [Backend Architecture](../../backend.md) - Firebase Functions setup
- [Features](../../FEATURES.md) - Subscription features
- [Architecture](../../ARCHITECTURE.md) - System architecture

---

**Version:** 2.1.77
**Last Updated:** January 14, 2026

---

## Recent Critical Fixes (v2.1.77)

### 🚨 **Production Issues Resolved**

**Date:** January 14, 2026
**Impact:** Subscription system now fully functional in production

#### Issues Fixed:
1. **Hardcoded Premium Access** - getUserSubscription() function was only returning premium for hardcoded email
2. **Firebase Admin Import Error** - Legacy syntax causing function crashes
3. **Test/Live Mode Conflicts** - Automatic customer ID migration added

#### Technical Details:
- **Functions Fixed:** `getUserSubscription()`, `createCheckoutSession()`
- **Error Handling:** Enhanced timeout and retry logic
- **Customer Management:** Automatic test-to-live customer ID cleanup
- **Status:** End-to-end subscription flow verified working

#### Verification:
```bash
# Test the subscription flow
firebase functions:log  # Check for successful operations
```

See [Bug Report: BUG-2026-001](../bugtracker/records/stripe-subscription-critical-fixes.md) for complete technical details.

