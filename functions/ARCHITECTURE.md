# Backend Architecture - ARC Firebase Functions

## Problem Restatement

**Goal**: Refactor Firebase backend to replace Venice AI with Gemini + Claude while:
- ✅ Keeping Firebase as core backend (Auth + Firestore + Functions)
- ✅ Preserving frontend API shape (`httpsCallable('analyzeJournalEntry')`, `httpsCallable('sendChatMessage')`)
- ✅ Implementing free vs paid tiers
- ✅ Adding quota enforcement (4 analyses/entry, 200 messages/thread for free)
- ✅ Creating model router abstraction
- ✅ Preparing for future Gemini 3.0 migration (no architecture changes)
- ✅ Adding local model support hooks (EIS-O1/EIS-E1)

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter Client                            │
│  httpsCallable('analyzeJournalEntry')                           │
│  httpsCallable('sendChatMessage')                                │
└────────────────────┬────────────────────────────────────────────┘
                     │ HTTPS + Firebase Auth Token
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│              Firebase Cloud Function (onCall)                    │
│  - Automatic auth token verification                             │
│  - CORS handling                                                 │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│              Load User from Firestore                             │
│  users/{userId} → { subscriptionTier, subscriptionStatus }      │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│              Quota Guard                                         │
│  checkCanAnalyzeEntry(userId, entryId)                           │
│  checkCanSendMessage(userId, threadId)                           │
│  → Returns: { allowed, error? }                                 │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓ (if allowed)
┌─────────────────────────────────────────────────────────────────┐
│              Model Router                                        │
│  selectModel(tier, operationType)                                │
│  → Returns: ModelFamily (GEMINI_FLASH, GEMINI_PRO, CLAUDE_*)    │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│              LLM Client Factory                                  │
│  createLLMClient(modelConfig)                                    │
│  → Returns: GeminiClient | ClaudeClient | LocalEISClient        │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│              External API Call                                  │
│  Gemini API (generativelanguage.googleapis.com)                 │
│  Claude API (api.anthropic.com)                                  │
│  Local EIS (localhost:8080) [Future]                            │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│              Parse & Structure Response                          │
│  - Extract summary, themes, suggestions (analysis)               │
│  - Format chat message (chat)                                   │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│              Update Firestore                                    │
│  - Increment analysisCount (journalEntries)                      │
│  - Increment messageCount (chatThreads)                         │
│  - Append messages (chatThreads)                                │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│              Return to Client                                    │
│  AnalysisResponse | ChatResponse                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. Model Router (`src/modelRouter.ts`)

**Purpose**: Select appropriate model based on tier and operation.

**Routing Rules**:

| Tier | Operation | Model Selected |
|------|-----------|----------------|
| FREE | Any | `gemini-3-flash-preview` (backend quotas) |
| PAID | journal_analysis | `gemini-3-flash-preview` (unlimited) |
| PAID | deep_reflection | Claude Sonnet |
| PAID | chat_message | `gemini-3-flash-preview` (unlimited) |
| PAID | theme_extraction | `gemini-3-flash-preview` |
| PAID | monthly_summary | Claude Sonnet |

**Note**: FREE and PAID both use the same Gemini 2.5 model. The difference is backend-enforced quotas, not model capabilities.

**Future Local Model**:
- When `LOCAL_EIS` is available and user opts in
- Suitable for: `chat_message`, `journal_analysis`
- Checks local server health before routing

### 2. Quota Guards (`src/quotaGuards.ts`)

**Functions**:
- `checkCanAnalyzeEntry(userId, entryId)`: Enforces 4 analyses/entry limit for FREE tier
- `checkCanSendMessage(userId, threadId)`: Enforces 200 messages/thread limit for FREE tier
- `incrementAnalysisCount(entryId)`: Updates Firestore counter
- `incrementMessageCount(threadId)`: Updates Firestore counter

**Error Structure**:
```typescript
{
  code: "ANALYSIS_LIMIT_REACHED" | "CHAT_LIMIT_REACHED" | "TIER_RESTRICTION",
  message: string,
  currentUsage: number,
  limit: number,
  upgradeRequired: boolean,
  tier: SubscriptionTier
}
```

### 3. LLM Clients (`src/llmClients.ts`)

**GeminiClient**:
- Supports `gemini-3-flash-preview` (free and paid tiers)
- Uses `generativelanguage.googleapis.com/v1beta`
- Both use the same underlying Gemini 2.5 model - difference is backend quotas
- Handles system instructions and conversation history
- Supports streaming (for future use)

**ClaudeClient**:
- Supports Claude Haiku and Claude Sonnet
- Uses `api.anthropic.com/v1`
- Handles system prompts and conversation history
- Supports streaming (for future use)

**LocalEISClient** (Future):
- Placeholder for local inference server
- Would connect to `localhost:8080`
- Requires local server health check

### 4. Cloud Functions

