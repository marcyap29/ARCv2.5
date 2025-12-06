# Priority 1 & 1.5 Testing Guide

**Last Updated:** December 6, 2025  
**Version:** 1.0  
**Status:** Ready for Testing

---

## Overview

This document provides comprehensive testing procedures for Priority 1 (Authentication) and Priority 1.5 (Subscription Management) features.

### Testing Scope

**Priority 1 - Authentication:**
- Email/password authentication
- Firebase Auth integration
- Sign-in/sign-out flows
- Auth state persistence
- Navigation and routing

**Priority 1.5 - Subscription & Access Control:**
- Subscription tier management (Free/Premium)
- LUMARA rate limiting
- Phase history access control
- Stripe integration
- Upgrade/downgrade flows

---

## Prerequisites

### Required Setup

1. **Firebase Configuration**
   - Firebase project initialized
   - Authentication enabled
   - Cloud Functions deployed

2. **API Keys Configured**
   ```bash
   # Verify these secrets are set
   firebase functions:secrets:access GEMINI_API_KEY
   firebase functions:secrets:access THROTTLE_UNLOCK_PASSWORD
   # Optional for full testing:
   firebase functions:secrets:access STRIPE_SECRET_KEY
   ```

3. **Test Accounts**
   - Create 2 test email accounts for testing
   - Have Stripe test card ready: `4242 4242 4242 4242`

4. **Clean Test Environment**
   ```bash
   cd "ARC MVP/EPI"
   flutter clean
   flutter pub get
   ```

---

## Priority 1 Testing: Authentication

### Test 1.1: Email/Password Sign-Up

**Objective:** Verify new users can create accounts

**Steps:**
1. Launch app (fresh install or after sign-out)
2. Tap "Sign Up" or "Create Account"
3. Enter test email: `test1@example.com`
4. Enter password: `TestPass123!`
5. Confirm password: `TestPass123!`
6. Tap "Create Account"

**Expected Results:**
- ✅ No validation errors
- ✅ Loading indicator appears
- ✅ Account created successfully
- ✅ User navigated to main app screen
- ✅ Firebase Auth shows new user in console

**Pass Criteria:** All checkboxes marked ✅

---

### Test 1.2: Email/Password Sign-In

**Objective:** Verify existing users can sign in

**Steps:**
1. Sign out from app
2. Return to sign-in screen
3. Enter email: `test1@example.com`
4. Enter password: `TestPass123!`
5. Tap "Sign In"

**Expected Results:**
- ✅ No validation errors
- ✅ Loading indicator appears
- ✅ Sign-in successful
- ✅ User navigated to main app screen
- ✅ User data loaded correctly

**Pass Criteria:** All checkboxes marked ✅

---

### Test 1.3: Authentication State Persistence

**Objective:** Verify auth state persists across app restarts

**Steps:**
1. Sign in with test account
2. Navigate to Journal screen
3. Create a test journal entry
4. Close app completely (swipe up from app switcher)
5. Reopen app

**Expected Results:**
- ✅ App opens directly to main screen (no sign-in screen)
- ✅ User still authenticated
- ✅ Previous journal entry visible
- ✅ No data loss

**Pass Criteria:** All checkboxes marked ✅

---

### Test 1.4: Sign-Out Flow

**Objective:** Verify users can sign out properly

**Steps:**
1. While signed in, go to Settings
2. Scroll to bottom
3. Tap "Sign Out"
4. Confirm sign-out if prompted

**Expected Results:**
- ✅ User signed out immediately
- ✅ Navigated to sign-in screen
- ✅ Local user data cleared
- ✅ Firebase auth state cleared
- ✅ Cannot access protected screens

**Pass Criteria:** All checkboxes marked ✅

---

### Test 1.5: Invalid Credentials

**Objective:** Verify proper error handling for invalid credentials

**Steps:**
1. Go to sign-in screen
2. Enter email: `test1@example.com`
3. Enter wrong password: `WrongPassword123`
4. Tap "Sign In"

**Expected Results:**
- ✅ Error message displayed
- ✅ Message says "Invalid credentials" or similar
- ✅ User remains on sign-in screen
- ✅ No navigation occurs
- ✅ Can retry with correct password

