# Backend Architecture & Setup

**Version:** 2.1.46  
**Last Updated:** December 9, 2025  
**Status:** ✅ Production Ready with Authentication

---

## Overview

EPI MVP uses Firebase as its backend infrastructure for authentication, cloud functions, and subscription management. This document covers the complete backend setup, architecture, and deployment procedures.

---

## Priority 2: Firebase API Proxy (Completed Dec 7, 2025)

### Objective

Hide API keys from the client while keeping LUMARA running on-device with full journal access.

### Architecture

```
Client (Flutter)
  ↓
LUMARA (On-Device Logic)
  ↓
Firebase Cloud Function (proxyGemini)
  ↓
Gemini API (with secured API key)
```

### Key Benefits

- ✅ **API keys hidden** in Firebase Functions
- ✅ **LUMARA runs on-device** - maintains full journal access (chat + in-journal reflections)
- ✅ **No user configuration** - API key management is transparent
- ✅ **Simple proxy pattern** - Firebase function just forwards requests with the API key
- ✅ **Full data access** - LUMARA can still read local Hive database
- ✅ **Both LUMARA modes working** - Chat assistant and in-journal reflections both use proxy

### Implementation

**Client Side (`lib/services/gemini_send.dart`):**
```dart
Future<String> geminiSend({
  required String system,
  required String user,
  bool jsonExpected = false,
}) async {
  // Call Firebase proxy function
  final functions = FirebaseService.instance.getFunctions();
  final callable = functions.httpsCallable('proxyGemini');
  
  final result = await callable.call({
    'system': system,
    'user': user,
    'jsonExpected': jsonExpected,
  });
  
  return result.data['response'];
}
```

**Server Side (`functions/lib/index.js`):**
```javascript
exports.proxyGemini = onCall(
  { secrets: [GEMINI_API_KEY], invoker: "public" },
  async (request) => {
    const { system, user, jsonExpected } = request.data;
    
    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
    const model = genAI.getGenerativeModel({
      model: "gemini-2.5-flash",
      tools: [{ googleSearch: {} }],
      generationConfig: jsonExpected ? { responseMimeType: "application/json" } : undefined,
    });
    
    const chat = model.startChat({
      history: system ? [
        { role: "user", parts: [{ text: system }] },
        { role: "model", parts: [{ text: "Ok." }] }
      ] : [],
    });
    
    const result = await chat.sendMessage(user);
    return { response: result.response.text() };
  }
);
```

---

## Firebase Setup

### Project Configuration

- **Project ID:** `arc-epi`
- **Region:** `us-central1`
- **Platform:** Firebase Gen 2 (Cloud Functions v2)

### Required Services

1. **Firebase Authentication**
   - Email/Password authentication
   - Google OAuth (see OAuth Setup below)
   - Anonymous authentication (for MVP testing)

2. **Cloud Functions**
   - `proxyGemini` - API key proxy for Gemini API
   - `sendChatMessage` - LUMARA chat (currently deprecated, uses proxy instead)
   - `generateJournalReflection` - In-journal reflections (currently deprecated, uses proxy instead)
   - `getUserSubscription` - Subscription status
   - `createCheckoutSession` - Stripe checkout

3. **Firestore Database**
   - User documents and subscription data
   - Rate limiting state
   - Phase regimes and system state

4. **Secret Manager**
   - `GEMINI_API_KEY` - Gemini API key for proxy

---

## OAuth Setup (Priority 1.5)

### Google Sign-In Configuration

**Firebase Console Steps:**
1. Navigate to Authentication → Sign-in method
2. Enable "Google" provider
3. Add support email
4. Configure OAuth consent screen

**iOS Client Configuration:**
1. Create iOS OAuth 2.0 Client ID in Google Cloud Console
2. Bundle ID: `com.epi.arcmvp`
3. Download updated `GoogleService-Info.plist`
4. Replace file in `ios/Runner/`

**Android Configuration:**
1. Create Android OAuth 2.0 Client ID
2. Add SHA-1 certificate fingerprints
3. Download updated `google-services.json`
4. Replace file in `android/app/`

