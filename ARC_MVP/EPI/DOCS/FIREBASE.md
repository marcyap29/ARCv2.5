# Firebase Deployment & Management

This document covers Firebase CLI commands for deploying and managing the ARC application's backend services.

## Prerequisites

```bash
# Install Firebase CLI globally
npm install -g firebase-tools

# Login to Firebase
firebase login

# Verify you're logged in
firebase login:list
```

## Avoiding Frequent Re-Authentication (Recommended)

Firebase CLI tokens expire every 1-2 weeks. Use **gcloud Application Default Credentials (ADC)** for longer-lasting authentication:

### One-Time Setup

```bash
# Install gcloud CLI (macOS)
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-arm.tar.gz
tar -xzf google-cloud-cli-darwin-arm.tar.gz -C ~/
~/google-cloud-sdk/install.sh --quiet --path-update true
rm google-cloud-cli-darwin-arm.tar.gz

# Restart terminal or source config
source ~/.zshrc

# Authenticate with gcloud ADC (opens browser)
~/google-cloud-sdk/bin/gcloud auth application-default login

# Also login to Firebase normally
firebase login
```

### Why This Works

- **gcloud ADC** creates credentials at `~/.config/gcloud/application_default_credentials.json`
- Many Firebase/Google services automatically use these credentials as fallback
- ADC tokens last longer than Firebase CLI tokens
- You have two layers of auth: Firebase CLI + gcloud ADC

### If Firebase Session Expires

```bash
# Re-authenticate Firebase CLI
firebase login --reauth

# Set your project
firebase use arc-epi

# Deploy
firebase deploy --only functions --force
```

### Fix Permission Issues

If you see "firebase-tools update check failed", fix config permissions:

```bash
sudo chown -R $USER:$(id -gn $USER) ~/.config
```

## Project Setup

```bash
# List available projects
firebase projects:list

# Check current project
firebase use

# Switch to a specific project
firebase use <project-id>

# Initialize Firebase in a new directory
firebase init
```

## Deployment Commands

### Deploy Everything

```bash
# Deploy all Firebase services (functions, hosting, rules, etc.)
firebase deploy
```

### Deploy Functions Only

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy a specific function
firebase deploy --only functions:createCheckoutSession
firebase deploy --only functions:getUserSubscription
firebase deploy --only functions:createPortalSession
firebase deploy --only functions:proxyGemini

# Deploy multiple specific functions
firebase deploy --only functions:createCheckoutSession,functions:getUserSubscription
```

### Deploy Other Services

```bash
# Deploy hosting only
firebase deploy --only hosting

# Deploy Firestore rules only
firebase deploy --only firestore:rules

# Deploy Firestore indexes
firebase deploy --only firestore:indexes

# Deploy storage rules
firebase deploy --only storage
```

## Firebase Authentication

### Enable Auth Providers (Firebase Console)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Authentication** → **Sign-in method**
4. Enable desired providers:
   - **Google** (recommended for ARC)
   - Email/Password
   - Anonymous (for trial users)

### Google Sign-In Setup

#### iOS Setup

1. Download `GoogleService-Info.plist` from Firebase Console
2. Add to `ios/Runner/` directory
3. Add URL scheme to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Reversed client ID from GoogleService-Info.plist -->
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

#### Android Setup

1. Download `google-services.json` from Firebase Console
2. Add to `android/app/` directory
3. Add SHA-1 fingerprint to Firebase Console:

```bash
# Get debug SHA-1
cd android
./gradlew signingReport
```

### Auth Emulator

```bash
# Start auth emulator
firebase emulators:start --only auth

# Start with functions (for testing callable auth)
firebase emulators:start --only auth,functions
```

### Export/Import Auth Users

```bash
# Export users to JSON
firebase auth:export users.json --format=json

# Import users
firebase auth:import users.json
```

### Manage Users (CLI)

```bash
# List users (requires Admin SDK, typically done in code)
# Use Firebase Console for user management
```

### Flutter Auth Configuration

In your Flutter app (`lib/services/firebase_auth_service.dart`):

```dart
// Initialize Google Sign-In
final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
await _googleSignIn.initialize();

// Sign in with Google
final googleUser = await _googleSignIn.authenticate(
  scopeHint: ['email', 'profile'],
);

// Get Firebase credential
final credential = GoogleAuthProvider.credential(
  accessToken: accessToken,
  idToken: googleAuth.idToken,
);

// Sign in to Firebase
final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
```

### Auth Token Management

```dart
// Get current user's ID token
final token = await FirebaseAuth.instance.currentUser?.getIdToken();

// Force refresh token
final freshToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);

