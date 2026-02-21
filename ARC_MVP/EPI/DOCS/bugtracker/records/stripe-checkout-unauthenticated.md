# Stripe Checkout UNAUTHENTICATED Error

**Status:** ✅ RESOLVED  
**Date Reported:** January 10, 2026  
**Date Resolved:** January 10, 2026  
**Severity:** Critical  
**Component:** Firebase Functions / Stripe Integration

---

## Problem Summary

When users clicked "Subscribe and save $160.00" button in the subscription management screen, the `createCheckoutSession` Firebase function returned `UNAUTHENTICATED` error, even though:
- User was fully authenticated with Google
- `getUserSubscription` function worked correctly with the same auth context
- Firebase Auth tokens were valid and refreshed

## Error Message

```
[firebase_functions/unauthenticated] UNAUTHENTICATED
```

## Root Cause

**Cloud Run IAM Policy Issue**: The `createCheckoutSession` Cloud Run service was configured to "Require authentication" at the IAM level, which blocked requests before they reached the function code.

### Why `getUserSubscription` Worked But `createCheckoutSession` Didn't

1. **Different IAM policies**: Each Cloud Run service has its own IAM policy
2. **Deployment timing**: `getUserSubscription` was deployed when Firebase Functions v2 had different default IAM settings
3. **Secrets configuration**: Functions with `secrets` configuration may have different default IAM behavior

### Technical Details

For Firebase Callable Functions (Gen 2):
- The function runs on Cloud Run
- Cloud Run has an **IAM layer** that controls who can invoke the service
- Firebase Auth tokens are passed **inside** the HTTP request
- If Cloud Run IAM blocks the request, the function code never executes
- The error appears as `UNAUTHENTICATED` but is actually a Cloud Run IAM denial

## Solution

### 1. Set Cloud Run IAM Policy to Allow Public Access

1. Go to Google Cloud Console: https://console.cloud.google.com/run?project=arc-epi
2. Click on the `createcheckoutsession` service (lowercase)
3. Click the **"Security"** tab
4. Select **"Allow unauthenticated invocations"**
5. Click **Save**

### 2. Why This Is Safe

- Cloud Run allows public invocation of the underlying service
- The function code **still validates Firebase Auth** internally:
  ```javascript
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in to subscribe");
  }
  ```
- Only authenticated Firebase users can successfully use the function
- Unauthenticated requests will be rejected by the function code

### 3. Code Configuration (Optional)

The `invoker` setting in function configuration can be used, but may not always apply correctly:

```javascript
exports.createCheckoutSession = onCall(
  {
    cors: true,
    secrets: [STRIPE_SECRET_KEY, ...],
    // invoker: 'public', // May not work reliably - use Cloud Console instead
  },
  async (request) => {
    // ...
  }
);
```

**Recommendation**: Always verify IAM policy in Google Cloud Console after deployment.

## Verification Steps

1. Hot restart the app
2. Go to Settings → Subscription and Account → Subscription Management
3. Click "Subscribe and save $160.00"
4. Should be redirected to Stripe Checkout (success!)

## Debug Logging Added

Added server-side logging to help diagnose similar issues:

```javascript
console.log('createCheckoutSession: Received request');
console.log('createCheckoutSession: request.auth =', request.auth ? 'present' : 'null');
console.log('createCheckoutSession: request.rawRequest.headers.authorization =', 
  request.rawRequest?.headers?.authorization ? 'present' : 'missing');
```

## Lessons Learned

1. **Firebase Functions v2 IAM is separate from Firebase Auth**: The Cloud Run IAM layer controls who can invoke the function; Firebase Auth is handled inside the function code.

2. **Check Cloud Run IAM after deployment**: Deployments may not always apply `invoker` settings correctly.

3. **Same Firebase instance can have different IAM policies per function**: Just because one callable function works doesn't mean they all have the same IAM configuration.

4. **Error codes can be misleading**: `UNAUTHENTICATED` can mean either:
   - Cloud Run IAM rejection (request never reaches function)
   - Function code rejection (`request.auth` is null)

## Files Modified

- `functions/index.js`: Added debug logging for auth context
- Cloud Console: Set IAM policy for `createcheckoutsession` service

## Related Documentation

- [FIREBASE.md](../FIREBASE.md) - Firebase deployment and troubleshooting
- [STRIPE/STRIPE_SETUP_GUIDE.md](../STRIPE/STRIPE_SETUP_GUIDE.md) - Stripe integration setup

---

**Resolution Verified:** January 10, 2026 - Stripe checkout flow working correctly