**Important:** The `GoogleService-Info.plist` and `google-services.json` files must include:
- `CLIENT_ID` / `client_id`
- `REVERSED_CLIENT_ID` / `oauth_client`
- API keys and project IDs

For complete setup instructions, see archived documentation: `archive/setup/OAUTH_SETUP.md`

---

## Stripe Integration (Priority 1.5)

### Configuration

**Subscription Tiers:**
- **Free:** Limited access (50 requests/day, 10/minute)
- **Premium:** $30/month - Unlimited access

**Setup Steps:**
1. Create Stripe account and get API keys
2. Add Stripe secret keys to Firebase Secret Manager:
   - `STRIPE_SECRET_KEY`
   - `STRIPE_WEBHOOK_SECRET`
3. Configure webhook endpoint: `https://us-central1-arc-epi.cloudfunctions.net/stripeWebhook`
4. Subscribe to events: `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`

**Client Integration:**
- `lib/services/subscription_service.dart` - Subscription management
- `lib/ui/subscription/subscription_management_view.dart` - UI
- `lib/ui/subscription/lumara_subscription_status.dart` - Status display

---

## Deployment

### Firebase Functions Deployment

```bash
cd "/Users/mymac/Software Development/ARCv.04"

# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:proxyGemini
```

### Current Deployment Status

| Function | Status | Critical | Notes |
|----------|--------|----------|-------|
| `proxyGemini` | ✅ Deployed | YES | API key proxy |
| `sendChatMessage` | ✅ Deployed | NO | Deprecated, uses proxy |
| `generateJournalReflection` | ✅ Deployed | NO | Deprecated, uses proxy |
| `getUserSubscription` | ✅ Deployed | YES | Subscription status |
| `createCheckoutSession` | ✅ Deployed | YES | Stripe checkout |

---

## Security & IAM

### Required Permissions

**Cloud Run Service:**
- Service: `proxygemini-*`
- Permission: "Allow unauthenticated invocations"
- How to set: Cloud Console → Cloud Run → Service → Security → Allow public access

**Service Account:**
- Account: `{number}-compute@developer.gserviceaccount.com`
- Roles:
  - `Cloud Datastore User`
  - `Firebase Admin SDK Administrator Service Agent`
  - `Cloud Functions Invoker`

### Authentication Flow

1. **Client** makes request to Firebase Function
2. **Firebase** validates authentication (or allows public for MVP)
3. **Function** executes with service account permissions
4. **Response** returned to client

---

## Environment Configuration

### Functions Environment Variables

File: `functions/.env.arc-epi`
```bash
# Model Configuration
GEMINI_FLASH_MODEL_ID=gemini-2.5-flash
GEMINI_PRO_MODEL_ID=gemini-2.5

# Rate Limiting
FREE_MAX_REQUESTS_PER_DAY=50
FREE_MAX_REQUESTS_PER_MINUTE=10
FREE_MAX_ANALYSES_PER_ENTRY=4
FREE_MAX_CHAT_TURNS_PER_THREAD=200
```

### Client Configuration

**Firebase Region:**
```dart
const String.fromEnvironment(
  'FIREBASE_FUNCTIONS_REGION',
  defaultValue: 'us-central1',
);
```

**Service Initialization:**
```dart
FirebaseService.instance.initialize();
FirebaseService.instance.getFunctions(); // Returns configured instance
```

---

## Development Workflow

### Beta Branch Setup

**Two-App Installation:**
| Branch | App Name | Bundle ID |
|--------|----------|-----------|
| `main` | ARC | `com.epi.arcmvp` |
| `dev-*` | ARC P2 | `com.epi.arcmvp.priority2` |

**Workflow:**
1. Work on feature branch (`dev-priority-2-api-refactor`)
2. Test with separate bundle ID
3. Merge to `main` when complete
4. Reset `dev` branch for next feature

For complete workflow, see archived documentation: `archive/setup/BETA_BRANCH.md`

---

## Monitoring & Logs

