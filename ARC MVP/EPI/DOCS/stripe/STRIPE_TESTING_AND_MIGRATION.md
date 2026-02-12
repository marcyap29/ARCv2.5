# Stripe Testing, Modes & Production Migration

**Last Updated:** February 12, 2026  
**Status:** ✅ Production Ready

---

## Test Mode vs Live Mode

| Feature | Test Mode | Live Mode |
|---------|-----------|-----------|
| **API Keys** | `sk_test_...`, `pk_test_...` | `sk_live_...`, `pk_live_...` |
| **Charges** | Fake/Test | **REAL MONEY** |
| **Cards** | Test cards (`4242 4242 4242 4242`) | Real cards only |
| **Webhooks** | Test events | Real events |
| **Price IDs** | Test prices (`price_...`) | Live prices (`price_...`) |
| **Webhook Secret** | Test secret | Live secret |
| **When to Use** | Development/Testing | Production |

**Important:** Test mode and live mode are separate — products, customers, keys, and webhooks are independent.

---

## How to Switch to Test Mode

### Method 1: Developers → API Keys (Recommended)
1. Click **"Developers"** in the left sidebar
2. Click **"API keys"**
3. Look at the top for the toggle: **"Live mode"** / **"Test mode"**
4. Click to switch

### Method 2: Direct URL
```
https://dashboard.stripe.com/test/apikeys
```
Notice the `/test/` in the URL — this forces Test Mode.

### Method 3: Top Right Toggle
Look at the top right corner of any Stripe page for a small toggle or button.

### Verifying Mode
- **Test Mode:** Keys start with `pk_test_...` / `sk_test_...`. Blue/gray "Test mode" indicator.
- **Live Mode:** Keys start with `pk_live_...` / `sk_live_...`. Green "Live mode" indicator.

---

## Test Cards

For development, use these test card numbers:
- **Success:** `4242 4242 4242 4242` (any expiry date, any CVC)
- Use any future expiration date and any 3-digit CVC

---

## Webhook Setup (Visual Guide)

### Selecting Events

In the Stripe webhook setup ("Select events" screen):

1. API version: Keep default (stable version)
2. Use the search bar to find and select these 6 events:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
3. Click **"Continue"** → enter endpoint URL:
   ```
   https://us-central1-arc-epi.cloudfunctions.net/stripeWebhook
   ```

### Getting the Webhook Signing Secret

1. Click on the created webhook endpoint
2. In the right panel, find **"Signing secret"** (with lock icon)
3. Click the **eye icon** to reveal the full secret (starts with `whsec_...`)
4. Copy it and add to Firebase Secret Manager:
   ```bash
   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
   ```

---

## Success/Cancel Pages

When users complete Stripe checkout, they're redirected to success/cancel URLs.

**Current URLs:**
- Success: `https://arc-app.com/subscription/success?session_id={CHECKOUT_SESSION_ID}`
- Cancel: `https://arc-app.com/subscription/cancel`

**Hosting options:** Firebase Hosting (`public/` directory), GitHub Pages, or any static host.

**Key point:** The webhook handles subscription activation — these pages are for UX feedback only.

---

## Test to Live Migration Guide

### Pre-Migration Checklist
- [ ] App ready for production
- [ ] All subscription flows tested in test mode
- [ ] Stripe account with live mode enabled
- [ ] Access to Firebase Secret Manager

### Step 1: Get Live Mode Keys
1. Switch Stripe Dashboard to Live Mode
2. Developers → API Keys → Reveal live key (`sk_live_...`)

### Step 2: Create Products in Live Mode
1. Products → **"+ Add product"**
2. **ARC Premium:** Monthly $30.00/month + Annual $200.00/year
3. **ARC Founders Commit:** $1,500.00 one-time
4. Copy the **Price IDs** (`price_...`), NOT Product IDs (`prod_...`)

### Step 3: Create Live Webhook
1. Developers → Webhooks → **"+ Add endpoint"**
2. Endpoint: `https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net/stripeWebhook`
3. Select the 6 events listed above
4. Copy the webhook signing secret

### Step 4: Update Firebase Secrets
```bash
firebase functions:secrets:set STRIPE_SECRET_KEY        # sk_live_...
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET     # whsec_...
firebase functions:secrets:set STRIPE_PRICE_ID_MONTHLY   # price_...
firebase functions:secrets:set STRIPE_PRICE_ID_ANNUAL    # price_...
firebase functions:secrets:set STRIPE_FOUNDER_PRICE_ID_UPFRONT  # price_...
```

### Step 5: Configure Customer Portal (Live)
Settings → Billing → Customer portal: enable update payment, view history, cancel, switch plans.

### Step 6: Update App (If Using Publishable Keys)
Replace any `pk_test_...` with `pk_live_...` in Flutter code.

### Step 7: Deploy & Test
```bash
firebase deploy --only functions
```
Test with a real card (small amount). Verify webhook delivery and Firestore subscription update.

### Step 8: Set Up Monitoring
- Stripe alerts: failed payments, disputes, webhook failures
- Firebase alerts: function errors, high error rates, timeouts

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| Invalid API key | Test key in live mode or vice versa | Verify `STRIPE_SECRET_KEY` matches mode |
| Webhook not firing | Wrong secret or endpoint URL | Check webhook config in Stripe Dashboard |
| Price not found | Using Product ID instead of Price ID, or wrong mode | Use `price_...` IDs, not `prod_...` |
| Subscription not activating | Webhook not processing | Check Firebase Functions logs and Firestore rules |
| Customer Portal not working | Not configured in live mode | Configure in Stripe Dashboard → Settings → Billing |

---

## Rollback Plan

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY       # Enter test key: sk_test_...
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET    # Enter test secret: whsec_...
firebase deploy --only functions
```

---

## Security

- Never commit API keys to git — use Firebase Secret Manager
- Never share secret keys
- All webhook endpoints must use HTTPS
- Verify webhook signatures (already implemented)

---

**Consolidated from:** `STRIPE_TEST_VS_LIVE.md`, `FIND_TEST_MODE.md`, `STRIPE_DIRECT_TEST_MODE.md`, `STRIPE_TEST_TO_LIVE_MIGRATION.md`, `STRIPE_SUCCESS_PAGES.md`, `GET_WEBHOOK_SECRET.md`, `STRIPE_WEBHOOK_SETUP_VISUAL.md` (all archived).