**Pass Criteria:** All checkboxes marked ✅

---

### Test 1.6: Password Reset Flow

**Objective:** Verify password reset functionality

**Steps:**
1. Go to sign-in screen
2. Tap "Forgot Password?" link
3. Enter email: `test1@example.com`
4. Tap "Send Reset Email"
5. Check email inbox (Firebase Console → Authentication → Email Templates to view)

**Expected Results:**
- ✅ Success message displayed
- ✅ Reset email sent (verify in console)
- ✅ Email contains reset link
- ✅ Reset link works (optional: complete reset)

**Pass Criteria:** All checkboxes marked ✅

---

### Test 1.7: Testing Bypass

**Objective:** Verify "Continue without sign-in" works for development

**Steps:**
1. Go to sign-in screen
2. Look for "Continue without sign-in" button
3. Tap button

**Expected Results:**
- ✅ Button exists (for development builds)
- ✅ Navigates to main app
- ✅ App functions in limited/demo mode
- ✅ Firebase auth shows anonymous user (optional)

**Pass Criteria:** All checkboxes marked ✅

---

## Priority 1.5 Testing: Subscription Management

### Test 2.1: Free Tier Default

**Objective:** Verify new users start on free tier

**Steps:**
1. Create new account: `freeuser@example.com`
2. Complete sign-up
3. Navigate to Settings → Subscription
4. Check LUMARA subscription status badge

**Expected Results:**
- ✅ New user account created
- ✅ Subscription status shows "Free"
- ✅ Badge displays: "Free - Limited Access"
- ✅ Limits shown: "20 requests per day, 3 per minute"
- ✅ Phase history limited to 30 days message

**Pass Criteria:** All checkboxes marked ✅

---

### Test 2.2: LUMARA Rate Limiting (Daily Limit)

**Objective:** Verify daily rate limit enforced for free tier

**Setup:**
```dart
// For testing, you can temporarily reduce limits in backend
// functions/src/functions/rateLimitMiddleware.ts
const FREE_TIER_DAILY_LIMIT = 5; // Instead of 20
```

**Steps:**
1. Sign in as free tier user
2. Go to Journal screen
3. Create entry with text: "Test entry 1"
4. Tap LUMARA button to get reflection
5. Repeat steps 3-4 for entries 2, 3, 4, 5
6. Try 6th LUMARA request

**Expected Results:**
- ✅ First 5 requests succeed
- ✅ 6th request shows error
- ✅ Error message: "Daily limit reached (5/5)"
- ✅ Message suggests upgrading to Premium
- ✅ Retry after limit resets works

**Pass Criteria:** All checkboxes marked ✅

---

### Test 2.3: LUMARA Rate Limiting (Per-Minute Limit)

**Objective:** Verify per-minute rate limit enforced

**Steps:**
1. Sign in as free tier user
2. Go to Journal screen
3. Create test entry
4. Rapidly tap LUMARA button 4 times within 10 seconds

**Expected Results:**
- ✅ First 3 requests succeed
- ✅ 4th request shows error
- ✅ Error message: "Too many requests. Please wait."
- ✅ Wait 60 seconds
- ✅ Next request succeeds

**Pass Criteria:** All checkboxes marked ✅

---

### Test 2.4: Phase History Access Control (Free Tier)

**Objective:** Verify free tier only sees last 30 days of phase history

**Setup:**
```bash
# Create test entries spanning 60 days
# Can use a script or manually adjust dates
```

**Steps:**
1. Sign in as free tier user
2. Create journal entries with dates:
   - Today
   - 15 days ago
   - 30 days ago
   - 45 days ago
   - 60 days ago
3. Navigate to Insights → Phase (or Advanced Analytics)
4. View phase history timeline

**Expected Results:**
- ✅ Today's entry visible
- ✅ 15-day-old entry visible
- ✅ 30-day-old entry visible
- ✅ 45-day-old entry NOT visible
- ✅ 60-day-old entry NOT visible
- ✅ Message: "Free tier: Access limited to last 30 days"

**Pass Criteria:** All checkboxes marked ✅

---

### Test 2.5: Subscription Upgrade Flow

**Objective:** Verify Stripe checkout and upgrade to Premium