### View Function Logs

```bash
# View all logs
firebase functions:log

# View specific function
firebase functions:log --only proxyGemini

# View errors only
firebase functions:log 2>&1 | grep Error
```

### Firebase Console

- **Functions Dashboard:** https://console.firebase.google.com/project/arc-epi/functions
- **Authentication:** https://console.firebase.google.com/project/arc-epi/authentication
- **Firestore:** https://console.firebase.google.com/project/arc-epi/firestore

---

## Troubleshooting

### Common Issues

**1. `UNAUTHENTICATED` Error**
- **Cause:** Cloud Run service requires authentication
- **Fix:** Set "Allow public access" in Cloud Run → Security

**2. `PERMISSION_DENIED` Error**
- **Cause:** Firestore permissions not set
- **Fix:** Add `Cloud Datastore User` role to compute service account

**3. `models/0 is not found` Error**
- **Cause:** Model ID environment variable not set
- **Fix:** Check `functions/.env.arc-epi` or hardcode in `functions/src/config.ts`

**4. Function Not Found**
- **Cause:** Function not exported in `functions/src/index.ts`
- **Fix:** Add export and redeploy

**5. TypeScript Compilation Errors**
- **Cause:** TypeScript not properly configured
- **Fix:** Add function to `functions/lib/index.js` as pure JavaScript

---

## Priority 3: Authentication & Security (Completed Dec 9, 2025)

### Objective

Implement proper authentication and per-user rate limiting to replace the `invoker: "public"` workaround.

### Architecture

```
Client (Flutter)
  ↓
Firebase Auth (Anonymous → Google/Email)
  ↓
Cloud Functions (enforceAuth + checkLimits)
  ↓
Firestore (User Document + Usage Tracking)
```

### Key Components

#### 1. Authentication (`authGuard.ts`)

- **enforceAuth()**: Validates Firebase Auth, creates/loads user documents
- **checkJournalEntryLimit()**: Per-entry limit (5 for free users)
- **checkChatLimit()**: Per-chat limit (20 for free users)
- **Admin Detection**: Email-based admin privileges

#### 2. Rate Limiting

| Feature | Free Tier | Admin/Premium |
|---------|-----------|---------------|
| In-Journal LUMARA | 5 per entry | Unlimited |
| In-Chat LUMARA | 20 per chat | Unlimited |

#### 3. Sign-In UI (`sign_in_screen.dart`)

- **Google Sign-In**: One-tap authentication
- **Email/Password**: Sign up and sign in with validation
- **Forgot Password**: Email-based password reset
- **Account Linking**: Anonymous sessions preserved on sign-in

---

## Migration History

### Priority 2 Evolution

**Initial Approach (Abandoned):**
- Move all LUMARA logic to Firebase Functions
- **Problem:** Lost access to local journal data

**Final Approach (Dec 7, 2025):**
- Keep LUMARA on-device
- Only proxy API key through Firebase
- **Result:** Simple, maintains data access, secure API keys

### Authentication Workaround (Temporary)

For MVP testing, functions allow unauthenticated calls with temporary user IDs:
```javascript
const userId = request.auth?.uid || `mvp_test_${Date.now()}`;
```

**Note:** Proper authentication will be re-implemented in Priority 3.

---

## Related Documentation

- [Architecture Overview](ARCHITECTURE.md)
- [Features Guide](FEATURES.md)
- [README](README.md)

### Archived Setup Guides

- `archive/setup/OAUTH_SETUP.md` - Complete OAuth setup instructions
- `archive/setup/FIREBASE_DEPLOYMENT_STATUS.md` - Initial deployment notes
- `archive/setup/PRIORITY_2_API_REFACTOR.md` - Priority 2 implementation details
- `archive/setup/BETA_BRANCH.md` - Dev branch workflow
- `archive/setup/PRIORITY_2_AUTH_TODO.md` - Authentication workaround notes

---

**Status**: ✅ Production Ready with Authentication  
**Last Updated**: December 9, 2025  
**Version**: 2.1.46
