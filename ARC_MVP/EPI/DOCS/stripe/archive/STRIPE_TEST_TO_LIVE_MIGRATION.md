# Stripe Test to Live Mode Migration Guide

**Date:** January 13, 2026  
**Purpose:** Complete guide for migrating from Stripe test mode to live/production mode

---

## Overview

This guide walks you through migrating your Stripe integration from **test mode** to **live mode** for production use. All your current Stripe APIs, webhooks, and configurations are in test mode and need to be updated.

---

## ⚠️ Important Pre-Migration Checklist

Before starting, ensure:
- [ ] Your app is ready for production
- [ ] You've tested all subscription flows in test mode
- [ ] You have a Stripe account with live mode enabled
- [ ] You understand the differences between test and live mode
- [ ] You have access to Firebase Secret Manager
- [ ] You have your Firebase project ID ready

---

## Step 1: Switch Stripe Dashboard to Live Mode

### 1.1 Access Live Mode
1. Go to [Stripe Dashboard](https://dashboard.stripe.com)
2. **Switch to Live Mode**:
   - Look for the mode toggle in the **top right corner** OR
   - Go to **Developers → API Keys** and toggle at the top
   - Switch from "Test mode" to **"Live mode"**

### 1.2 Verify Live Mode
- You should see **"Live mode"** indicator (green/highlighted)
- Keys will now start with `pk_live_...` and `sk_live_...` (instead of `pk_test_...` and `sk_test_...`)

---

## Step 2: Get Live Mode API Keys

### 2.1 Get Live Secret Key
1. In Stripe Dashboard (Live Mode), go to **Developers → API Keys**
2. Under **"Secret key"**, click **"Reveal live key"**
3. Copy the key (starts with `sk_live_...`)
4. **Keep this secure** - you'll need it for Firebase Secret Manager

### 2.2 Get Live Publishable Key (Optional - for client-side)
1. In the same page, find **"Publishable key"**
2. Copy the key (starts with `pk_live_...`)
3. **Note:** If you're using publishable keys in your Flutter app, update them in your code

---

## Step 3: Create Products and Prices in Live Mode

### 3.1 Verify/Create Products and Prices
1. Go to **Products** in Stripe Dashboard (Live Mode)
2. Check if your products exist:
   - **ARC Premium** (monthly + annual recurring)
   - **ARC Founders Commit** (one-time upfront)
3. If they don't exist, create them:
   - Click **"+ Add product"**
   - Name: "ARC Premium"
   - Add pricing:
     - Monthly: $30.00/month (recurring)
     - Annual: $200.00/year (recurring)
   - Create another product:
     - Name: "ARC Founders Commit"
     - Price: $1,500.00 (one-time, non-recurring)
4. **Copy the Price IDs** (NOT the Product ID - you need the Price IDs!)
   - After creating prices, each price will have its own ID starting with `price_...`
   - Monthly Price ID: `price_...` ← **This is what you need**
   - Annual Price ID: `price_...` ← **This is what you need**
   - Founders Upfront Price ID: `price_...` ← **This is what you need**
   - Make sure this is a **one-time** price and different from monthly/annual
   
   **Important:** 
   - Product ID starts with `prod_...` - **Don't use this**
   - Price ID starts with `price_...` - **Use this** ✅
   - You need the Price IDs for monthly, annual, and founders upfront

**Important:** Price IDs are different between test and live mode. You'll need to update these in Firebase Secret Manager.

---

## Step 4: Set Up Live Mode Webhook

### 4.1 Create New Webhook Endpoint
1. In Stripe Dashboard (Live Mode), go to **Developers → Webhooks**
2. Click **"+ Add endpoint"**
3. **Endpoint URL**: 
   ```
   https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net/stripeWebhook
   ```
   Replace `YOUR-PROJECT-ID` with your actual Firebase project ID (e.g., `arc-epi`)

### 4.2 Select Events
Click **"Select events"** and add these events:
- ✅ `checkout.session.completed`
- ✅ `customer.subscription.created`
- ✅ `customer.subscription.updated`
- ✅ `customer.subscription.deleted`
- ✅ `invoice.payment_succeeded`
- ✅ `invoice.payment_failed`

### 4.3 Get Webhook Signing Secret
1. Click **"Add endpoint"** to create it
2. Once created, click on the webhook endpoint
3. Under **"Signing secret"**, click **"Reveal"**
4. Copy the secret (starts with `whsec_...`)
5. **Keep this secure** - you'll need it for Firebase Secret Manager

**Important:** The webhook secret is different for live mode. You need a new webhook endpoint in live mode.

---

## Step 5: Update Firebase Secret Manager

### 5.1 Update Stripe Secret Key
```bash
# Navigate to your project
cd "/Users/mymac/Software/Development/ARCv1.0/ARC MVP/EPI"

# Update the secret key (will prompt for new value)
firebase functions:secrets:set STRIPE_SECRET_KEY
# When prompted, paste your LIVE secret key: sk_live_...
```

### 5.2 Update Webhook Secret
```bash
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# When prompted, paste your LIVE webhook secret: whsec_...
```

### 5.3 Update Price IDs
```bash
# Update Monthly Price ID
firebase functions:secrets:set STRIPE_PRICE_ID_MONTHLY
# When prompted, paste your LIVE monthly price ID: price_...

# Update Annual Price ID
firebase functions:secrets:set STRIPE_PRICE_ID_ANNUAL
# When prompted, paste your LIVE annual price ID: price_...

# Update Founder Upfront Price ID
firebase functions:secrets:set STRIPE_FOUNDER_PRICE_ID_UPFRONT
# When prompted, paste your LIVE founder upfront price ID: price_...
```

### 5.4 Verify Secrets
```bash
# List all secrets to verify
firebase functions:secrets:access STRIPE_SECRET_KEY
firebase functions:secrets:access STRIPE_WEBHOOK_SECRET
firebase functions:secrets:access STRIPE_PRICE_ID_MONTHLY
firebase functions:secrets:access STRIPE_PRICE_ID_ANNUAL
firebase functions:secrets:access STRIPE_FOUNDER_PRICE_ID_UPFRONT
```

**Note:** Make sure all secrets start with:
- `STRIPE_SECRET_KEY`: `sk_live_...` (not `sk_test_...`)
- `STRIPE_WEBHOOK_SECRET`: `whsec_...` (different from test mode)
- Price IDs: `price_...` (from live mode products)

---

## Step 6: Update Customer Portal (If Needed)

### 6.1 Configure Customer Portal
1. In Stripe Dashboard (Live Mode), go to **Settings → Billing → Customer portal**
2. Enable:
   - ✅ Update payment methods
   - ✅ View billing history
   - ✅ Cancel subscriptions
   - ✅ **Switch plans** (allows monthly ↔ annual switching)
3. Add your live mode products to the portal product list
4. Set return URL to: `arc://settings`

---

## Step 7: Update Flutter App (If Using Publishable Keys)

### 7.1 Check for Publishable Keys
Search your Flutter codebase for `pk_test_`:
```bash
grep -r "pk_test" lib/
```

### 7.2 Update to Live Keys
If you find any publishable keys:
1. Replace `pk_test_...` with `pk_live_...`
2. Get the live publishable key from Stripe Dashboard → Developers → API Keys
3. Update in your code/config files

**Note:** If you're not using publishable keys in the app (all handled server-side), skip this step.

---

## Step 8: Redeploy Firebase Functions

### 8.1 Deploy Functions
```bash
# Deploy functions with updated secrets
firebase deploy --only functions
```

### 8.2 Verify Deployment
```bash
# Check function logs
firebase functions:log --only stripeWebhook
```

---

## Step 9: Test Live Mode (Carefully!)

### 9.1 Test with Real Card (Small Amount)
**⚠️ WARNING:** This will charge a real card!

1. Use a real credit card (your own for testing)
2. Test the subscription flow:
   - Open your app
  - Try to subscribe (monthly, annual, and founders upfront)
   - Complete checkout with real card
   - Verify subscription activates

### 9.2 Verify Webhook Delivery
1. Go to Stripe Dashboard → Developers → Webhooks
2. Click on your live webhook endpoint
3. Check the **"Events"** tab
4. Verify events are being delivered successfully

### 9.3 Check Firebase
1. Check Firestore - user document should update with `subscriptionTier: "premium"`
2. Verify subscription data is correct

### 9.4 Test Customer Portal
1. Access customer portal from your app
2. Verify subscription management works
3. Test plan switching (monthly ↔ annual)
4. Test cancellation

---

## Step 10: Monitor and Set Up Alerts

### 10.1 Set Up Stripe Alerts
1. Go to **Settings → Notifications** in Stripe Dashboard
2. Enable email alerts for:
   - Failed payments
   - Disputed payments
   - Webhook failures
   - Subscription cancellations

### 10.2 Monitor Function Logs
```bash
# Watch function logs in real-time
firebase functions:log --only stripeWebhook --follow
```

### 10.3 Set Up Firebase Alerts
1. Go to Firebase Console → Functions
2. Set up alerts for:
   - Function errors
   - High error rates
   - Execution timeouts

---

## Complete Checklist

Before going fully live, verify:

### Stripe Dashboard
- [ ] Switched to Live Mode
- [ ] Live API keys obtained (`sk_live_...`, `pk_live_...`)
- [ ] Products created in Live Mode
- [ ] Price IDs copied from Live Mode
- [ ] Webhook endpoint created in Live Mode
- [ ] Webhook signing secret obtained (`whsec_...`)
- [ ] Customer Portal configured
- [ ] Email notifications enabled

### Firebase
- [ ] `STRIPE_SECRET_KEY` updated to live key (`sk_live_...`)
- [ ] `STRIPE_WEBHOOK_SECRET` updated to live secret (`whsec_...`)
- [ ] `STRIPE_PRICE_ID_MONTHLY` updated to live price ID
- [ ] `STRIPE_PRICE_ID_ANNUAL` updated to live price ID
- [ ] `STRIPE_FOUNDER_PRICE_ID_UPFRONT` updated to live price ID
- [ ] Functions redeployed
- [ ] Function logs checked

### App
- [ ] Publishable keys updated (if used)
- [ ] Tested subscription flow with real card
- [ ] Verified webhook delivery
- [ ] Tested Customer Portal
- [ ] Verified subscription activation in Firestore

### Monitoring
- [ ] Stripe alerts configured
- [ ] Firebase alerts configured
- [ ] Function logs monitored

---

## Differences: Test vs Live Mode

| Feature | Test Mode | Live Mode |
|---------|-----------|-----------|
| **API Keys** | `sk_test_...`, `pk_test_...` | `sk_live_...`, `pk_live_...` |
| **Charges** | Fake/Test | **REAL MONEY** |
| **Cards** | Test cards (`4242 4242 4242 4242`) | Real cards only |
| **Webhooks** | Test events | Real events |
| **Price IDs** | Test prices (`price_...`) | Live prices (`price_...`) |
| **Webhook Secret** | Test secret | Live secret |
| **When to Use** | Development/Testing | Production |

**Note:** Use **Price IDs** (`price_...`), NOT Product IDs (`prod_...`). The code uses Price IDs in checkout sessions.

---

## Troubleshooting

### "Invalid API key" Error
- **Cause:** Using test key in live mode or vice versa
- **Fix:** Verify `STRIPE_SECRET_KEY` in Firebase Secret Manager starts with `sk_live_...`

### Webhook Not Firing
- **Cause:** Wrong webhook secret or endpoint URL
- **Fix:** 
  1. Verify `STRIPE_WEBHOOK_SECRET` is from live mode webhook
  2. Check webhook endpoint URL matches your Firebase function URL
  3. Check Stripe Dashboard → Webhooks for failed deliveries

### "Price not found" Error
- **Cause:** Using test price ID in live mode, or using Product ID instead of Price ID
- **Fix:** 
  1. Make sure you're using **Price IDs** (`price_...`), NOT Product IDs (`prod_...`)
  2. Update `STRIPE_PRICE_ID_MONTHLY` and `STRIPE_PRICE_ID_ANNUAL` with live mode price IDs
  3. Verify the price IDs exist in Stripe Dashboard → Products → [Your Product] → Pricing

### Subscription Not Activating
- **Cause:** Webhook not processing correctly
- **Fix:**
  1. Check Firebase Functions logs
  2. Verify webhook events in Stripe Dashboard
  3. Check Firestore rules allow function writes

### Customer Portal Not Working
- **Cause:** Portal not configured in live mode
- **Fix:** Configure Customer Portal in Stripe Dashboard (Live Mode) → Settings → Billing → Customer portal

---

## Security Reminders

- ✅ **Never commit API keys to git** - use Firebase Secret Manager
- ✅ **Never share secret keys** - keep them secure
- ✅ **Use HTTPS** - all webhook endpoints must use HTTPS
- ✅ **Verify webhook signatures** - your code should already do this
- ✅ **Monitor for suspicious activity** - set up alerts

---

## Rollback Plan

If something goes wrong, you can rollback:

1. **Switch Stripe Dashboard back to Test Mode**
2. **Revert Firebase secrets to test values:**
   ```bash
   firebase functions:secrets:set STRIPE_SECRET_KEY
   # Enter test key: sk_test_...
   
   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
   # Enter test webhook secret: whsec_...
   ```
3. **Redeploy functions:**
   ```bash
   firebase deploy --only functions
   ```

---

## Support Resources

- [Stripe Live Mode Documentation](https://stripe.com/docs/keys)
- [Stripe Webhooks Guide](https://stripe.com/docs/webhooks)
- [Firebase Secret Manager](https://firebase.google.com/docs/functions/config-env)
- [Stripe Support](https://support.stripe.com/)

---

**Last Updated:** January 13, 2026  
**Status:** Ready for Production Migration
