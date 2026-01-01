# Stripe Test Mode vs Live Mode - Quick Guide

## 🔴 You're Currently in LIVE Mode

Based on your screenshot, you're seeing:
- ✅ Green "Live mode" indicator
- ✅ Keys starting with `pk_live_` and `sk_live_`

## ⚠️ For Development: Use TEST Mode

**We need to switch to TEST mode first!**

### Why Test Mode?
- ✅ **No real charges** - completely safe for testing
- ✅ **Test card numbers** work (like `4242 4242 4242 4242`)
- ✅ **No risk** - can't accidentally charge real customers
- ✅ **Free to test** - unlimited test transactions
- ✅ **Same functionality** - everything works exactly the same

### How to Switch to Test Mode

**Method 1: From Dashboard**
1. Look at the **"For developers"** section on your dashboard
2. You'll see a green **"Live mode"** indicator
3. **Click on "Live mode"** - it's a toggle switch
4. It will switch to **"Test mode"** (will turn gray/blue)

**Method 2: Top Right Toggle**
1. Look at the top right corner of your Stripe Dashboard
2. You might see a toggle switch that says "Live mode"
3. Click it to switch to "Test mode"

**Method 3: From Developers Menu**
1. Click **"Developers"** in the left sidebar
2. Click **"API keys"**
3. At the top, you'll see a toggle for "Test mode" / "Live mode"
4. Switch it to "Test mode"

### After Switching to Test Mode

You'll see:
- 🔵 **"Test mode"** indicator (instead of green "Live mode")
- Keys will change to:
  - `pk_test_...` (publishable key)
  - `sk_test_...` (secret key) ← **This is what you need!**

## 📋 Key Differences

| Feature | Test Mode | Live Mode |
|---------|-----------|-----------|
| **Key Prefix** | `sk_test_...` | `sk_live_...` |
| **Charges** | Fake/Test | **REAL MONEY** |
| **Cards** | Test cards work | Real cards only |
| **Webhooks** | Test events | Real events |
| **When to Use** | Development/Testing | Production |

## ✅ What to Use for This Setup

**Use TEST MODE keys for now:**
- `sk_test_...` (Secret key)
- Test Price IDs (created in test mode)
- Test webhook secret

**Switch to LIVE MODE later when:**
- ✅ App is ready for production
- ✅ You've tested everything thoroughly
- ✅ You want real customers to pay

## 🚨 Important Notes

1. **Never use Live keys for testing** - you could charge real customers!
2. **Test mode and Live mode are separate** - products, customers, and keys are different
3. **You'll need to create products in both modes** - one for test, one for live
4. **Webhooks are separate** - create one for test mode, one for live mode

## Next Steps

1. **Switch to Test Mode** (using one of the methods above)
2. **Get your test keys** (`sk_test_...`)
3. **Create test products** (in test mode)
4. **Set up test webhook** (in test mode)
5. **Add all test secrets to Firebase**
6. **Test everything thoroughly**
7. **Then switch to Live mode** when ready for production

---

**Current Status:** You're in Live mode - switch to Test mode before proceeding! 🔄

