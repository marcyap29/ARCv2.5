# Backend Architecture: Gemini 2.5 + Claude with Tier-Based Routing

**Last Updated:** December 3, 2025

## Overview

This document outlines the backend architecture that uses Google Gemini 2.5 and Anthropic Claude for AI processing, implementing tier-based access control, rate limiting, and developer throttle unlock capabilities. Model selection is completely internal—users never see API provider names or model choices.

## Architecture Flow

```
Flutter App → Firebase Auth → Cloud Functions → Rate Limiter → Model Router → Direct API Calls
     ↓              ↓              ↓              ↓              ↓              ↓
User Action → Auth Token → analyzeEntry/ → Check Limits → Tier Check → Gemini 2.5/Claude
                           sendMessage   → Throttle?    → Model Select  ↓
                                        → Update Counters Response
                                        ↓              ↓
                                   Success ← AI Processing
```

## Core Components

### 1. **Model Router Layer**
- **ModelFamily**: `GEMINI_FLASH`, `GEMINI_PRO`, `CLAUDE_HAIKU`, `CLAUDE_SONNET`
- **ModelConfig**: Configuration interface for each model
- **Router Logic**: Selects model based on user tier + operation type

### 2. **Tier System**
#### **Free Tier**
- Model: Gemini 2.5 Flash (internal default)
- **Rate Limiting (Primary)**: 20 requests/day, 3 requests/minute
- **Legacy Limits**: 4 deep analyses per journal entry, 200 chat turns per thread
- No Claude access
- Throttle unlock available (password-protected developer feature)

#### **Paid Tier ($30/mo)**
- Models: Gemini 2.5 + Claude (Haiku/Sonnet)
- Unlimited requests (no rate limiting)
- Unlimited journal analysis
- Unlimited chat turns
- Access to premium Claude models
- Automatic failover to Claude if Gemini unavailable

### 3. **Database Schema (Firestore)**

#### `users/{userId}`
```typescript
interface User {
  plan: "free" | "pro";  // Simplified tier field
  subscriptionTier?: "FREE" | "PAID";  // Legacy field (deprecated)
  stripeSubscriptionId?: string;
  stripeCustomerId?: string;
  throttleUnlocked?: boolean;  // Developer throttle unlock
  throttleUnlockedAt?: Timestamp;  // When throttle was unlocked
  createdAt: Timestamp;
  lastActive: Timestamp;
}
```

#### `rateLimits/{userId}`
```typescript
interface RateLimit {
  userId: string;
  requestsToday: number;  // Daily request counter
  requestsLastMinute: number;  // Per-minute counter
  lastRequestAt: Timestamp;  // Last request timestamp
  dayWindowStart: Timestamp;  // Start of current day window
  minuteWindowStart: Timestamp;  // Start of current minute window
  updatedAt: Timestamp;
}
```

#### `journalEntries/{entryId}`
```typescript
interface JournalEntry {
  userId: string;
  content: string;
  analysisCount: number; // Incremented on each deep analysis
  createdAt: Timestamp;
  lastAnalyzedAt?: Timestamp;
}
```

#### `chatThreads/{threadId}`
```typescript
interface ChatThread {
  userId: string;
  messageCount: number; // Incremented on each chat turn
  createdAt: Timestamp;
  lastMessageAt: Timestamp;
}
```

## Environment Variables Structure

```bash
# API Keys
GEMINI_API_KEY=your_gemini_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key

# Model Configuration
GEMINI_FLASH_MODEL_ID="gemini-2.5-flash"  # Free tier default
GEMINI_PRO_MODEL_ID="gemini-2.5"  # Paid tier default (not gemini-2.5-pro)
CLAUDE_HAIKU_MODEL_ID="claude-3-haiku-20240307"
CLAUDE_SONNET_MODEL_ID="claude-3-sonnet-20240229"

# Rate Limiting (Primary Quota System)
FREE_MAX_REQUESTS_PER_DAY=20
FREE_MAX_REQUESTS_PER_MINUTE=3

# Legacy Usage Limits (Maintained for Compatibility)
FREE_MAX_ANALYSES_PER_ENTRY=4
FREE_MAX_CHAT_TURNS_PER_THREAD=200

# Throttle Unlock (Developer Feature)
THROTTLE_UNLOCK_PASSWORD=your_secure_password

# Future Model Support
LOCAL_EIS_MODEL_ID="eis-o1-local" # For future local model integration
```

## Cloud Functions

