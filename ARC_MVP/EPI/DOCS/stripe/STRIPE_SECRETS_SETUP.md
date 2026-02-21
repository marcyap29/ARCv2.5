# Stripe Secrets Setup Guide - Step by Step

**Project ID:** `arc-epi`  
**Date:** January 1, 2026

This guide will walk you through setting up all Stripe secrets in Firebase Secret Manager.

---

## Prerequisites

1. ✅ Stripe account (sign up at https://stripe.com if needed)
2. ✅ Firebase CLI installed and logged in
3. ✅ Access to Stripe Dashboard

---

## Step 1: Get Stripe API Keys (5 minutes)

### 1.1 Log into Stripe Dashboard
1. Go to [https://dashboard.stripe.com](https://dashboard.stripe.com)
2. Log in with your Stripe account

### 1.2 Switch to Test Mode (IMPORTANT!)
**You're currently in LIVE mode - we need to switch to TEST mode for development.**

**The Test Mode toggle is in the Developers section, not on the home page!**

1. In the **left sidebar**, click **"Developers"** (you might need to scroll down or expand a section)
2. Click **"API keys"** in the Developers menu
3. At the **top of the API keys page**, you'll see a toggle switch that says:
   - **"Live mode"** (if you're in live mode) - it will be highlighted/green
   - **"Test mode"** (if you're in test mode) - it will be gray/blue
4. **Click the toggle** to switch from "Live mode" to "Test mode"
5. The page will refresh and you'll see test keys instead of live keys
6. The keys will now start with `pk_test_` and `sk_test_` (instead of `pk_live_` and `sk_live_`)

**Alternative: Look for toggle in top right**
- Sometimes there's a toggle in the **top right corner** of any Stripe page
- It might say "Live" or "Test" - click it to switch modes

**Why Test Mode?**
- ✅ No real charges - safe for testing
- ✅ Use test card numbers
- ✅ Won't affect real customers
- ✅ Can test everything without risk

### 1.3 Get Your Secret Key (Test Mode)
**Make sure you're in TEST MODE before getting keys!**

1. In the **"For developers"** section on your dashboard, you should see:
   - **Publishable key** (starts with `pk_test_...` when in test mode)
   - **Secret key** (starts with `sk_test_...` when in test mode) - **THIS IS WHAT YOU NEED**
2. Click the **eye icon** 👁️ next to the masked Secret key to reveal it
3. Copy the entire key (it looks like: `sk_test_51AbCdEf...`)
4. **IMPORTANT:** Make sure it starts with `sk_test_` (NOT `sk_live_`)
5. **Save this somewhere safe** - you'll need it in Step 4

**Alternative Method:**
- Click **"Developers"** in the left sidebar
- Click **"API keys"**
- You'll see the same keys there
- Click **"Reveal test key"** to see your secret key

---

## Step 2: Create Products and Get Price IDs (10 minutes)

### 2.1 Create the Premium Product
1. In Stripe Dashboard, click **"Products"** in the left sidebar
2. Click the **"+ Add product"** button (top right)
3. Fill in the product details:
   - **Name:** `ARC Premium`
   - **Description:** `Premium subscription for ARC app with unlimited LUMARA access`
   - Leave other fields as default
4. Scroll down to **"Pricing"** section
5. Click **"Add another price"** to add both monthly and annual prices

### 2.2 Add Monthly Price ($30/month)
1. In the pricing section:
   - **Price:** `30.00`
   - **Currency:** `USD` (or your currency)
   - **Billing period:** Select **"Recurring"** → **"Monthly"**
2. Click **"Add price"** or **"Save product"**

### 2.3 Add Annual Price ($200/year)
1. Still in the same product, click **"Add another price"**
2. Fill in:
   - **Price:** `200.00`
   - **Currency:** `USD`
   - **Billing period:** Select **"Recurring"** → **"Yearly"**
3. Click **"Save product"**

### 2.4 Create the Founders Commit Product
1. In Stripe Dashboard, click **"Products"** in the left sidebar
2. Click the **"+ Add product"** button (top right)
3. Fill in the product details:
   - **Name:** `ARC Founders Commit`
   - **Description:** `Founders commitment for ARC (3-year, upfront)`
   - Leave other fields as default
4. Scroll down to **"Pricing"** section
5. Add a one-time price:
   - **Price:** `1500.00`
   - **Currency:** `USD`
   - **Billing period:** **One-time** (non-recurring)
6. Click **"Save product"**

### 2.5 Get Your Price IDs
1. After saving, you'll see your product page
2. You'll see all prices listed
3. For each price, click on it to open the price details
4. Copy the **Price ID** (starts with `price_...`)
   - **Monthly Price ID:** `price_...` (save this)
   - **Annual Price ID:** `price_...` (save this)
   - **Founders Upfront Price ID:** `price_...` (save this)
5. **Save all Price IDs** - you'll need them in Step 4

---

## Step 3: Set Up Webhook (10 minutes)

### 3.1 Create Webhook Endpoint (Called "Destination" in New Interface)
**Note:** In Stripe's newer interface, webhook endpoints are called "destinations" - they're the same thing!

1. In Stripe Dashboard, you're already on the **"Webhooks"** page (I can see you're in the Workbench)
2. Click the **"+ Add destination"** button (purple button with plus icon)
3. You'll be asked to choose a destination type - select **"Webhook endpoint"** (or just "Webhook")
4. In the **"Endpoint URL"** field, enter:
   ```
   https://us-central1-arc-epi.cloudfunctions.net/stripeWebhook
   ```
   (This is your Firebase project's webhook URL)

### 3.2 Select Events to Listen To
1. Click **"Select events"**
2. Check these events:
   - ✅ `checkout.session.completed`
   - ✅ `customer.subscription.created`
   - ✅ `customer.subscription.updated`
   - ✅ `customer.subscription.deleted`
   - ✅ `invoice.payment_succeeded`
   - ✅ `invoice.payment_failed`
3. Click **"Add events"**

### 3.3 Get Webhook Signing Secret
1. Click **"Add endpoint"** to create the webhook
2. After creation, you'll see your webhook in the list
3. Click on the webhook to open its details
4. Find **"Signing secret"** section
5. Click **"Reveal"** next to the signing secret
6. Copy the webhook secret (starts with `whsec_...`)
7. **Save this** - you'll need it in Step 4

### 3.4 Configure Customer Portal
1. Go to **Settings → Billing → Customer portal**
2. Enable:
   - Update payment methods
   - View billing history
   - Cancel subscriptions
   - **Switch plans** (allows monthly ↔ annual switching)
3. Add your products to the portal product list
4. Set return URL to: `arc://settings`

---

## Step 4: Add Secrets to Firebase (5 minutes)

Now we'll add all the secrets to Firebase Secret Manager using the Firebase CLI.

### 4.1 Navigate to Project Directory
Open your terminal and run:
```bash
cd "/Users/mymac/Software/Development/ARCv1.0/functions"
```

### 4.2 Add Stripe Secret Key
Run this command:
```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
```

**When prompted:**
- Paste your Stripe Secret Key (the `sk_test_...` key from Step 1.3)
- Press Enter
- You'll see: `✔ Created a new secret version for STRIPE_SECRET_KEY`

### 4.3 Add Monthly Price ID
Run this command:
```bash
firebase functions:secrets:set STRIPE_PRICE_ID_MONTHLY
```

**When prompted:**
- Paste your Monthly Price ID (the `price_...` from Step 2.4)
- Press Enter
- You'll see: `✔ Created a new secret version for STRIPE_PRICE_ID_MONTHLY`

### 4.4 Add Annual Price ID
Run this command:
```bash
firebase functions:secrets:set STRIPE_PRICE_ID_ANNUAL
```

**When prompted:**
- Paste your Annual Price ID (the `price_...` from Step 2.4)
- Press Enter
- You'll see: `✔ Created a new secret version for STRIPE_PRICE_ID_ANNUAL`

### 4.5 Add Founders Upfront Price ID
Run this command:
```bash
firebase functions:secrets:set STRIPE_FOUNDER_PRICE_ID_UPFRONT
```

**When prompted:**
- Paste your Founders upfront Price ID (the `price_...` one-time price)
- Press Enter
- You'll see: `✔ Created a new secret version for STRIPE_FOUNDER_PRICE_ID_UPFRONT`

### 4.6 Add Webhook Secret
Run this command:
```bash
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

**When prompted:**
- Paste your Webhook Secret (the `whsec_...` from Step 3.3)
- Press Enter
- You'll see: `✔ Created a new secret version for STRIPE_WEBHOOK_SECRET`

### 4.7 Verify Secrets Are Set
Run these commands to verify:
```bash
firebase functions:secrets:access STRIPE_SECRET_KEY
firebase functions:secrets:access STRIPE_PRICE_ID_MONTHLY
firebase functions:secrets:access STRIPE_PRICE_ID_ANNUAL
firebase functions:secrets:access STRIPE_FOUNDER_PRICE_ID_UPFRONT
firebase functions:secrets:access STRIPE_WEBHOOK_SECRET
```

You should see each secret displayed (or a message confirming it exists).

---

## Step 5: Deploy Functions (2 minutes)

Now deploy the functions so they can use the secrets:

```bash
cd "/Users/mymac/Software/Development/ARCv1.0"
firebase deploy --only functions:createCheckoutSession,functions:createPortalSession,functions:stripeWebhook
```

Wait for the deployment to complete. You should see:
```
✔ functions[createCheckoutSession(us-central1)] Successful update operation.
✔ functions[createPortalSession(us-central1)] Successful update operation.
✔ functions[stripeWebhook(us-central1)] Successful update operation.
```

---

## Step 6: Test the Integration (5 minutes)

### 6.1 Test in Your App
1. Open your ARC app
2. Sign in with a test account (not your premium email)
3. Navigate to **Settings** → **Subscription Management**
4. Click **"Subscribe"** (either Monthly or Annual)
5. You should now be redirected to Stripe Checkout (no more UNAUTHENTICATED error!)

### 6.2 Use Test Cards (Test Mode Only)
In the Stripe Checkout page:
- **Success:** `4242 4242 4242 4242`
- **Decline:** `4000 0000 0000 0002`
- **Requires authentication:** `4000 0025 0000 3155`

For success flow: use **4242 4242 4242 4242**, any future expiry (e.g., `12/25`), any CVC (e.g., `123`), any ZIP (e.g., `12345`). Click **"Subscribe"** to complete the test payment.

### 6.3 Verify Subscription
1. After payment, you should be redirected back to the app
2. Check your subscription status - it should show "Premium"
3. Go to Stripe Dashboard → **Customers** → Find your test customer
4. You should see the subscription is active

---

## Quick Reference: All Commands

Here are all the commands you need, in order:

```bash
# Navigate to functions directory
cd "/Users/mymac/Software/Development/ARCv1.0/functions"

# Add Stripe Secret Key
firebase functions:secrets:set STRIPE_SECRET_KEY
# (Paste: sk_test_...)

# Add Monthly Price ID
firebase functions:secrets:set STRIPE_PRICE_ID_MONTHLY
# (Paste: price_...)

# Add Annual Price ID
firebase functions:secrets:set STRIPE_PRICE_ID_ANNUAL
# (Paste: price_...)

# Add Founders Upfront Price ID
firebase functions:secrets:set STRIPE_FOUNDER_PRICE_ID_UPFRONT
# (Paste: price_...)

# Add Webhook Secret
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# (Paste: whsec_...)

# Deploy functions
cd "/Users/mymac/Software/Development/ARCv1.0"
firebase deploy --only functions:createCheckoutSession,functions:createPortalSession,functions:stripeWebhook
```

---

## Troubleshooting

### Error: "Secret not found"
- Make sure you're in the correct directory (`/functions`)
- Verify you're logged into Firebase: `firebase login`
- Check project: `firebase use arc-epi`

### Error: "UNAUTHENTICATED" still appears
- Make sure all secrets are set correctly
- Redeploy the functions after setting secrets
- Check function logs: `firebase functions:log`

### Webhook not working
- Verify webhook URL is exactly: `https://us-central1-arc-epi.cloudfunctions.net/stripeWebhook`
- Check Stripe Dashboard → Webhooks → Your endpoint → Events tab
- Make sure webhook secret matches what you set in Firebase

### "Function not found" or Checkout URL doesn't open
- Run `firebase deploy --only functions` again
- Ensure `url_launcher` is in pubspec.yaml
- Check `firebase functions:log` for errors

### User not upgrading after payment
- Check Firebase Functions logs
- Verify webhook events are being received
- Check Firestore rules allow function writes

### Can't find Price IDs
- Go to Stripe Dashboard → Products
- Click on your "ARC Premium" product
- Click on each price to see its details
- The Price ID is shown at the top of the price details page

---

## Step 7: Local Webhook Testing (Optional)

To test webhooks against a local function:

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Login to Stripe
stripe login

# Forward webhooks to local function
stripe listen --forward-to localhost:5001/arc-epi/us-central1/stripeWebhook

# Trigger test events
stripe trigger checkout.session.completed
```

---

## Monitoring

### Check Function Logs
```bash
firebase functions:log
```

### Verify Webhooks
1. Go to Stripe Dashboard → Developers → Webhooks
2. Click on your webhook endpoint
3. Check the "Events" tab for successful deliveries

---

## What's Next?

Once everything is set up:
1. ✅ Test the full subscription flow
2. ✅ Test subscription cancellation
3. ✅ Test Customer Portal (Manage Subscription button)
4. ✅ Monitor webhook events in Stripe Dashboard
5. ✅ Check Firebase Functions logs for any errors

### Production checklist (when going live)
- [ ] Switch to Live Mode in Stripe Dashboard
- [ ] Get live API keys
- [ ] Create new webhook endpoint for live mode
- [ ] Update Firebase secrets with live keys
- [ ] Test with real cards (small amounts first)
- [ ] Set up monitoring alerts
- [ ] Test Customer Portal functionality

---

## Security Notes

✅ All secrets are stored securely in Firebase Secret Manager  
✅ Secrets are never exposed to the client  
✅ Webhook signatures are verified  
✅ All payment processing happens on Stripe's secure servers  

---

**Related:** [STRIPE_TEST_VS_LIVE.md](STRIPE_TEST_VS_LIVE.md) for Test vs Live mode; [stripe/README.md](README.md) for full Stripe doc index.

