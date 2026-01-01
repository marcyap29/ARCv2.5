# How to Get Your Webhook Signing Secret

## You're Already on the Right Page! ✅

I can see you're on the webhook details page for "arc-webhook". The signing secret is right there in the right panel!

---

## Step-by-Step: Get Your Signing Secret

### What You're Looking At

In the **right panel**, you'll see a section called:

**"Signing secret"** (with a lock icon 🔒)

Below that, you'll see:
- A description about verifying events
- A **masked field** showing: `whsec_•••••••••••`
- An **eye icon** 👁️ (to reveal the secret)
- A **refresh icon** 🔄 (to roll/generate a new secret)

### How to Reveal It

1. **Click the eye icon** 👁️ next to the masked secret
2. The secret will be **revealed** and you'll see the full value
3. It will look like: `whsec_1SkpWVA8MaaAomE3QXtnO4vV...` (long string)
4. **Copy the entire secret** - you'll need it for Firebase

### What to Do With It

Once you have the secret (starts with `whsec_`):

1. **Save it somewhere safe** (you'll paste it into Firebase)
2. **Add it to Firebase Secret Manager** (Step 4 in the setup guide)
3. Run this command:
   ```bash
   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
   ```
4. When prompted, paste your `whsec_...` secret

---

## Quick Visual Guide

**Right Panel → Signing Secret Section:**
```
┌─────────────────────────────────┐
│ Signing secret 🔒                │
│                                  │
│ Use this secret to verify...     │
│                                  │
│ [whsec_•••••••••••] 👁️ 🔄       │
│   ↑ Click the eye icon here!     │
└─────────────────────────────────┘
```

---

## Important Notes

- ✅ **Don't share this secret** - it's sensitive
- ✅ **Keep it secure** - only use it in Firebase Secret Manager
- ✅ **Don't commit it to git** - it's stored securely in Firebase
- ✅ **You can roll it** - if compromised, click the refresh icon to generate a new one

---

## Next Steps

After you get the secret:

1. Copy it (the full `whsec_...` string)
2. Go to Step 4 in `STRIPE_SECRETS_SETUP.md`
3. Run: `firebase functions:secrets:set STRIPE_WEBHOOK_SECRET`
4. Paste the secret when prompted

---

**You're almost done!** Just click that eye icon 👁️ and copy the secret! 🎯

