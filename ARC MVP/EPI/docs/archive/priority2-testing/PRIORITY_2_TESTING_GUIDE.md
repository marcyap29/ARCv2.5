# Priority 2 Testing Guide - Firebase-Only Mode

**What Changed:** All LUMARA AI calls now go through Firebase Functions instead of local API  
**Goal:** Verify everything works and rate limiting is enforced  
**Time Required:** ~20 minutes

---

## ✅ **Pre-Testing Setup**

### 1. Check Firebase Functions Are Deployed
```bash
cd /Users/mymac/Software\ Development/ARCv.04/functions
firebase functions:list
```

**Expected:** Should see these functions listed:
- ✅ `sendChatMessage`
- ✅ `generateJournalReflection`
- ✅ `getUserSubscription`
- ✅ `createCheckoutSession`

**If not listed:** Run `firebase deploy --only functions`

### 2. Launch the App
```bash
cd "/Users/mymac/Software Development/ARCv.04/ARC MVP/EPI"
flutter run
```

### 3. Sign In
- Use "Continue without sign-in (Testing)" OR
- Sign in with your test account

---

## 🧪 **Test 1: LUMARA Chat (Core Feature)**

**What we're testing:** Main LUMARA chat uses Firebase Functions

### Steps:
1. Open LUMARA assistant (chat icon)
2. Look for subscription badge in header
   - ✅ Should show "Free - Limited Access" or "Premium"
3. Send a simple message: "Hello"
4. Wait for response

### ✅ **Success Indicators:**
- [ ] Response appears (proves Firebase Function works)
- [ ] Response is relevant and in LUMARA's voice
- [ ] No error messages appear
- [ ] Subscription badge visible in header

### ❌ **Failure Indicators:**
- **Error:** "LUMARA cannot answer at the moment"
  - **Fix:** Check Firebase Functions are deployed
  - **Fix:** Check internet connection
  - **Fix:** Check Firebase Auth is working

---

## 🧪 **Test 2: In-Journal Reflections**

**What we're testing:** Journal LUMARA uses Firebase Functions

### Steps:
1. Go to Journal screen (book icon)
2. Create a new journal entry
3. Write something: "I'm feeling reflective today"
4. Tap the LUMARA button (sparkle icon)
5. Wait for reflection

### ✅ **Success Indicators:**
- [ ] LUMARA reflection appears below your text
- [ ] Reflection is thoughtful and relevant
- [ ] No error messages

### ❌ **Failure Indicators:**
- **Error:** "Firebase backend unavailable"
  - **Fix:** Check `generateJournalReflection` function is deployed

---

## 🧪 **Test 3: Rate Limiting (Critical!)**

**What we're testing:** Backend enforces 20 messages/day, 3 messages/minute

### Steps:

#### **3A. Test Per-Minute Limit**
1. Go to LUMARA chat
2. Send 3 messages quickly:
   - "Test 1"
   - "Test 2"
   - "Test 3"
3. Try to send a 4th message immediately: "Test 4"

### ✅ **Success Indicators:**
- [ ] First 3 messages work fine
- [ ] 4th message shows error dialog
- [ ] Dialog says something about rate limit
- [ ] "Upgrade" button appears in dialog

#### **3B. Test Per-Day Limit** (Optional - takes longer)
1. Send 20 messages throughout the day
2. Try to send the 21st message

### ✅ **Success Indicators:**
- [ ] First 20 messages work
- [ ] 21st message triggers rate limit error
- [ ] Upgrade dialog appears

---

## 🧪 **Test 4: Subscription Status Display**

**What we're testing:** UI shows correct subscription info

### Steps:
1. Open LUMARA chat
2. Check header badge
3. Go to Settings → Subscription Management
4. Check subscription details