**Prerequisites:**
- Stripe configured in test mode
- STRIPE_SECRET_KEY set in Firebase

**Steps:**
1. Sign in as free tier user: `freeuser@example.com`
2. Go to Settings → Subscription
3. Tap "Upgrade to Premium" button
4. Review upgrade dialog
5. Tap "Upgrade Now"
6. Complete Stripe checkout:
   - Card: `4242 4242 4242 4242`
   - Expiry: Any future date (e.g., `12/25`)
   - CVC: Any 3 digits (e.g., `123`)
   - Zip: Any zip code (e.g., `12345`)
7. Complete payment

**Expected Results:**
- ✅ Stripe checkout opens
- ✅ Shows correct amount: $30.00/month
- ✅ Payment processes successfully
- ✅ Redirects back to app
- ✅ Subscription status updates to "Premium"
- ✅ Badge shows: "Premium - Full Access"
- ✅ Firestore user document shows `plan: "premium"`

**Pass Criteria:** All checkboxes marked ✅

---

### Test 2.6: Premium Tier Benefits

**Objective:** Verify premium users have unlimited access

**Steps:**
1. Sign in as premium user (from Test 2.5)
2. Go to Journal screen
3. Make 25+ LUMARA requests (more than free limit)
4. Navigate to phase history
5. View entries older than 30 days

**Expected Results:**
- ✅ All 25+ LUMARA requests succeed
- ✅ No rate limit errors
- ✅ No daily limit warnings
- ✅ Phase history shows all entries (60+ days)
- ✅ Status badge shows "Premium"
- ✅ Benefits message: "Unlimited LUMARA requests, Full phase history"

**Pass Criteria:** All checkboxes marked ✅

---

### Test 2.7: Subscription Status Persistence

**Objective:** Verify subscription persists across app restarts

**Steps:**
1. Sign in as premium user
2. Verify premium status
3. Close app completely
4. Reopen app
5. Check subscription status

**Expected Results:**
- ✅ App reopens with user signed in
- ✅ Subscription status still "Premium"
- ✅ LUMARA requests work without limits
- ✅ Full phase history accessible
- ✅ No tier downgrade

**Pass Criteria:** All checkboxes marked ✅

---

### Test 2.8: Stripe Webhook - Payment Success

**Objective:** Verify webhook updates user to premium on payment

**Steps:**
1. Complete Stripe checkout as in Test 2.5
2. Monitor Firebase Functions logs:
   ```bash
   firebase functions:log --only stripeWebhook
   ```
3. Check Firestore:
   - Navigate to Firebase Console → Firestore
   - Find user document
   - Verify fields updated

**Expected Results:**
- ✅ Webhook receives `checkout.session.completed` event
- ✅ User document updated:
   - `plan: "premium"`
   - `stripeSubscriptionId: "sub_xxxxx"`
   - `stripeCustomerId: "cus_xxxxx"`
- ✅ Functions log shows successful processing
- ✅ No errors in webhook execution

**Pass Criteria:** All checkboxes marked ✅

---

### Test 2.9: Subscription Cancellation

**Objective:** Verify user can cancel subscription

**Steps:**
1. Sign in as premium user
2. Go to Settings → Subscription
3. Tap "Manage Subscription"
4. Tap "Cancel Subscription"
5. Confirm cancellation
6. Wait for webhook to process

**Expected Results:**
- ✅ Cancellation confirmation dialog appears
- ✅ User confirms cancellation
- ✅ Webhook receives `customer.subscription.deleted` event
- ✅ User downgraded to free tier in Firestore
- ✅ App subscription status updates to "Free"
- ✅ Rate limits re-enabled
- ✅ Phase history limited to 30 days

**Pass Criteria:** All checkboxes marked ✅

---

### Test 2.10: Payment Failure Handling

**Objective:** Verify graceful handling of payment failures

**Steps:**
1. Sign in as free user
2. Go to Settings → Subscription
3. Tap "Upgrade to Premium"
4. In Stripe checkout, use decline card: `4000 0000 0000 0002`
5. Complete checkout

**Expected Results:**
- ✅ Payment fails
- ✅ Error message shown: "Payment declined"
- ✅ User returns to app
- ✅ Subscription remains "Free"
- ✅ No partial state (user not upgraded)
- ✅ Can retry with valid card