### 1. `analyzeJournalEntry`
- **Input**: `{ entryId: string, entryContent: string }`
- **Process**:
  1. Verify Firebase Auth token
  2. Load user + entry from Firestore
  3. Check rate limits (primary: 20/day, 3/minute for free tier)
  4. Check throttle unlock status (bypasses rate limits if unlocked)
  5. Check legacy analysis quota (4 per entry for free tier)
  6. Route to appropriate model (Gemini 2.5 Flash/Pro or Claude)
  7. Process AI request with failover support
  8. Increment rate limit counters
  9. Return structured analysis (no `modelUsed` field)

### 2. `sendChatMessage`
- **Input**: `{ threadId: string, message: string }`
- **Process**:
  1. Verify user authentication
  2. Load thread from Firestore
  3. Check rate limits (primary: 20/day, 3/minute for free tier)
  4. Check throttle unlock status (bypasses rate limits if unlocked)
  5. Check legacy chat quota (200 turns per thread for free tier)
  6. Route to appropriate model (Gemini 2.5 Flash/Pro or Claude)
  7. Process AI request with failover support
  8. Append message and response
  9. Increment rate limit counters and messageCount
  10. Return updated conversation (no `modelUsed` field)

### 3. `stripeWebhook` (Stripe Webhook Handler)
- **Events**: `checkout.session.completed`, `invoice.payment_succeeded`, `invoice.payment_failed`, `customer.subscription.deleted`
- **Process**:
  1. Receive Stripe webhook event
  2. Verify webhook signature
  3. Map `customerId` → `userId`
  4. Update `plan: "free" | "pro"` and `stripeSubscriptionId`
  5. Update Firestore user document

### 4. `unlockThrottle` (Developer Feature)
- **Input**: `{ password: string }`
- **Process**:
  1. Verify Firebase Auth token
  2. Compare password with `THROTTLE_UNLOCK_PASSWORD` using `crypto.timingSafeEqual`
  3. Update user document: `throttleUnlocked: true`, `throttleUnlockedAt: now()`
  4. Return success status

### 5. `lockThrottle`
- **Input**: None (uses auth token)
- **Process**:
  1. Verify Firebase Auth token
  2. Remove `throttleUnlocked` and `throttleUnlockedAt` from user document
  3. Return success status

### 6. `checkThrottleStatus`
- **Input**: None (uses auth token)
- **Process**:
  1. Verify Firebase Auth token
  2. Load user document
  3. Return `{ unlocked: boolean }`

### 7. `generateJournalPrompts`
- **Input**: `{ expanded: boolean, context?: { recentEntries?: string[], recentChats?: string[], currentPhase?: string } }`
- **Process**:
  1. Verify Firebase Auth token
  2. Check rate limits
  3. Route to appropriate model
  4. Generate contextual journal prompts (4 initial or 12-18 expanded)
  5. Return `{ prompts: string[], count: number }`

### 8. `generateJournalReflection`
- **Input**: `{ entryText: string, phase?: string, mood?: string, chronoContext?: object, chatContext?: string, mediaContext?: string, options?: object }`
- **Process**:
  1. Verify Firebase Auth token
  2. Load user from Firestore
  3. Check rate limits (primary: 20/day, 3/minute for free tier)
  4. Route to appropriate model (Gemini 2.5 Flash/Pro or Claude)
  5. Build system prompt with LUMARA Master Prompt (simplified for journal reflections)
  6. Build user prompt based on options and context
  7. Generate reflection using LLM
  8. Return `{ reflection: string }`
- **Purpose**: In-journal LUMARA reflections (replaces direct `geminiSend()` calls)
- **Note**: Backend handles all API keys via Firebase Secrets; no local API key needed

## Model Routing Logic

**Internal Only** - Users never see model selection or API provider names.

```typescript
function selectModel(userPlan: "free" | "pro", operationType: string): ModelFamily {
  // Free tier: Always Gemini 2.5 Flash
  if (userPlan === "free") {
    return ModelFamily.GEMINI_FLASH;  // gemini-2.5-flash
  }

  // Paid tier: Gemini 2.5 default, Claude for premium operations
  if (userPlan === "pro") {
    if (operationType === "deep_reflection" || operationType === "premium_analysis") {
      return ModelFamily.CLAUDE_SONNET;
    } else {
      return ModelFamily.GEMINI_PRO;  // gemini-2.5
    }
  }

  throw new Error("Invalid plan or operation type");
}

// With failover support
async function selectModelWithFailover(
  userPlan: "free" | "pro",
  operationType: string
): Promise<ModelConfig> {
  const primary = selectModel(userPlan, operationType);
  
  // Health check and failover logic
  if (primary.family === "GEMINI" && !await checkGeminiHealth()) {
    // Failover to Claude if Gemini unavailable
    return userPlan === "pro" 
      ? ModelFamily.CLAUDE_HAIKU 
      : throw new Error("Gemini unavailable for free tier");
  }
  
  return primary;
}
```

