# Backend Architecture & Setup

**Version:** 3.2
**Last Updated:** February 7, 2026
**Status:** ✅ Production Ready with Adaptive Framework, Companion-First LUMARA, Validation & Logging, Health Integration, AssemblyAI v3, Internet Access, Enhanced Classification-Aware PRISM Privacy Protection, Stripe Integration (web), RevenueCat (in-app purchases), and Local Backup Services

---

## Overview

EPI MVP uses Firebase as its backend infrastructure for authentication, cloud functions, and subscription management. **Stripe** is used for web-based subscription/payments; **RevenueCat** powers in-app purchases (iOS/Android). See [PAYMENTS_CLARIFICATION.md](PAYMENTS_CLARIFICATION.md) and [revenuecat/README.md](revenuecat/README.md) for how the two fit together. This document covers Firebase backend setup, architecture, and deployment procedures.

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
  String intent = 'chat',
  bool skipTransformation = false, // Skip if entry already abstracted
}) async {
  // Step 1: PRISM scrubbing - local PII detection and masking
  final prismAdapter = PrismAdapter();
  final userPrismResult = prismAdapter.scrub(user);
  final systemPrismResult = prismAdapter.scrub(system);
  
  // Step 2: Correlation-resistant transformation (if not skipped)
  String transformedUserText;
  if (skipTransformation) {
    // Entry already abstracted, use scrubbed version directly
    transformedUserText = userPrismResult.scrubbedText;
  } else {
    // Transform to structured JSON payload
    final userTransformation = await prismAdapter.transformToCorrelationResistant(
      prismScrubbedText: userPrismResult.scrubbedText,
      intent: intent,
      prismResult: userPrismResult,
    );
    transformedUserText = userTransformation.cloudPayloadBlock.toJsonString();
  }
  
  // Call Firebase proxy function
  final functions = FirebaseService.instance.getFunctions();
  final callable = functions.httpsCallable('proxyGemini');
  
  final result = await callable.call({
    'system': transformedSystem,
    'user': transformedUserText, // Either structured JSON or abstracted text
    'jsonExpected': jsonExpected,
  });
  
  // Restore PII in response for local display
  final restoredResponse = prismAdapter.restore(
    result.data['response'],
    userPrismResult.reversibleMap,
  );
  
  return restoredResponse;
}
```

**Journal Entry Flow (`lib/arc/chat/services/enhanced_lumara_api.dart`):**
```dart
// Abstract entry text BEFORE building prompt
final entryTransformation = await prismAdapter.transformToCorrelationResistant(
  prismScrubbedText: entryPrismResult.scrubbedText,
  intent: 'journal_reflection',
  prismResult: entryPrismResult,
);
final entryDescription = entryTransformation.cloudPayloadBlock.semanticSummary;

// Build natural language prompt with abstract description
final userPrompt = 'Current entry: $entryDescription\n\n[instructions...]';

// Skip transformation to preserve natural language
await geminiSend(
  system: systemPrompt,
  user: userPrompt,
  skipTransformation: true, // Preserve natural language
);
```

**Privacy Protection (Enhanced v2.1.86):**
- ✅ PRISM scrubbing: Local PII detection and masking
- ✅ Classification-Aware Privacy: Dual strategy based on content type
  - **Technical/Factual Content**: Preserves semantic content after PII scrubbing
  - **Personal/Emotional Content**: Full correlation-resistant transformation
- ✅ Enhanced Semantic Analysis: On-device technical content detection
  - Mathematics, physics, computer science, engineering recognition
  - Subject-specific summarization preserves context while protecting privacy
- ✅ Correlation-resistant transformation: Rotating aliases prevent re-identification for personal content
- ✅ Enhanced semantic summaries: Descriptive abstractions instead of generic summaries
- ✅ Structured JSON payloads: No verbatim personal text transmission
- ✅ Session-based rotation: Identifiers rotate per session for personal content
- ✅ Reversible mapping: Stored locally only, never transmitted
- ✅ Privacy Guarantee: All PII scrubbed regardless of content type, no personal verbatim text sent to cloud

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

### Web Access Safety Layer

LUMARA's web access is governed by a comprehensive 10-rule safety layer that ensures responsible use of Google Search:

1. **Primary Source Priority** - Always prioritize user's personal context (journal entries, chat history) before web search
2. **Explicit Need Check** - Perform internal reasoning to verify web search is necessary
3. **Opt-In by User Intent** - Interpret user requests (e.g., "look up", "find information") as permission to search
4. **Content Safety Boundaries** - Avoid violent, graphic, extremist, or illegal content
5. **Research Mode Filter** - Prioritize peer-reviewed sources and reliable data for research queries
6. **Containment Framing** - Provide high-level summaries for sensitive topics (mental health, trauma) without graphic details
7. **No Passive Browsing** - Web access must always be tied to explicit user requests
8. **Transparent Sourcing** - Summarize findings and state when external information was used
9. **Contextual Integration** - Relate web-sourced information back to user's ARC themes, ATLAS phase, and personal patterns
10. **Fail-Safe Rule** - Refuse unsafe or unverifiable content and offer safe alternatives

**Implementation**: Safety rules are defined in `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` and enforced through LUMARA's system prompt. The `webAccess.enabled` flag in the control state determines when web search is available.

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
   - `getAssemblyAIToken` - Returns AssemblyAI API key for premium users (Universal Streaming v3)
   - `sendChatMessage` - LUMARA chat (currently deprecated, uses proxy instead)
   - `generateJournalReflection` - In-journal reflections (currently deprecated, uses proxy instead)
   - `getUserSubscription` - Subscription status
   - `createCheckoutSession` - Stripe checkout

3. **Firestore Database**
   - User documents and subscription data
   - Rate limiting state
   - Phase regimes and system state
   - **Adaptive Framework State (v3.1)**: User cadence profiles stored at `users/{userId}/adaptive_state/cadence_profile`
     - User type classification (power user, frequent, weekly, sporadic)
     - Cadence metrics (average days between entries, standard deviation)
     - User type transition history
     - Last calculation timestamp and entry count

4. **Secret Manager**
   - `GEMINI_API_KEY` - Gemini API key for proxy
   - `ASSEMBLYAI_API_KEY` - AssemblyAI API key for premium voice transcription (Universal Streaming v3)

---

## AssemblyAI Integration (Premium Feature)

### Overview

AssemblyAI Universal Streaming v3 provides real-time speech-to-text transcription for premium users. The integration uses WebSocket streaming for low-latency transcription.

### Architecture

```
Client (Flutter)
  ↓
