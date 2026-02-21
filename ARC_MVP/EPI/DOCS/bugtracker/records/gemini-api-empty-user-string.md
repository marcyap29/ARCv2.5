# Gemini API Empty User String Error

**Bug ID:** gemini-api-empty-user-string  
**Status:** ✅ **RESOLVED**  
**Severity:** Critical  
**Component:** Firebase Functions / Gemini API Integration  
**Date Reported:** January 10, 2026  
**Date Resolved:** January 10, 2026

---

## Problem

When generating LUMARA reflections for journal entries, users received the error:
```
LUMARA reflection failed: Exception: Gemini API request failed: system and user parameters are required
```

### Root Cause

The `proxyGemini` Firebase function was rejecting requests when the `user` parameter was an empty string (`''`). This occurred because:

1. **Journal reflections use unified prompt**: All content is in the `system` prompt, with `user` set to empty string
2. **Original validation logic**: The function checked `!user`, which treats empty strings as falsy in JavaScript
3. **Error location**: `enhanced_lumara_api.dart` line 581 calls `geminiSend()` with `user: ''` for journal reflections

### Impact

- **Critical**: Journal reflections completely broken
- **User Experience**: Users could not generate LUMARA reflections for their journal entries
- **Error Message**: Confusing error that didn't indicate the actual issue

---

## Solution

### Code Changes

**File:** `functions/index.js`

**Before:**
```javascript
if (!system || !user) {
  throw new HttpsError("invalid-argument", "system and user parameters are required");
}
```

**After:**
```javascript
// Allow empty string for user (when all content is in system prompt)
// But require that parameters are provided (not null/undefined)
if (system == null || user == null) {
  throw new HttpsError("invalid-argument", "system and user parameters are required");
}

// Convert to string if needed (handles correlation-resistant transformation objects)
const systemStr = typeof system === 'string' ? system : JSON.stringify(system);
const userStr = typeof user === 'string' ? user : JSON.stringify(user);

// Ensure at least one has content (allow empty user if system has content)
if (systemStr.trim().length === 0 && userStr.trim().length === 0) {
  throw new HttpsError("invalid-argument", "At least one of system or user must have content");
}
```

### Key Improvements

1. **Null/undefined check**: Changed from falsy check (`!user`) to explicit null check (`user == null`)
2. **Empty string support**: Now allows empty strings for `user` when `system` has content
3. **Type handling**: Handles both string and object types (for correlation-resistant transformation)
4. **Better validation**: Ensures at least one parameter has content

### Files Modified

- `functions/index.js`: Updated `proxyGemini` validation logic (lines 148-161, 182-190)
- Added debug logging for parameter validation

---

## Testing

### Test Cases

1. ✅ **Journal Reflection**: Empty `user` string with full `system` prompt → Should work
2. ✅ **Chat Mode**: Both `system` and `user` have content → Should work
3. ✅ **Null Parameters**: Either parameter is null/undefined → Should error appropriately
4. ✅ **Both Empty**: Both `system` and `user` are empty → Should error appropriately

### Verification

- Function deployed successfully: `2026-01-10T05:00:00`
- Function status: Active (v2, callable, us-central1)
- Tested with journal entry reflection → ✅ Success

---

## Related Issues

- Related to unified prompt system (v3.2) where all content is in system prompt
- Similar to: [lumara-user-prompt-override.md](lumara-user-prompt-override.md)

---

## Commit Information

**Commit:** `bd2f8065c`  
**Branch:** `dev` → `main`  
**Date:** January 10, 2026  
**Message:** `feat: LUMARA improvements - temporal context, persona updates, settings simplification`

**Files Changed:**
- `functions/index.js`: Updated validation logic for empty user strings

---

## Resolution Verified

**Date:** January 10, 2026  
**Status:** ✅ **RESOLVED** - Function deployed and tested successfully

---

## Additional Notes

- Added debug logging to help diagnose similar issues in the future
- Function now properly handles correlation-resistant transformation objects
- Empty string support is critical for unified prompt system architecture

