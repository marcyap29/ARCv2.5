# Direct Link to Stripe Test Mode

## Quick Solution: Use Direct URL

Since you can't find the toggle, use this direct link to access Test Mode:

**Click this link or paste it in your browser:**
```
https://dashboard.stripe.com/test/apikeys
```

Notice the `/test/` in the URL - this forces Test Mode!

## What You'll See in Test Mode

After clicking the link, you'll see:
- ✅ Keys starting with `pk_test_...` (instead of `pk_live_...`)
- ✅ Button says "Reveal test key" (instead of "Reveal live key")
- ✅ The page will show you're in Test Mode

## Alternative: Look for Mode Selector

Sometimes the toggle is at the **very top** of the page, above the "Developers" heading. Look for:
- A dropdown menu
- A button that says "Live" or "Test"
- A small toggle switch near the search bar

## After Switching to Test Mode

1. Click "Reveal test key" next to the Secret key
2. Copy the key (it will start with `sk_test_...`)
3. This is the key you'll use for Firebase secrets

---

**Easiest method:** Just use the direct URL: `https://dashboard.stripe.com/test/apikeys`