Firebase Function (getAssemblyAIToken)
  ↓
AssemblyAI API Key (from Firebase Secrets)
  ↓
WebSocket Connection (wss://streaming.assemblyai.com/v3/ws)
  ↓
Real-time Transcription (Turn messages)
```

### Setup

1. **Add AssemblyAI API Key to Firebase Secrets:**
   ```bash
   firebase functions:secrets:set ASSEMBLYAI_API_KEY
   # Enter your AssemblyAI API key when prompted
   ```

2. **Configure Cloud Run IAM:**
   - Navigate to Cloud Run → `getassemblyaitoken-*` service
   - Security tab → "Allow public access"
   - This allows authenticated Firebase users to invoke the function

3. **Client Implementation:**
   - `lib/arc/chat/voice/transcription/assemblyai_provider.dart` - WebSocket client
   - `lib/services/assemblyai_service.dart` - Token fetching and caching
   - Uses Universal Streaming v3 endpoint: `wss://streaming.assemblyai.com/v3/ws`
   - Sends raw binary audio data (16kHz, 16-bit, mono PCM)
   - Receives "Turn" messages with partial and final transcripts

### API Details

**Universal Streaming v3:**
- **Endpoint:** `wss://streaming.assemblyai.com/v3/ws?token={API_KEY}&inactivity_timeout=30`
- **Authentication:** API key as query parameter (no Authorization header)
- **Audio Format:** Raw binary PCM (16kHz, 16-bit, mono)
- **Message Format:** JSON "Turn" messages with `transcript`, `end_of_turn`, `words` array
- **Session Flow:** Begin message → Audio streaming → Turn messages → Close

**Firebase Function (`getAssemblyAIToken`):**
```javascript
exports.getAssemblyAIToken = onCall(
  { secrets: [ASSEMBLYAI_API_KEY] },
  async (request) => {
    // Validates premium subscription
    // Returns API key directly (v3 accepts it as token parameter)
    return {
      token: ASSEMBLYAI_API_KEY.value().trim(),
      expiresAt: Date.now() + (60 * 60 * 1000), // 1 hour
      tier: 'premium',
      eligibleForCloud: true
    };
  }
);
```

### Troubleshooting

**1. "UNAUTHENTICATED" Error:**
- **Cause:** Cloud Run service requires authentication
- **Fix:** Set "Allow public access" in Cloud Run → Security tab

**2. "Not authorized" WebSocket Error:**
- **Cause:** Invalid or missing API key
- **Fix:** Verify `ASSEMBLYAI_API_KEY` secret is set correctly

**3. WebSocket Closes Immediately:**
- **Cause:** Audio format incorrect or session not ready
- **Fix:** Ensure audio is raw binary PCM, wait for "Begin" message before sending

**4. No Transcripts Received:**
- **Cause:** "Turn" message type not handled
- **Fix:** Verify `assemblyai_provider.dart` handles "Turn" messages (v3 format)

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
5. Add `CFBundleURLTypes` entry with `REVERSED_CLIENT_ID` (Google Sign-In callback)

**Android Configuration:**
1. Create Android OAuth 2.0 Client ID
2. Add SHA-1 certificate fingerprints
3. Download updated `google-services.json`
4. Replace file in `android/app/`

**Important:** The `GoogleService-Info.plist` and `google-services.json` files must include:
- `CLIENT_ID` / `client_id`
- `REVERSED_CLIENT_ID` / `oauth_client`
- API keys and project IDs

**Hotfix (Dec 10, 2025):** iOS Google Sign-In crash resolved by updating `GoogleService-Info.plist` with the correct `CLIENT_ID`/`REVERSED_CLIENT_ID` and adding the URL scheme to `Info.plist`.

**Restoration (Jan 19, 2026):** `GoogleService-Info.plist` restored from ARCv1.0 to resolve build errors. File must be present in `ios/Runner/` directory for iOS builds to succeed.

For complete setup instructions, see archived documentation: `archive/setup/OAUTH_SETUP.md`

---

## Stripe Integration (Priority 1.5)

### Configuration

**Subscription Tiers:**
- **Free:** Limited access (4 requests per conversation, 3/minute, 10 chat messages per day)
- **Premium:** $30/month or $200/year - Unlimited access
- **Founders Commit:** $1,500 upfront for 3 years (one-time payment)

**Setup Steps:**
1. Create Stripe account and get API keys
2. Add Stripe secrets to Firebase Secret Manager:
   - `STRIPE_SECRET_KEY`
   - `STRIPE_WEBHOOK_SECRET`
   - `STRIPE_PRICE_ID_MONTHLY`
   - `STRIPE_PRICE_ID_ANNUAL`
   - `STRIPE_FOUNDER_PRICE_ID_UPFRONT`
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
| `getAssemblyAIToken` | ✅ Deployed | YES | AssemblyAI API key for premium users (v3) |
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
| In-Journal LUMARA | 5 per conversation | Unlimited |
| In-Chat LUMARA | 10 per day | Unlimited |
| LUMARA Requests | 4 per conversation | Unlimited |

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

## Companion-First LUMARA Validation & Logging (v2.1.87)

### Firebase Collections for Monitoring

The new Companion-First LUMARA system includes comprehensive validation and logging infrastructure using Firebase Firestore.

#### Validation Logs Collection
**Collection:** `lumara_validation_logs`

**Purpose:** Monitor response quality and rule compliance

**Document Schema:**
```javascript
{
  user_id: string,
  entry_type: string,         // factual, reflective, analytical, conversational, metaAnalysis
  persona: string,            // companion, strategist, therapist, challenger
  is_valid: boolean,
  violations: string[],       // Array of violation descriptions
  metrics: {
    wordCount: number,
    maxWords: number,
    referenceCount: number,
    maxReferencesAllowed: number,
    isPersonalContent: boolean
  },
  entry_preview: string,      // First 100 chars of entry
  response_preview: string,   // First 100 chars of response
  timestamp: FieldValue.serverTimestamp()
}
```

#### Persona Distribution Collection
**Collection:** `lumara_persona_distribution`

**Purpose:** Monitor persona selection against 50-60% Companion target

**Document Schema:**
```javascript
{
  user_id: string,
  entry_type: string,
  user_intent: string,        // reflect, thinkThrough, differentPerspective, etc.
  selected_persona: string,
  selection_reason: string,   // "Companion-first default", "High emotional intensity", etc.
  was_companion_first: boolean,
  timestamp: FieldValue.serverTimestamp(),
  date: string               // YYYY-MM-DD for daily aggregation
}
```

### Analytics & Monitoring

**Persona Distribution Tracking:**
- Daily aggregation of persona usage percentages
- Target monitoring: 50-60% Companion, 25-35% Strategist, 10-15% Therapist, <5% Challenger
- Alerts if Companion usage drops below 50%

**Validation Monitoring:**
- Real-time tracking of response rule violations
- Reference limit enforcement logging
- Word count compliance monitoring
- Entry-type specific validation tracking

**Performance Metrics:**
- Response quality scores based on validation pass rates
- User experience metrics (simplified settings adoption)
- System behavior compliance (anti-over-referencing effectiveness)

### Client-Side Integration

**Validation Service:** `lib/services/lumara/validation_service.dart`
- Comprehensive response validation with strict Companion checks
- Firebase logging integration for monitoring violations
- Real-time compliance enforcement

**Logging Integration:** All validation results automatically logged to Firebase for:
- System performance monitoring
- User experience optimization
- Persona distribution analysis
- Rule effectiveness measurement

---

## Related Documentation

- [Architecture Overview](ARCHITECTURE.md)
- [Features Guide](FEATURES.md)
- [README](README.md)
- [Stripe Integration](stripe/README.md) - Complete Stripe setup and configuration guides

### Archived Setup Guides

- `archive/setup/OAUTH_SETUP.md` - Complete OAuth setup instructions
- `archive/setup/FIREBASE_DEPLOYMENT_STATUS.md` - Initial deployment notes
- `archive/setup/PRIORITY_2_API_REFACTOR.md` - Priority 2 implementation details
- `archive/setup/BETA_BRANCH.md` - Dev branch workflow
- `archive/setup/PRIORITY_2_AUTH_TODO.md` - Authentication workaround notes

---

**Status**: ✅ Production Ready with Adaptive Framework, Authentication, AssemblyAI v3, Web Access Safety, Stripe Integration & Local Backup Services  
**Last Updated**: January 31, 2026  
**Version**: 3.3.4