## Quota Enforcement

### Rate Limiting (Primary System)

**Free Tier**: 20 requests/day, 3 requests/minute
**Pro Tier**: Unlimited (no rate limiting)
**Throttle Unlock**: Bypasses all rate limits

```typescript
async function checkRateLimit(userId: string): Promise<QuotaCheckResult> {
  const user = await admin.firestore().doc(`users/${userId}`).get();
  const userData = user.data() as UserDocument;
  
  // Pro tier or throttle unlocked: no limits
  if (userData.plan === "pro" || userData.throttleUnlocked) {
    return { allowed: true };
  }
  
  // Load or create rate limit document
  const rateLimitRef = admin.firestore().doc(`rateLimits/${userId}`);
  const rateLimitDoc = await rateLimitRef.get();
  const now = admin.firestore.Timestamp.now();
  
  // Reset day window if needed
  // Reset minute window if needed
  // Check daily limit (20 requests)
  // Check minute limit (3 requests)
  // Increment counters if allowed
  
  return { allowed: true/false, reason?: string };
}
```

### Legacy Quota Enforcement (Maintained for Compatibility)

```typescript
async function checkAnalysisQuota(userId: string, entryId: string): Promise<boolean> {
  const entry = await admin.firestore().doc(`journalEntries/${entryId}`).get();
  const analysisCount = entry.data()?.analysisCount || 0;

  return analysisCount < FREE_MAX_ANALYSES_PER_ENTRY;  // 4
}

async function checkChatQuota(userId: string, threadId: string): Promise<boolean> {
  const thread = await admin.firestore().doc(`chatThreads/${threadId}`).get();
  const messageCount = thread.data()?.messageCount || 0;

  return messageCount < FREE_MAX_CHAT_TURNS_PER_THREAD;  // 200
}
```

## Migration from Venice AI

### What Changes:
1. **Remove**: All Flutter-side LLM providers
2. **Keep**: Firebase Cloud Functions endpoints (`analyzeJournalEntry`, `sendChatMessage`)
3. **Add**: Direct Gemini/Claude API calls in Cloud Functions
4. **Add**: Tier and quota enforcement logic

### What Stays the Same:
- Frontend API calls to Firebase Cloud Functions
- Authentication flow
- Core journaling and chat functionality
- User experience (transparent backend changes)

## Future Extensibility

### Local Model Support
When EIS-O1/EIS-E1 models become available:
1. Add `LOCAL_EIS` to ModelFamily enum
2. Create `LocalClient` for device-specific inference
3. Update routing rules to prefer local models for privacy
4. Implement model availability detection

### Gemini 3.0 Migration
Future migration to Gemini 3.0:
1. Update `GEMINI_FLASH_MODEL_ID` and `GEMINI_PRO_MODEL_ID` environment variables
2. No architecture changes required (model selection is internal)
3. Test API compatibility and adjust if needed
4. Users never see model version changes (transparent upgrade)

## Security Considerations

1. **API Key Protection**: All API keys stored securely as Firebase Functions secrets
2. **Authentication**: Every function call validates Firebase Auth token
3. **Authorization**: Tier-based access control prevents unauthorized usage
4. **Rate Limiting**: Primary quota system (20/day, 3/minute) prevents abuse
5. **Throttle Unlock Security**: Password verification using `crypto.timingSafeEqual` to prevent timing attacks
6. **Data Privacy**: No conversation data stored beyond necessary analytics
7. **Model Selection Privacy**: Internal-only model routing (no user-facing API choices)
8. **Failover Security**: Automatic failover to Claude if Gemini unavailable (paid tier only)

## Performance Optimizations

1. **Connection Pooling**: Reuse HTTP connections for API calls
2. **Response Caching**: Cache frequent analysis patterns
3. **Async Processing**: Non-blocking API calls where possible
4. **Error Handling**: Robust fallback mechanisms
5. **Monitoring**: Comprehensive logging and error tracking