**Pass Criteria:** All checkboxes marked ✅

---

## Integration Testing

### Test 3.1: End-to-End User Journey (Free User)

**Objective:** Complete user flow from sign-up to hitting limits

**Steps:**
1. Fresh app install
2. Create account: `journey1@example.com`
3. Complete onboarding (if any)
4. Create first journal entry: "Today was a good day"
5. Tap LUMARA for reflection
6. Create 5 more entries with LUMARA reflections
7. View phase history
8. Make 20 LUMARA requests total
9. Try 21st request

**Expected Results:**
- ✅ Sign-up successful
- ✅ First entry created
- ✅ LUMARA reflection generated
- ✅ All 6 entries saved
- ✅ Phase history shows recent entries only
- ✅ 20 requests succeed
- ✅ 21st request blocked with upgrade prompt

**Pass Criteria:** All checkboxes marked ✅

---

### Test 3.2: End-to-End User Journey (Premium User)

**Objective:** Complete user flow from sign-up to premium features

**Steps:**
1. Fresh app install
2. Create account: `journey2@example.com`
3. Create 3 journal entries
4. Go to Settings → Subscription
5. Upgrade to Premium (Stripe test card)
6. Create 25 journal entries with LUMARA
7. View full phase history
8. Create entries spanning 60 days (adjust dates)
9. Verify all history accessible

**Expected Results:**
- ✅ Account created and signed in
- ✅ Initial entries created
- ✅ Upgrade to Premium successful
- ✅ All 25 LUMARA requests succeed
- ✅ No rate limiting
- ✅ Full 60-day phase history visible
- ✅ Premium badge displayed throughout

**Pass Criteria:** All checkboxes marked ✅

---

## Performance Testing

### Test 4.1: Auth Performance

**Objective:** Verify authentication completes in reasonable time

**Steps:**
1. Time sign-in flow from tapping "Sign In" to main screen
2. Measure cold start time for authenticated user
3. Measure sign-out time

**Expected Results:**
- ✅ Sign-in completes in < 3 seconds
- ✅ Cold start for authenticated user < 2 seconds
- ✅ Sign-out completes in < 1 second

**Pass Criteria:** All timing expectations met

---

### Test 4.2: Subscription Check Performance

**Objective:** Verify subscription checks don't slow down app

**Steps:**
1. Sign in as premium user
2. Navigate between screens (Journal, LUMARA, Insights)
3. Monitor for lag or delays

**Expected Results:**
- ✅ No noticeable lag when checking subscription
- ✅ Subscription checks cached appropriately
- ✅ Navigation remains smooth
- ✅ LUMARA responses not delayed by tier checks

**Pass Criteria:** All checkboxes marked ✅

---

## Error Handling & Edge Cases

### Test 5.1: Network Connectivity Loss

**Objective:** Verify graceful handling of network issues

**Steps:**
1. Sign in while online
2. Enable airplane mode
3. Try to make LUMARA request
4. Disable airplane mode
5. Retry LUMARA request

**Expected Results:**
- ✅ Offline error shown clearly
- ✅ App doesn't crash
- ✅ Subscription tier cached locally
- ✅ Request succeeds when back online

**Pass Criteria:** All checkboxes marked ✅

---

### Test 5.2: Concurrent Sign-In Attempts

**Objective:** Verify handling of multiple sign-in attempts

**Steps:**
1. Go to sign-in screen
2. Enter credentials
3. Rapidly tap "Sign In" 5 times

**Expected Results:**
- ✅ Only one sign-in attempt processes
- ✅ No duplicate user sessions
- ✅ Loading state prevents multiple taps
- ✅ Successfully signs in once

**Pass Criteria:** All checkboxes marked ✅

---

### Test 5.3: Subscription Tier Sync Issues

**Objective:** Verify recovery from tier sync issues

**Steps:**
1. Sign in as premium user
2. Manually change Firestore `plan` field to "free"
3. Refresh subscription status in app
4. Verify correction

**Expected Results:**
- ✅ App detects tier mismatch
- ✅ Queries Firebase Functions for truth
- ✅ Correct tier restored
- ✅ Rate limits apply correctly based on actual tier