// Listen to auth state changes
FirebaseAuth.instance.authStateChanges().listen((User? user) {
  if (user != null) {
    print('User signed in: ${user.email}');
  } else {
    print('User signed out');
  }
});
```

### Common Auth Issues

| Issue | Solution |
|-------|----------|
| `UNAUTHENTICATED` error in callable | Ensure `getIdToken(true)` is called before callable |
| Google Sign-In not working | Check SHA-1 fingerprint and OAuth consent screen |
| Token expired | Call `getIdToken(true)` to force refresh |
| Anonymous user can't subscribe | Prompt user to sign in with Google first |

### Fixing `UNAUTHENTICATED` Errors in Firebase Callable Functions

The most common cause of `[firebase_functions/unauthenticated] UNAUTHENTICATED` errors is that the auth token isn't being sent with the callable request.

#### Root Cause

Firebase callable functions automatically include the auth token from `FirebaseAuth.instance.currentUser`. However, the token may not be attached if:

1. **User just signed in** - Token hasn't propagated yet
2. **Token expired** - Firebase didn't auto-refresh
3. **Auth state not synced** - Callable created before auth completed

#### Solution: Force Token Refresh Before Callable

```dart
// ALWAYS refresh token before making a callable request
Future<void> makeAuthenticatedCall() async {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    throw Exception('User not signed in');
  }
  
  if (user.isAnonymous) {
    throw Exception('Anonymous users cannot access this feature');
  }
  
  // CRITICAL: Force refresh the token
  final token = await user.getIdToken(true);
  
  if (token == null) {
    throw Exception('Could not obtain auth token');
  }
  
  print('Token obtained: ${token.substring(0, 30)}...');
  
  // Now make the callable - Firebase will include the fresh token
  final functions = FirebaseFunctions.instance;
  final callable = functions.httpsCallable('yourFunctionName');
  
  final result = await callable.call({'data': 'value'});
}
```

#### After Google Sign-In - Wait for Token

```dart
Future<void> signInAndCall() async {
  // Sign in with Google
  final credential = await signInWithGoogle();
  
  if (credential?.user != null) {
    // CRITICAL: Wait for auth state to propagate
    await Future.delayed(Duration(milliseconds: 500));
    
    // CRITICAL: Force refresh token
    final token = await credential!.user!.getIdToken(true);
    
    // Verify token exists
    if (token == null) {
      throw Exception('Failed to get token after sign-in');
    }
    
    // Now safe to make callable
    await makeAuthenticatedCall();
  }
}
```

#### Debug Checklist

```dart
void debugAuthState() async {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  
  print('=== AUTH DEBUG ===');
  print('User: ${user?.uid ?? "NULL"}');
  print('Email: ${user?.email ?? "NULL"}');
  print('isAnonymous: ${user?.isAnonymous}');
  print('Provider: ${user?.providerData.map((p) => p.providerId).toList()}');
  
  if (user != null) {
    try {
      final token = await user.getIdToken(true);
      print('Token: ${token?.substring(0, 30)}...');
      print('Token length: ${token?.length}');
    } catch (e) {
      print('Token ERROR: $e');
    }
  }
  print('==================');
}
```

#### Server-Side Verification (Cloud Function)

```javascript
// In your Cloud Function
exports.yourFunction = onCall(async (request) => {
  // Check if auth exists
  if (!request.auth) {
    console.error('No auth context in request');
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  // Check if anonymous
  const isAnonymous = request.auth.token.firebase?.sign_in_provider === 'anonymous';
  if (isAnonymous) {
    throw new HttpsError('unauthenticated', 'Anonymous users not allowed');
  }
  
  // Log auth details
  console.log('Auth UID:', request.auth.uid);
  console.log('Auth Email:', request.auth.token.email);
  console.log('Provider:', request.auth.token.firebase?.sign_in_provider);
  
  // Proceed with function logic
  return { success: true };
});
```

#### Complete Flow for Subscription Checkout

```dart
Future<bool> createCheckoutSession() async {
  // Step 1: Verify user is signed in with real account
  final auth = FirebaseAuthService.instance;
  
  if (!auth.hasRealAccount) {
    // Navigate to sign-in first
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => SignInScreen(returnOnSignIn: true),
    ));
    
    // Wait for auth to settle
    await Future.delayed(Duration(milliseconds: 500));
  }
  
  // Step 2: Get fresh user reference
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.isAnonymous) {
    throw Exception('Sign in required');
  }
  
  // Step 3: Force token refresh
  final token = await user.getIdToken(true);
  if (token == null) {
    throw Exception('Could not get auth token');
  }
  
  print('✅ Token ready: ${token.length} chars');
  
  // Step 4: Make callable (token automatically included)
  final callable = FirebaseFunctions.instance.httpsCallable('createCheckoutSession');
  final result = await callable.call({
    'billingInterval': 'annual',
  });
  
  return result.data['url'] != null;
}
```

#### Key Points

1. **Always call `getIdToken(true)`** before callable functions
2. **Wait 500ms** after sign-in for auth state to propagate
3. **Check `isAnonymous`** - anonymous users can't use premium features
4. **Log token details** for debugging
5. **Server-side**: Always verify `request.auth` exists

## Functions Development

### Navigate to Functions Directory

```bash
cd functions
```

### Install Dependencies

```bash
npm install
```

### Build TypeScript

```bash
npm run build
```

### Full Deployment Workflow

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

## Viewing Logs

```bash
# View all function logs
firebase functions:log

