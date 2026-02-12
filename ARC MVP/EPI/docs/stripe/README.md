# Stripe Integration Documentation

**Last Updated:** February 12, 2026  
**Status:** ✅ Production Ready

---

## Overview

Stripe is used for **web** purchases (Checkout and Customer Portal). **In-app purchases** (Apple/Google) are handled by RevenueCat — see [revenuecat/README.md](../revenuecat/README.md).

---

## Documentation Index

| Document | Purpose |
|----------|---------|
| **[STRIPE_SECRETS_SETUP.md](STRIPE_SECRETS_SETUP.md)** | Comprehensive setup: API keys, products, webhooks, Firebase Secret Manager, deploy, test, troubleshoot |
| **[STRIPE_TESTING_AND_MIGRATION.md](STRIPE_TESTING_AND_MIGRATION.md)** | Test vs live mode, switching modes, webhook visual guide, success pages, test-to-live migration, troubleshooting |
| **[STRIPE_INTEGRATION_ANALYSIS.md](STRIPE_INTEGRATION_ANALYSIS.md)** | Technical analysis: architecture, implementation status, database schema, security |

---

## Quick Start

1. **First-time setup:** Follow [STRIPE_SECRETS_SETUP.md](STRIPE_SECRETS_SETUP.md)
2. **Testing & modes:** See [STRIPE_TESTING_AND_MIGRATION.md](STRIPE_TESTING_AND_MIGRATION.md)
3. **Technical details:** See [STRIPE_INTEGRATION_ANALYSIS.md](STRIPE_INTEGRATION_ANALYSIS.md)

---

## Integration Status

✅ Checkout session creation  
✅ Customer portal integration  
✅ Webhook handler with signature verification  
✅ Subscription status management  
✅ Firebase Secret Manager integration  
✅ Production deployment completed  
✅ Live mode fully functional  
✅ Test/live mode migration handling  

---

## Recent Critical Fixes (v2.1.77)

**Date:** January 14, 2026

1. **Hardcoded Premium Access** — `getUserSubscription()` fixed
2. **Firebase Admin Import Error** — Legacy syntax corrected
3. **Test/Live Mode Conflicts** — Automatic customer ID migration

See [Bug Report: BUG-2026-001](../bugtracker/records/stripe-subscription-critical-fixes.md) for details.

---

## Related Documentation

- [Backend Architecture](../backend.md) — Firebase Functions
- [Features](../FEATURES.md) — Subscription features
- [Architecture](../ARCHITECTURE.md) — System architecture