**Pass Criteria:** All checkboxes marked ✅

---

## Security Testing

### Test 6.1: JWT Token Validation

**Objective:** Verify Firebase tokens are validated

**Steps:**
1. Sign in successfully
2. Make LUMARA API request
3. Monitor network traffic (optional)
4. Verify token included in requests

**Expected Results:**
- ✅ All API requests include Firebase Auth token
- ✅ Backend validates token
- ✅ Invalid tokens rejected
- ✅ Expired tokens refreshed automatically

**Pass Criteria:** All checkboxes marked ✅

---

### Test 6.2: Rate Limit Bypass Prevention

**Objective:** Verify rate limits cannot be bypassed

**Steps:**
1. Sign in as free user
2. Hit daily rate limit (20 requests)
3. Try to bypass by:
   - Clearing app data
   - Signing out and back in
   - Changing device time
4. Verify limit still enforced

**Expected Results:**
- ✅ Rate limit persists after clear data
- ✅ Rate limit tied to user account (not device)
- ✅ Time manipulation doesn't bypass limit
- ✅ Limit enforced server-side (Firebase Functions)

**Pass Criteria:** All checkboxes marked ✅

---

## Test Results Summary

### Priority 1: Authentication

| Test ID | Test Name | Pass/Fail | Notes |
|---------|-----------|-----------|-------|
| 1.1 | Email/Password Sign-Up | | |
| 1.2 | Email/Password Sign-In | | |
| 1.3 | Auth State Persistence | | |
| 1.4 | Sign-Out Flow | | |
| 1.5 | Invalid Credentials | | |
| 1.6 | Password Reset | | |
| 1.7 | Testing Bypass | | |

### Priority 1.5: Subscription Management

| Test ID | Test Name | Pass/Fail | Notes |
|---------|-----------|-----------|-------|
| 2.1 | Free Tier Default | | |
| 2.2 | Daily Rate Limiting | | |
| 2.3 | Per-Minute Limiting | | |
| 2.4 | Phase History Access (Free) | | |
| 2.5 | Subscription Upgrade | | |
| 2.6 | Premium Tier Benefits | | |
| 2.7 | Status Persistence | | |
| 2.8 | Stripe Webhook Success | | |
| 2.9 | Subscription Cancellation | | |
| 2.10 | Payment Failure | | |

### Integration Tests

| Test ID | Test Name | Pass/Fail | Notes |
|---------|-----------|-----------|-------|
| 3.1 | E2E Free User Journey | | |
| 3.2 | E2E Premium User Journey | | |

### Performance Tests

| Test ID | Test Name | Pass/Fail | Notes |
|---------|-----------|-----------|-------|
| 4.1 | Auth Performance | | |
| 4.2 | Subscription Check Performance | | |

### Error Handling Tests

| Test ID | Test Name | Pass/Fail | Notes |
|---------|-----------|-----------|-------|
| 5.1 | Network Loss | | |
| 5.2 | Concurrent Sign-In | | |
| 5.3 | Tier Sync Issues | | |

### Security Tests

| Test ID | Test Name | Pass/Fail | Notes |
|---------|-----------|-----------|-------|
| 6.1 | JWT Token Validation | | |
| 6.2 | Rate Limit Bypass Prevention | | |

---

## Known Issues

Document any issues found during testing:

1. **Issue:** [Description]
   - **Severity:** High/Medium/Low
   - **Status:** Open/In Progress/Resolved
   - **Workaround:** [If any]

---

## Testing Sign-Off

**Tester Name:** _______________  
**Date:** _______________  
**Overall Status:** ☐ Pass ☐ Fail ☐ Pass with Issues

**Comments:**
```
[Add any additional testing notes or observations]
```

---

## Next Steps

After completing Priority 1 & 1.5 testing:

1. **Fix Critical Issues** - Address any blocking bugs
2. **Document Workarounds** - For known minor issues
3. **Update Priority 2 Plan** - Prepare for API redirection
4. **Production Readiness** - Complete OAuth setup for production
5. **Deploy to TestFlight/Beta** - External testing phase

---

**Testing Guide Status:** ✅ Complete and Ready  
**Last Updated:** December 6, 2025  
**Version:** 1.0