# View logs for a specific function
firebase functions:log --only createCheckoutSession

# View recent logs (last 100 lines)
firebase functions:log --limit 100

# Follow logs in real-time
firebase functions:log --follow
```

## Local Development & Testing

### Start Emulators

```bash
# Start all emulators
firebase emulators:start

# Start specific emulators
firebase emulators:start --only functions
firebase emulators:start --only functions,firestore
firebase emulators:start --only functions,firestore,auth

# Start with data import
firebase emulators:start --import=./emulator-data

# Start and export data on exit
firebase emulators:start --export-on-exit=./emulator-data
```

### Emulator UI

When emulators are running, access the Emulator UI at:
- http://localhost:4000

## Secrets Management

### Set Secrets

```bash
# Set a secret
firebase functions:secrets:set SECRET_NAME

# Example: Set Stripe secrets
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
firebase functions:secrets:set STRIPE_PRICE_ID_MONTHLY
firebase functions:secrets:set STRIPE_PRICE_ID_ANNUAL
firebase functions:secrets:set STRIPE_FOUNDER_PRICE_ID_UPFRONT

# Set Gemini API key
firebase functions:secrets:set GEMINI_API_KEY
```

### Set API Keys Without Trailing Newlines (Important for proxyGroq)

When you run `firebase functions:secrets:set GROQ_API_KEY` and paste the key, pressing Enter adds a trailing newline. Groq rejects keys with newlines (401 Invalid API Key). Use one of these methods:

**Option A – stdin without newline (recommended):**
```bash
cd "ARC MVP/EPI"
echo -n "gsk_your_actual_key_here" | firebase functions:secrets:set GROQ_API_KEY --project arc-epi --data-file=-
```

**Option B – file:**
```bash
echo -n "gsk_your_actual_key_here" > /tmp/groq_key.txt
firebase functions:secrets:set GROQ_API_KEY --project arc-epi --data-file=/tmp/groq_key.txt
rm /tmp/groq_key.txt
```

**Verify:** After deploying, check Cloud Functions logs for `proxyGroq: key rawLen=X cleanLen=X hadNewlines=false startsWithGsk=true`. If `hadNewlines=true` or `startsWithGsk=false`, re-set the secret with Option A or B.

### List Secrets

```bash
firebase functions:secrets:list
```

### Access Secrets

```bash
firebase functions:secrets:access SECRET_NAME
```

## Troubleshooting

### Re-authenticate

```bash
# If you get authentication errors
firebase login --reauth

