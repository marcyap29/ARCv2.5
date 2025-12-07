# Priority 2: Authentication TODO

## ⚠️ Temporary Workaround Active

**Status:** Auth requirement temporarily bypassed for MVP testing

### What Was Changed

**Files Modified:**
- `functions/src/functions/sendChatMessage.ts`
- `functions/src/functions/generateJournalReflection.ts`

**Change:**
```typescript
// TEMPORARY (current):
const userId = request.auth?.uid || `mvp_test_${Date.now()}`;

// TODO: Restore this after Priority 2 testing:
const userId = request.auth?.uid;
if (!userId) {
  throw new HttpsError("unauthenticated", "User must be authenticated");
}
```

### Why This Workaround?

**Problem:** Firebase Functions v2 + Anonymous Auth integration issue
- Anonymous sign-in works in the app ✅
- Auth tokens are generated ✅
- Functions reject the tokens ❌ (UNAUTHENTICATED error)

**Root Cause:** Likely IAM permissions or Firebase Functions v2 configuration issue with anonymous auth

**Decision:** Bypass auth temporarily to unblock Priority 2 testing (API redirection & backend security)

---

## 🔒 Security Status

**What's Still Secure:**
- ✅ Gemini API key stored in Firebase Secrets (not in app)
- ✅ All AI requests go through Firebase backend
- ✅ Rate limiting enforced server-side
- ✅ No API keys in client code

**What's Temporarily Insecure:**
- ⚠️ Anyone can call the functions (no per-user auth)
- ⚠️ No subscription-based access control enforcement
- ⚠️ Rate limits apply globally, not per-user

**Risk Level:** Low for MVP/testing (app not public, no billing active)

---

## 🔧 How to Restore Proper Auth (Priority 3)

### Option A: Fix Anonymous Auth Integration

1. **Check IAM Permissions:**
   ```bash
   gcloud functions get-iam-policy sendChatMessage \
     --region=us-central1 \
     --project=arc-epi
   ```

2. **Add policy for authenticated users:**
   ```bash
   gcloud functions add-iam-policy-binding sendChatMessage \
     --region=us-central1 \
     --member="allAuthenticatedUsers" \
     --role="roles/cloudfunctions.invoker" \
     --project=arc-epi
   ```

3. **Restore auth checks in functions**

4. **Test with anonymous user**

### Option B: Require Email/Google Sign-In

1. Disable anonymous auth in Firebase Console
2. Require email or Google OAuth
3. Restore auth checks
4. Update UI to require sign-in

---

## 📋 Testing Checklist (Before Restoring Auth)

- [ ] LUMARA chat works through Firebase
- [ ] In-journal reflections work through Firebase
- [ ] Rate limiting works
- [ ] Error handling works
- [ ] No local API keys used
- [ ] Firebase logs show proper function calls

---

## 📝 Notes

**Date Implemented:** 2025-12-05
**Branch:** `priority-2-api-refactor`
**Commits:** 
- `b577fd22` - temp: Remove auth requirement for Priority 2 MVP testing

**Next Steps:**
1. Complete Priority 2 testing
2. Decide on auth strategy (anonymous vs email)
3. Implement proper auth (Priority 3)
4. Remove this workaround

