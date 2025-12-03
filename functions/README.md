# ARC Backend - Firebase Cloud Functions

Refactored backend replacing Venice AI with Gemini + Claude architecture.

## Architecture

```
Client (Flutter)
  ↓ HTTPS + Firebase Auth Token
Firebase Cloud Function (onCall)
  ↓ Verify Auth Token
Load User from Firestore
  ↓ Check Subscription Tier
Quota Guard (checkCanAnalyzeEntry / checkCanSendMessage)
  ↓ Enforce Limits
Model Router (selectModel)
  ↓ Choose Model (Gemini Flash/Pro or Claude)
LLM Client (GeminiClient / ClaudeClient)
  ↓ Call API
Gemini/Claude API
  ↓ Response
Parse & Structure Response
  ↓ Update Firestore (increment counters)
Return to Client
```

## Setup

### 1. Install Dependencies

```bash
cd functions
npm install
```

### 2. Configure Secrets

```bash
# Set API keys as secrets
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set ANTHROPIC_API_KEY
```

### 3. Configure Model IDs

```bash
# Set model IDs (optional - defaults provided)
firebase functions:config:set gemini.flash_model_id="gemini-2.5-flash"
firebase functions:config:set gemini.pro_model_id="gemini-2.5"
firebase functions:config:set claude.haiku_model_id="claude-3-haiku-20240307"
firebase functions:config:set claude.sonnet_model_id="claude-3-5-sonnet-20241022"
```

### 4. Build and Deploy

```bash
npm run build
firebase deploy --only functions
```

## Cloud Functions

### `analyzeJournalEntry`

Analyzes a journal entry with deep insights.

**Request:**
```typescript
{
  entryId: string;
  entryContent: string;
}
```

**Response:**
```typescript
{
  summary: string;
  themes: string[];
  suggestions: string[];
  tier: "FREE" | "PAID";
  modelUsed: ModelFamily;
}
```

### `sendChatMessage`

Sends a chat message and receives AI response.

**Request:**
```typescript
{
  threadId: string;
  message: string;
}
```

**Response:**
```typescript
{
  threadId: string;
  message: ChatMessage;
  messageCount: number;
  modelUsed: ModelFamily;
}
```

### `stripeWebhook`

Handles Stripe subscription events to update user tiers.

## Tier System

**Important**: Both FREE and PAID tiers use the same Gemini 2.5 model. The difference is backend-enforced quotas, not model capabilities.

### FREE Tier
- Model: `gemini-2.5-flash` (same underlying Gemini 2.5 model)
- Backend-enforced limits:
  - 4 deep analyses per journal entry
  - 200 chat turns per thread
- No Claude access

### PAID Tier ($30/mo)
- Model: `gemini-2.5` (unlimited access to same Gemini 2.5 model)
- Additional models: Claude Haiku, Claude Sonnet (for deep reflection)
- Backend removes all quotas: Unlimited analyses and chat

## Model Routing

- **FREE tier**: Always `gemini-2.5-flash` (backend enforces quotas)
- **PAID tier**:
  - `journal_analysis`: `gemini-2.5` (unlimited)
  - `deep_reflection`: Claude Sonnet
  - `chat_message`: `gemini-2.5` (unlimited)
  - `theme_extraction`: `gemini-2.5`
  - `monthly_summary`: Claude Sonnet

## Migration to Gemini 3.0

When Gemini 3.0 is released:

1. Update model IDs via config:
   ```bash
   firebase functions:config:set gemini.flash_model_id="gemini-3.0-flash"
   firebase functions:config:set gemini.pro_model_id="gemini-3.0-pro"
   ```

2. No code changes needed - the model router uses these config values

3. Test API compatibility (response format should remain the same)

## Local Model Support (Future)

The architecture includes support for local models (EIS-O1/EIS-E1):

- `LOCAL_EIS` model family defined
- `LocalEISClient` stub implemented
- Routing logic can select local models when available
- Requires local inference server running on `localhost:8080`

## Firestore Collections

### `users/{userId}`
```typescript
{
  subscriptionTier: "FREE" | "PAID";
  subscriptionStatus: "active" | "canceled" | "trial";
  stripeCustomerId?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### `journalEntries/{entryId}`
```typescript
{
  userId: string;
  content: string;
  analysisCount: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### `chatThreads/{threadId}`
```typescript
{
  userId: string;
  messageCount: number;
  messages: ChatMessage[];
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