# For CI/CD environments
firebase login:ci
```

### Clear Cache

```bash
# Clear Firebase cache
firebase logout
firebase login
```

### Check Function Status

```bash
# List deployed functions
firebase functions:list
```

### API still not working – checklist

1. **Firebase config**
   - **iOS**: Use the real `GoogleService-Info.plist` from Firebase Console (project **arc-epi**) in `ios/Runner/`. Placeholder or wrong project IDs will cause init or proxy calls to fail.
   - At app start you should see logs like `FirebaseService: Firebase services are ready`; if you see "Firebase not ready" or init errors, fix the plist and rebuild.

2. **Signed in**
   - When signed in, LUMARA can use the **Firebase proxy** (no in-app key needed). That requires:
     - **GROQ_API_KEY** and **GEMINI_API_KEY** set in Firebase Secret Manager for project **arc-epi**.
     - `proxyGroq` and `proxyGemini` deployed (`firebase deploy --only functions`).
   - Check Cloud Functions logs in Firebase Console for `proxyGroq` / `proxyGemini` errors (e.g. "API key not configured", timeouts).

3. **Not signed in**
   - When not signed in, only **direct** API keys work. In **Settings → LUMARA** add a **Groq** or **Gemini** key and tap **Save**. The app will use that key for journal and chat; Gemini is also used directly when not signed in (no proxy).

4. **Clear errors**
   - "Firebase is not available" → fix plist and network; ensure Firebase init runs at app start.
   - "Connection to AI failed. Sign in or add a Groq or Gemini API key" → add a key in Settings → LUMARA and Save, or sign in to use the proxy.

### LUMARA: “I have an API key but it isn’t working”

#### Why this can happen

1. **Which key is used where**
   - **Journal reflections** and **LUMARA chat** use the API key you set in **Settings → LUMARA** (Groq or Gemini). That key is stored on the device and sent directly to Groq/Gemini (or via your backend if you use a proxy).
   - If you are **signed in**, some flows can use the **Firebase proxy** (`proxyGroq` / `proxyGemini`) instead of your in-app key. The proxy uses the **server’s** API key (Firebase Secret Manager). So “I added a key in Settings” only affects the direct path; proxy behavior depends on the project’s secrets.

2. **You must tap Save**
   - In **Settings → LUMARA**, after entering a Groq or Gemini key, tap **Save** next to that field. If you only type the key and leave the screen, it is not stored.

3. **Which provider is used**
   - LUMARA prefers **Groq** (Llama 3.3 70B), then **Gemini**. If you only added a **Gemini** key, that’s used. If you added **Groq**, make sure it’s the key in the **Groq** field (not only Gemini). In the Xcode/run console you should see: `LUMARA: Using Groq (API key) for reflection` or `LUMARA: Using Gemini (no Groq key) for reflection`.

4. **Invalid key or network**
   - Wrong or revoked keys return 401/403 or timeouts. Get a new key from [Groq Console](https://console.groq.com/) or [Google AI Studio](https://aistudio.google.com/apikey) and save it again in Settings.

5. **Stale key after updating**
   - If you had an old key and then updated it in Settings, the app now uses the latest key on the next request (no restart needed).

#### Quick checks

- In **Settings → LUMARA**: confirm a key is present for **Groq** (or **Gemini**) and that you tapped **Save**.
- Run the app and trigger a reflection; in the console look for `LUMARA: Using Groq (API key)` or `Using Gemini` to see which provider is used.
- If you use the Firebase proxy when signed in, ensure **GROQ_API_KEY** (and/or Gemini) is set in Firebase Secret Manager and that `proxyGroq` is deployed (see **Secrets Management** and **ARC-Specific Functions**).

### "Connection to AI failed: INTERNAL" (proxyGroq / proxyGemini)

When both `proxyGroq` and `proxyGemini` return `internal - INTERNAL`:

1. **Check Cloud Functions logs** – Firebase Console → Functions → Logs, or:
   ```bash
   cd ARC_MVP/EPI && firebase functions:log --only proxyGroq,proxyGemini
   ```
   The logs show the underlying error (e.g. Groq 401, Gemini 429/403).

2. **Common causes:**
   - **GROQ_API_KEY** – 401 Invalid API Key: re-set without newlines (see **Set API Keys Without Trailing Newlines**).
   - **GEMINI_API_KEY** – 429 (quota) or 403 (leaked key): wait for quota reset or rotate key at [Google AI Studio](https://aistudio.google.com/apikey).

3. **GTMSessionFetcher "was already running"** – duplicate concurrent call; usually transient. Retry the request.

### proxyGroq 401 Invalid API Key

If journal reflections fail with "Groq API error: 401" even though the key works with curl:

1. **Trailing newline in secret** – Firebase `secrets:set` adds a newline when you paste and press Enter. Re-set the secret without newlines (see **Set API Keys Without Trailing Newlines** above).
2. **Wrong key in Secret Manager** – Ensure the key in Firebase matches the one that works with curl. Rotate the key in [Groq Console](https://console.groq.com) if it was exposed, then update the Firebase secret.
3. **Check logs** – `firebase functions:log --only proxyGroq` shows `key rawLen=X cleanLen=X hadNewlines=X startsWithGsk=X`. If `hadNewlines=true` or `startsWithGsk=false`, re-set the secret.

### proxyGemini Empty User String Error

If LUMARA journal reflections fail with "system and user parameters are required" error, the function may not be handling empty user strings correctly.

#### Symptoms
- Error: `Gemini API request failed: system and user parameters are required`
- Journal reflections fail but chat works fine
- Error occurs even though parameters are being sent

#### Root Cause
The `proxyGemini` function was rejecting empty string `user` parameters. Journal reflections use unified prompts where all content is in the `system` prompt, with `user` set to empty string.

#### Solution
Updated function validation to:
1. Check for `null`/`undefined` instead of falsy values
2. Allow empty strings when `system` has content
3. Handle both string and object types

#### Verification
```bash
# Check function logs
firebase functions:log --only proxyGemini

