# Stripe Integration Setup Guide

This guide will help you set up Stripe integration with your Firebase Cloud Functions.

## 1. Stripe Dashboard Setup

### Get Your Stripe Keys
1. Log into [Stripe Dashboard](https://dashboard.stripe.com)
2. Make sure you're in **Test Mode** (toggle in top right)
3. Go to **Developers → API Keys**
4. Copy:
   - **Secret key**: `sk_test_...` (for Firebase functions)

### Create Products and Price IDs
1. Go to **Products** in Stripe Dashboard
2. Click **+ Add product**
3. Create "ARC Premium" product with these prices:
   - **Monthly**: $30.00/month recurring
   - **Annual**: $200.00/year recurring
4. After creation, copy both **Price IDs**:
   - Monthly: `price_...`
   - Annual: `price_...`

### Set Up Webhook
1. Go to **Developers → Webhooks**
2. Click **Add endpoint**
3. Endpoint URL: `https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net/stripeWebhook`
   - Replace `YOUR-PROJECT-ID` with your Firebase project ID
4. Click **Select events** and add:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
5. Click **Add endpoint**
6. Once created, click **Reveal** under Signing secret
7. Copy the webhook secret: `whsec_...`

### Configure Customer Portal
1. Go to **Settings → Billing → Customer portal**
2. Enable:
   - Update payment methods
   - View billing history
   - Cancel subscriptions
   - **Switch plans** (allows monthly ↔ annual switching)
3. Add your products to the portal product list
4. Set return URL to: `arc://settings`

## 2. Firebase Secret Manager Setup

You'll need to set up secrets in Firebase Secret Manager for security. Run these commands in your terminal:

### Set Stripe Secrets (Test Mode)
```bash
# Navigate to your project
cd "/Users/mymac/Software/Development/ARCv1.0/ARC MVP/EPI"

# Set test mode secrets
firebase functions:secrets:set STRIPE_SECRET_KEY
# When prompted, enter: sk_test_YOUR_SECRET_KEY

firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# When prompted, enter: whsec_YOUR_WEBHOOK_SECRET

firebase functions:secrets:set STRIPE_PRICE_ID_MONTHLY
# When prompted, enter: price_YOUR_MONTHLY_PRICE_ID

firebase functions:secrets:set STRIPE_PRICE_ID_ANNUAL
# When prompted, enter: price_YOUR_ANNUAL_PRICE_ID
```

### For Production (When Ready)
```bash
# Toggle to Live Mode in Stripe Dashboard first
# Get live API keys and create new webhook endpoint for live mode

firebase functions:secrets:set STRIPE_SECRET_KEY
# Enter: sk_live_YOUR_LIVE_SECRET_KEY

firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# Enter: whsec_YOUR_LIVE_WEBHOOK_SECRET

# Price IDs are usually the same between test/live if created in live mode
```

## 3. Deploy Functions

```bash
# Deploy the updated functions
firebase deploy --only functions
```

## 4. Testing

### Test Cards (Test Mode Only)
- **Success**: `4242 4242 4242 4242`
- **Decline**: `4000 0000 0000 0002`
- **Requires Auth**: `4000 0025 0000 3155`

### Test Flow
1. Open your app
2. Try to subscribe (monthly or annual)
3. You should be redirected to Stripe Checkout
4. Use test card: `4242 4242 4242 4242` (any future expiry, any CVC)
5. Complete payment
6. Check Firestore - user doc should update with `subscriptionTier: "premium"`

### Local Webhook Testing (Optional)
```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Login to Stripe
stripe login

# Forward webhooks to local function
stripe listen --forward-to localhost:5001/YOUR-PROJECT-ID/us-central1/stripeWebhook

# Trigger test events
stripe trigger checkout.session.completed
```

## 5. Monitoring

### Check Function Logs
```bash
firebase functions:log
```

### Verify Webhooks
1. Go to Stripe Dashboard → Developers → Webhooks
2. Click on your webhook endpoint
3. Check the "Events" tab for successful deliveries

## 6. Production Checklist

Before going live:
- [ ] Switch to Live Mode in Stripe Dashboard
- [ ] Get live API keys
- [ ] Create new webhook endpoint for live mode
- [ ] Update Firebase secrets with live keys
- [ ] Test with real cards (small amounts)
- [ ] Set up monitoring alerts
- [ ] Test Customer Portal functionality

## Troubleshooting

**"Function not found" error:**
- Run `firebase deploy --only functions` again
- Check `firebase functions:log` for errors

**Checkout URL doesn't open:**
- Make sure `url_launcher` is in pubspec.yaml
- Check function logs for errors

**Webhook not firing:**
- Verify endpoint URL matches exactly
- Check Stripe Dashboard → Webhooks for failed deliveries
- Verify webhook secret is correct

**User not upgrading after payment:**
- Check Firebase Functions logs
- Verify webhook events are being received
- Check Firestore rules allow function writes

## Security Notes

- ✅ Secret keys are stored in Firebase Secret Manager
- ✅ Webhook signatures are verified
- ✅ Customer data is isolated from journal content
- ✅ Only Firebase UID links payment to user data
- ✅ All payment processing happens on Stripe's secure servers