# How to Find Test Mode Toggle in Stripe

## The Test Mode Toggle is NOT on the Home Page

The toggle is hidden in the **Developers** section. Here's exactly where to find it:

## Method 1: Through Developers → API Keys (Easiest)

1. **Click "Developers" in the left sidebar**
   - Scroll down if needed
   - It's usually near the bottom of the sidebar

2. **Click "API keys"**
   - This will open the API keys page

3. **Look at the TOP of the API keys page**
   - You'll see a toggle switch that says either:
     - **"Live mode"** (green/highlighted) ← You're here now
     - **"Test mode"** (gray/blue)

4. **Click the toggle** to switch to Test mode
   - The page will refresh
   - Keys will change from `sk_live_...` to `sk_test_...`

## Method 2: Top Right Corner Toggle

1. Look at the **top right corner** of any Stripe page
2. You might see a small toggle or button that says:
   - "Live" or "Test mode"
   - Click it to switch

## Method 3: URL Parameter

If you can't find the toggle, you can manually switch by going to:
```
https://dashboard.stripe.com/test/apikeys
```
(Notice the `/test/` in the URL - this forces test mode)

## Visual Guide

**What you'll see in Live Mode:**
- Toggle shows: **"Live mode"** (green/highlighted)
- Keys start with: `pk_live_...` and `sk_live_...`

**What you'll see in Test Mode:**
- Toggle shows: **"Test mode"** (gray/blue)
- Keys start with: `pk_test_...` and `sk_test_...`

## Quick Steps

1. ✅ Left sidebar → **"Developers"**
2. ✅ Click **"API keys"**
3. ✅ Look at **top of page** for toggle
4. ✅ Click toggle to switch to **"Test mode"**
5. ✅ Copy your `sk_test_...` key

---

**Still can't find it?** Try going directly to:
`https://dashboard.stripe.com/test/apikeys`