# Verify function is deployed
firebase functions:list | grep proxyGemini
```

#### Related Documentation
- See `docs/bugtracker/records/gemini-api-empty-user-string.md` for full details
- Fixed in v3.2.2 (January 10, 2026)

---

### Firestore "Missing or insufficient permissions"

If you see `Permission denied` for `classification_logs`, `journal_entries`, or `sentinel_state`:

1. **Deploy updated Firestore rules** – The rules at `firestore.rules` (project root) must include these collections. Deploy with:
   ```bash
   firebase deploy --only firestore:rules
   ```

2. **Collections that need rules:**
   - `classification_logs` – create only (with `user_id == auth.uid`)
   - `users/{userId}/journal_entries` – read/write for owner
   - `users/{userId}/sentinel_state` – read/write for owner

### Cloud Run IAM Issues (UNAUTHENTICATED Error)

If a callable function returns `UNAUTHENTICATED` error even though the user is logged in, the issue is likely **Cloud Run IAM policy**, not Firebase Auth.

#### Symptoms
- `[firebase_functions/unauthenticated] UNAUTHENTICATED` error
- Other callable functions work fine with the same auth
- User is definitely logged in (Firebase Auth tokens are valid)

#### Root Cause
Firebase Functions v2 runs on Cloud Run. Cloud Run has its own IAM layer that controls who can invoke the service. If Cloud Run blocks the request, the function code never executes.

#### Solution

1. Go to [Google Cloud Console - Cloud Run](https://console.cloud.google.com/run)
2. Select your project (e.g., `arc-epi`)
3. Click on the affected service (e.g., `createcheckoutsession`)
4. Go to the **"Security"** tab
5. Under "Authentication", select **"Allow unauthenticated invocations"**
6. Click **Save**

**Why this is safe**: The function code still validates Firebase Auth internally:
```javascript
if (!request.auth) {
  throw new HttpsError("unauthenticated", "...");
}
```

Only authenticated Firebase users can successfully use the function.

#### Verify the Fix

Check Firebase Functions logs:
```bash
firebase functions:log --only <functionName>
```

If you see "not authorized to invoke" errors, the IAM policy is still blocking requests.

### Delete Functions

```bash
# Delete a specific function
firebase functions:delete functionName

# Delete with force (no confirmation)
firebase functions:delete functionName --force
```

## Environment Configuration

### Set Environment Variables (Legacy)

```bash
# Set config variable
firebase functions:config:set stripe.secret_key="sk_live_xxx"

# Get current config
firebase functions:config:get

# Unset config
firebase functions:config:unset stripe.secret_key
```

### Export Config for Local Development

```bash
firebase functions:config:get > .runtimeconfig.json
```

## ARC-Specific Functions

The following Cloud Functions are used by ARC:

| Function | Purpose |
|----------|---------|
| `createCheckoutSession` | Creates Stripe checkout session for subscriptions |
| `getUserSubscription` | Gets user's current subscription tier |
| `createPortalSession` | Creates Stripe customer portal session |
| `proxyGroq` | Proxies requests to Groq API (Llama 3.3 70B / Mixtral) |
| `proxyGemini` | Proxies requests to Gemini API |
| `analyzeJournalEntry` | Analyzes journal entries with AI |
| `generateJournalPrompts` | Generates AI-powered journal prompts |

### proxyGroq Request/Response Format

**Client → Server (Flutter `groq_send.dart`):**
- Sends JSON via `functions.httpsCallable('proxyGroq').call(requestData)`
- `requestData` keys: `user` (required), `system`, `model`, `temperature`, `maxTokens`, `entryId`, `chatId`
- Firebase Auth token is sent automatically in the request headers; the function checks `request.auth`

**Server → Groq API:**
- Reads `GROQ_API_KEY` from Secret Manager, sanitizes it (removes newlines/BOM), then calls `https://api.groq.com/openai/v1/chat/completions`
- Request body: `{ model, messages: [{ role: "system", content }, { role: "user", content }], temperature, stream: false, max_tokens? }`

**Server → Client:**
- Returns `{ response: string, usage?: object }` on success

## Quick Reference

```bash
# Most common commands
firebase deploy --only functions          # Deploy all functions
firebase functions:log --follow           # Watch logs in real-time
firebase emulators:start --only functions # Test locally
firebase functions:secrets:set KEY        # Add a secret
```

## Related Documentation

- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [Google Sign-In for Flutter](https://pub.dev/packages/google_sign_in)
- [Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)