### ✅ **Success Indicators:**
- [ ] Badge shows "Free - Limited Access" (if on free tier)
- [ ] Subscription screen shows:
  - [ ] Current tier name
  - [ ] "20 messages per day" limit
  - [ ] "3 messages per minute" limit
  - [ ] "30 days of history access" limit
  - [ ] Upgrade button (if free tier)

---

## 🧪 **Test 5: Error Handling**

**What we're testing:** Graceful error messages when things go wrong

### Steps:

#### **5A. No Internet Test**
1. Turn off WiFi/cellular on device
2. Try to send LUMARA message
3. Should see clear error

### ✅ **Success Indicators:**
- [ ] Error message appears
- [ ] Message says something like "Check your connection"
- [ ] App doesn't crash

#### **5B. Auth Error Test**
1. (If signed in) Sign out
2. Try to use LUMARA
3. Should prompt to sign in

### ✅ **Success Indicators:**
- [ ] Prompted to sign in OR
- [ ] Can use "Continue without sign-in" button

---

## 🚫 **Test 6: Disabled Features (Should NOT Work)**

**What we're testing:** Old local API paths are properly disabled

### Expected Behavior:
These features should throw errors if accessed:
- ❌ VEIL-EDGE integration (not used in normal flow)
- ❌ ECHO service (secondary feature)
- ❌ Lumara Share service (secondary feature)

**Note:** You probably won't encounter these in normal usage - they're not in the UI flow.

---

## 📊 **Test Results Summary**

Fill this out as you test:

| Test | Status | Notes |
|------|--------|-------|
| 1. LUMARA Chat | ⬜ Pass / ⬜ Fail | |
| 2. Journal Reflections | ⬜ Pass / ⬜ Fail | |
| 3A. Per-Minute Limit | ⬜ Pass / ⬜ Fail | |
| 3B. Per-Day Limit | ⬜ Pass / ⬜ Fail | |
| 4. Subscription Display | ⬜ Pass / ⬜ Fail | |
| 5A. No Internet Error | ⬜ Pass / ⬜ Fail | |
| 5B. Auth Error | ⬜ Pass / ⬜ Fail | |

---

## 🐛 **Common Issues & Fixes**

### Issue: "LUMARA cannot answer at the moment"
**Causes:**
1. Firebase Functions not deployed
2. No internet connection
3. Firebase Auth token expired

**Fixes:**
```bash
# Check functions are deployed
firebase functions:list

# Deploy if needed
firebase deploy --only functions

# Check Firebase project is correct
firebase use --add
```

### Issue: Rate limiting not working
**Cause:** Backend might not be enforcing limits

**Fix:** Check backend logs:
```bash
firebase functions:log --only sendChatMessage
```

### Issue: Subscription badge not showing
**Cause:** SubscriptionService not initialized

**Fix:** Check if `FirebaseService` is initialized properly

---

## ✅ **Success Criteria**

**Priority 2 is successful if:**
- ✅ LUMARA chat works (Test 1)
- ✅ Journal reflections work (Test 2)
- ✅ Rate limiting triggers error dialog (Test 3)
- ✅ Subscription status displays correctly (Test 4)
- ✅ Error messages are clear and helpful (Test 5)

**Optional Success:**
- ✅ All 7 tests pass
- ✅ No crashes or freezes
- ✅ Performance feels smooth

---

## 📝 **After Testing**

### If All Tests Pass:
1. Report success: "All Priority 2 tests passed ✅"
2. Ready to merge branches
3. Ready for production deployment

### If Some Tests Fail:
1. Note which test failed
2. Include error message
3. Include steps to reproduce
4. We'll debug together

---

## 🎯 **Quick Test (5 minutes)**

If you're short on time, just do these:
1. ✅ Send one LUMARA chat message (Test 1)
2. ✅ Generate one journal reflection (Test 2)
3. ✅ Check subscription badge shows up (Test 4)

If those 3 work, Priority 2 is probably fine. Full testing can come later.

---

**Ready to test? Start with Test 1 and work your way down!**

