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

# Example: Set Stripe secret key
firebase functions:secrets:set STRIPE_SECRET_KEY

# Set Gemini API key
firebase functions:secrets:set GEMINI_API_KEY
```

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
| `proxyGemini` | Proxies requests to Gemini API |
| `analyzeJournalEntry` | Analyzes journal entries with AI |
| `generateJournalPrompts` | Generates AI-powered journal prompts |

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

