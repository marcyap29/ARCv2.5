# Backend Architecture: Gemini + Claude with Tier-Based Routing

## Overview

This document outlines the new backend architecture that replaces Venice AI with direct Gemini and Claude integration, implementing tier-based access control and usage quotas.

## Architecture Flow

```
Flutter App → Firebase Auth → Cloud Functions → Model Router → Direct API Calls
     ↓              ↓              ↓              ↓              ↓
User Action → Auth Token → analyzeEntry/ → Tier Check → Gemini/Claude
                           sendMessage   → Quota Check  ↓
                                        → Model Select  Response
                                        ↓              ↓
                                   Update Counters ← Success
```

## Core Components

### 1. **Model Router Layer**
- **ModelFamily**: `GEMINI_FLASH`, `GEMINI_PRO`, `CLAUDE_HAIKU`, `CLAUDE_SONNET`
- **ModelConfig**: Configuration interface for each model
- **Router Logic**: Selects model based on user tier + operation type

### 2. **Tier System**
#### **Free Tier**
- Model: Gemini Flash only
- Limits: 4 deep analyses per journal entry, 200 chat turns per thread
- No Claude access

#### **Paid Tier ($30/mo)**
- Models: Gemini Pro + Claude (Haiku/Sonnet)
- Unlimited journal analysis
- Unlimited chat turns
- Access to premium Claude models

### 3. **Database Schema (Firestore)**

#### `users/{userId}`
```typescript
interface User {
  subscriptionTier: "FREE" | "PAID";
  subscriptionStatus: "active" | "canceled" | "trial";
  stripeCustomerId?: string;
  createdAt: Timestamp;
  lastActive: Timestamp;
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
GEMINI_FLASH_MODEL_ID="gemini-1.5-flash"
GEMINI_PRO_MODEL_ID="gemini-1.5-pro"
CLAUDE_HAIKU_MODEL_ID="claude-3-haiku-20240307"
CLAUDE_SONNET_MODEL_ID="claude-3-sonnet-20240229"

# Usage Limits
FREE_MAX_ANALYSES_PER_ENTRY=4
FREE_MAX_CHAT_TURNS_PER_THREAD=200

# Future Model Support
LOCAL_EIS_MODEL_ID="eis-o1-local" # For future local model integration
```

## Cloud Functions

### 1. `analyzeJournalEntry`
- **Input**: `{ entryId: string, analysisType: string }`
- **Process**:
  1. Verify Firebase Auth token
  2. Load user + entry from Firestore
  3. Check subscription tier
  4. Enforce analysis quota (free tier only)
  5. Route to appropriate model (Gemini Flash/Pro or Claude)
  6. Increment `analysisCount`
  7. Return structured analysis

### 2. `sendChatMessage`
- **Input**: `{ threadId: string, message: string }`
- **Process**:
  1. Verify user authentication
  2. Load thread from Firestore
  3. Check subscription tier
  4. Enforce chat quota (free tier only)
  5. Route to appropriate model
  6. Append message and response
  7. Increment `messageCount`
  8. Return updated conversation

### 3. `updateSubscription` (Stripe Webhook)
- **Process**:
  1. Receive Stripe webhook event
  2. Map `customerId` → `userId`
  3. Update `subscriptionTier` and `subscriptionStatus`
  4. Update Firestore user document

## Model Routing Logic

```typescript
function selectModel(userTier: string, operationType: string): ModelFamily {
  if (userTier === "FREE") {
    return ModelFamily.GEMINI_FLASH;
  }

  if (userTier === "PAID") {
    if (operationType === "deep_reflection" || operationType === "premium_analysis") {
      return ModelFamily.CLAUDE_SONNET;
    } else {
      return ModelFamily.GEMINI_PRO;
    }
  }

  throw new Error("Invalid tier or operation type");
}
```

## Quota Enforcement

### Free Tier Limits
```typescript
async function checkAnalysisQuota(userId: string, entryId: string): Promise<boolean> {
  const entry = await admin.firestore().doc(`journalEntries/${entryId}`).get();
  const analysisCount = entry.data()?.analysisCount || 0;

  return analysisCount < FREE_MAX_ANALYSES_PER_ENTRY;
}

async function checkChatQuota(userId: string, threadId: string): Promise<boolean> {
  const thread = await admin.firestore().doc(`chatThreads/${threadId}`).get();
  const messageCount = thread.data()?.messageCount || 0;

  return messageCount < FREE_MAX_CHAT_TURNS_PER_THREAD;
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
1. Update `GEMINI_PRO_MODEL_ID` environment variable
2. No architecture changes required
3. Test API compatibility and adjust if needed

## Security Considerations

1. **API Key Protection**: All API keys stored securely in Firebase Functions environment
2. **Authentication**: Every function call validates Firebase Auth token
3. **Authorization**: Tier-based access control prevents unauthorized usage
4. **Rate Limiting**: Built-in quota enforcement prevents abuse
5. **Data Privacy**: No conversation data stored beyond necessary analytics

## Performance Optimizations

1. **Connection Pooling**: Reuse HTTP connections for API calls
2. **Response Caching**: Cache frequent analysis patterns
3. **Async Processing**: Non-blocking API calls where possible
4. **Error Handling**: Robust fallback mechanisms
5. **Monitoring**: Comprehensive logging and error tracking