# Throttle Unlock Setup

## Overview

The throttle unlock feature allows developers/admins to bypass rate limits with a password-protected unlock. This is useful for testing and development.

## Setup

### 1. Set the Throttle Unlock Password

```bash
firebase functions:secrets:set THROTTLE_UNLOCK_PASSWORD
```

When prompted, enter your desired password. This password will be required to unlock throttles.

**Security Note:** Choose a strong password and keep it secure. This password controls access to bypass rate limits.

### 2. Deploy Functions

```bash
cd functions
npm run build  # If TypeScript compilation is needed
cd ..
firebase deploy --only functions
```

## How It Works

### Backend

1. **Rate Limiter Check**: The `checkRateLimit()` function checks:
   - User's plan (free/pro)
   - `throttleUnlocked` field in user document
   - If either is true, rate limits are bypassed

2. **Unlock Function**: `unlockThrottle` Cloud Function:
   - Verifies password against `THROTTLE_UNLOCK_PASSWORD` secret
   - Uses constant-time comparison to prevent timing attacks
   - Sets `throttleUnlocked: true` in user's Firestore document

3. **Lock Function**: `lockThrottle` Cloud Function:
   - Removes throttle unlock from user document
   - Re-enables rate limiting

4. **Status Check**: `checkThrottleStatus` Cloud Function:
   - Returns current unlock status for the user

### Frontend

1. **Settings Menu**: "Throttle" option added to Privacy & Security section
2. **Password Input**: Empty text field (no character count indicator)
3. **Unlock Button**: Submits password to `unlockThrottle` function
4. **Status Display**: Shows locked/unlocked state
5. **Lock Button**: Allows re-locking the throttle

## User Experience

1. User navigates to Settings → Privacy & Security → Throttle
2. Sees current status (Locked/Unlocked)
3. If locked, enters password in empty text field
4. Clicks "Unlock Throttle"
5. If password is correct, throttle is unlocked
6. Rate limits are bypassed for this user
7. User can lock throttle again if needed

## Security Features

- Password stored as Firebase secret (encrypted)
- Constant-time password comparison (prevents timing attacks)
- Password input has no character count indicator
- Password field is obscured by default
- Only authenticated users can unlock throttle
- Unlock status stored in Firestore per user

## Firestore Schema

```typescript
users/{userId}
{
  throttleUnlocked: boolean,        // true if throttle is unlocked
  throttleUnlockedAt: Timestamp,    // When throttle was unlocked
  // ... other user fields
}
```

## Testing

1. Set password: `firebase functions:secrets:set THROTTLE_UNLOCK_PASSWORD`
2. Deploy functions
3. Open app → Settings → Throttle
4. Enter password
5. Verify throttle unlocks
6. Test that rate limits are bypassed
7. Lock throttle and verify limits are re-enabled

