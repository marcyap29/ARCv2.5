# Quick Start Guide - Backend Refactor

## Problem Restatement ✅

**You asked me to:**
1. ✅ Remove all Venice AI dependencies
2. ✅ Replace Venice calls with Gemini Flash, Gemini Pro, and Claude
3. ✅ Implement free vs paid tiers
4. ✅ Add analysis and chat quotas
5. ✅ Create model router abstraction
6. ✅ Keep Firebase as core backend (Auth + Firestore + Functions)
7. ✅ Preserve frontend API shape (`httpsCallable` functions)

**I've delivered:**
- Complete TypeScript backend refactor
- Model router with tier-based selection
- Quota enforcement system
- Gemini + Claude clients
- Updated Cloud Functions
- Stripe webhook handler
- Future-proof architecture (Gemini 3.0 ready, local model hooks)

---

## File Structure

```
functions/
├── src/
│   ├── types.ts                    # Type definitions
│   ├── config.ts                    # Environment config & model IDs
│   ├── admin.ts                     # Firebase Admin init
│   ├── modelRouter.ts              # Model selection logic
│   ├── quotaGuards.ts              # Tier & quota enforcement
│   ├── llmClients.ts               # Gemini & Claude clients
│   ├── functions/
│   │   ├── analyzeJournalEntry.ts  # Journal analysis function
│   │   ├── sendChatMessage.ts      # Chat function
│   │   └── stripeWebhook.ts        # Stripe subscription handler
│   └── index.ts                     # Function exports
├── tsconfig.json                    # TypeScript config
├── package.json                     # Dependencies
├── .env.example                     # Environment variables template
├── README.md                        # Setup guide
├── ARCHITECTURE.md                  # Detailed architecture
└── IMPLEMENTATION_SUMMARY.md        # What was built
```

---

## Setup (5 Minutes)

### 1. Install Dependencies
```bash
cd functions
npm install
```

### 2. Set API Keys (Secrets)
```bash
# These will prompt for the actual keys
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set ANTHROPIC_API_KEY
```

### 3. Build TypeScript
```bash
npm run build
```

### 4. Deploy
```bash
firebase deploy --only functions
```

---

## Environment Variables

### Required Secrets
- `GEMINI_API_KEY` - Get from https://aistudio.google.com/app/apikey
- `ANTHROPIC_API_KEY` - Get from https://console.anthropic.com/

### Optional Config (Defaults Provided)
- `GEMINI_FLASH_MODEL_ID` (default: "gemini-2.5-flash" - free tier)
- `GEMINI_PRO_MODEL_ID` (default: "gemini-2.5" - paid tier, unlimited)
- `CLAUDE_HAIKU_MODEL_ID` (default: "claude-3-haiku-20240307")
- `CLAUDE_SONNET_MODEL_ID` (default: "claude-3-5-sonnet-20241022")
- `FREE_MAX_ANALYSES_PER_ENTRY` (default: "4")
- `FREE_MAX_CHAT_TURNS_PER_THREAD` (default: "200")

---

## API Usage (Frontend)

### Analyze Journal Entry
```dart
// Flutter/Dart
final callable = FirebaseFunctions.instance.httpsCallable('analyzeJournalEntry');
final result = await callable.call({
  'entryId': entryId,
  'entryContent': entryContent,
});

final analysis = result.data as Map<String, dynamic>;
// analysis['summary']
// analysis['themes'] (List<String>)
// analysis['suggestions'] (List<String>)
// analysis['tier'] ("FREE" | "PAID")
// analysis['modelUsed'] (ModelFamily)
```

### Send Chat Message
```dart
// Flutter/Dart
final callable = FirebaseFunctions.instance.httpsCallable('sendChatMessage');
final result = await callable.call({
  'threadId': threadId,
  'message': userMessage,
});

final response = result.data as Map<String, dynamic>;
// response['threadId']
// response['message'] (ChatMessage)
// response['messageCount'] (int)
// response['modelUsed'] (ModelFamily)
```

---

## Testing Quotas

### Free Tier Test
```javascript
// Create free tier user in Firestore
await db.collection('users').doc('test-user').set({
  subscriptionTier: 'FREE',
  subscriptionStatus: 'active',
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});

// Try 5th analysis → Should fail with ANALYSIS_LIMIT_REACHED
// Try 201st message → Should fail with CHAT_LIMIT_REACHED
```

### Paid Tier Test
```javascript
// Create paid tier user
await db.collection('users').doc('paid-user').set({
  subscriptionTier: 'PAID',
  subscriptionStatus: 'active',
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});

// Unlimited analyses and messages
// Should use Gemini Pro / Claude based on operation
```

---

## Model Routing Examples

| User Tier | Operation | Model Selected |
|-----------|-----------|----------------|
| FREE | `journal_analysis` | Gemini Flash |
| FREE | `chat_message` | Gemini Flash |
| PAID | `journal_analysis` | Gemini Pro |
| PAID | `deep_reflection` | Claude Sonnet |
| PAID | `chat_message` | Gemini Pro |
| PAID | `monthly_summary` | Claude Sonnet |

---

## Migration to Gemini 3.0

**When Gemini 3.0 is released:**

```bash
# Update model IDs (no code changes needed!)
firebase functions:config:set gemini.flash_model_id="gemini-3.0-flash"
firebase functions:config:set gemini.pro_model_id="gemini-3.0-pro"

# Redeploy
npm run build
firebase deploy --only functions
```

That's it! The model router automatically uses the new IDs.

---

## What Was Removed

- ❌ `veniceProxy` function (old `index.js`)
- ❌ All Venice AI API calls
- ❌ Venice AI dependencies

## What Was Added

- ✅ Gemini Flash/Pro clients
- ✅ Claude Haiku/Sonnet clients
- ✅ Model router
- ✅ Quota guards
- ✅ Tier system
- ✅ Stripe webhook
- ✅ TypeScript type safety

---

## Next Steps

1. **Test locally** with Firebase emulators
2. **Deploy to staging** environment
3. **Verify quota enforcement** works correctly
4. **Test model routing** for different operations
5. **Configure Stripe webhook** endpoint
6. **Monitor logs** for any issues

---

## Support

- See `ARCHITECTURE.md` for detailed architecture
- See `README.md` for setup instructions
- See `IMPLEMENTATION_SUMMARY.md` for what was built