#### `analyzeJournalEntry`
- **Input**: `{ entryId, entryContent }`
- **Output**: `{ summary, themes, suggestions, tier, modelUsed }`
- **Flow**: Auth → Quota Check → Model Selection → LLM Call → Parse → Update → Return

#### `sendChatMessage`
- **Input**: `{ threadId, message }`
- **Output**: `{ threadId, message, messageCount, modelUsed }`
- **Flow**: Auth → Quota Check → Load Thread → Model Selection → LLM Call → Update → Return

#### `stripeWebhook`
- **Input**: Stripe webhook event
- **Flow**: Verify Signature → Map customerId → Update Firestore
- **Events**: `subscription.created`, `subscription.updated`, `subscription.deleted`

---

## Firestore Schema

### Collection: `users/{userId}`
```typescript
{
  subscriptionTier: "FREE" | "PAID",
  subscriptionStatus: "active" | "canceled" | "trial",
  stripeCustomerId?: string,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Collection: `journalEntries/{entryId}`
```typescript
{
  userId: string,
  content: string,
  analysisCount: number,  // Incremented on each analysis
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Collection: `chatThreads/{threadId}`
```typescript
{
  userId: string,
  messageCount: number,  // Incremented on each user message
  messages: ChatMessage[],
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

---

## Environment Configuration

### Secrets (set via `firebase functions:secrets:set`)
- `GEMINI_API_KEY`
- `ANTHROPIC_API_KEY`

### Config (set via `firebase functions:config:set`)
- `GEMINI_FLASH_MODEL_ID` (default: "gemini-3-flash-preview" - free tier with backend quotas)
- `GEMINI_PRO_MODEL_ID` (default: "gemini-3-flash-preview" - paid tier, unlimited)
- `CLAUDE_HAIKU_MODEL_ID` (default: "claude-3-haiku-20240307")
- `CLAUDE_SONNET_MODEL_ID` (default: "claude-3-5-sonnet-20241022")
- `FREE_MAX_ANALYSES_PER_ENTRY` (default: "4")
- `FREE_MAX_CHAT_TURNS_PER_THREAD` (default: "200")

---

## Migration Path to Gemini 3.0

**No code changes required!**

1. Update model IDs via config:
   ```bash
   firebase functions:config:set gemini.flash_model_id="gemini-3.0-flash"
   firebase functions:config:set gemini.pro_model_id="gemini-3.0-pro"
   ```

2. Redeploy functions:
   ```bash
   npm run build
   firebase deploy --only functions
   ```

3. Test API compatibility (response format should remain the same)

The model router automatically uses the new model IDs from config.

---

## Local Model Integration (Future)

### Architecture Hook

The codebase includes:
- `LOCAL_EIS` model family in types
- `LocalEISClient` stub in `llmClients.ts`
- `isLocalModelAvailable()` method in `ModelRouter`
- `selectModelWithLocal()` method for local preference

### Implementation Steps (When Ready)

1. **Start Local Inference Server**:
   - Run EIS-O1/EIS-E1 inference server on `localhost:8080`
   - Implement health check endpoint

2. **Update LocalEISClient**:
   ```typescript
   async generateContent(prompt, systemPrompt, history) {
     const response = await fetch("http://localhost:8080/v1/chat/completions", {
       method: "POST",
       body: JSON.stringify({ messages, system: systemPrompt })
     });
     return response.json().choices[0].message.content;
   }
   ```

3. **Update Routing Logic**:
   - Check `isLocalModelAvailable()` before routing
   - Allow user preference for local processing
   - Fallback to cloud if local unavailable

4. **No Frontend Changes Needed**:
   - Model selection is transparent to client
   - Same API shape maintained

---

## Deployment Checklist

- [ ] Set API keys as secrets
- [ ] Configure model IDs (optional - defaults provided)
- [ ] Build TypeScript: `npm run build`
- [ ] Deploy functions: `firebase deploy --only functions`
- [ ] Test `analyzeJournalEntry` with free tier user
- [ ] Test `sendChatMessage` with free tier user
- [ ] Verify quota enforcement
- [ ] Test paid tier routing
- [ ] Configure Stripe webhook endpoint
- [ ] Test subscription updates

---

## Testing

### Free Tier Tests
1. Create free tier user
2. Attempt 5th analysis → Should fail with quota error
3. Send 201st message → Should fail with quota error
4. Verify Gemini Flash is used

### Paid Tier Tests
1. Create paid tier user
2. Verify unlimited analyses
3. Verify unlimited messages
4. Verify `gemini-3-flash-preview` routing based on operation

### Model Routing Tests
1. `journal_analysis` → `gemini-3-flash-preview` (paid, unlimited)
2. `deep_reflection` → Claude Sonnet (paid)
3. `chat_message` → `gemini-3-flash-preview` (paid, unlimited)
4. All operations → `gemini-3-flash-preview` (free, backend quotas)

