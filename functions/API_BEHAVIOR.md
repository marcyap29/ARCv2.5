# API Behavior - No User-Facing Model Selection

## System Prompt

**LUMARA does not present API choices to the user.**

The system uses Gemini as the default and primary inference engine with **Google Search Grounding enabled** for real-time web information access.

The model layer is upgradeable internally and is never exposed to the user.

### Closing Statement Engine

LUMARA uses a sophisticated closing statement engine to prevent repetitive, robotic endings:

- **75+ closing variations** across 5 context categories (Reflection/Emotion, Planning/Action, Identity/Phase, Regulation/Overwhelm, Neutral/Light)
- **7 ending styles** rotated to avoid patterns (soft question, reflective echo, gentle prompt, non-prompt closure, pause-affirmation, next-step suggestion, user-led turn)
- **ATLAS phase integration** - Closings adapt to user's current life phase
- **Anti-repetition enforcement** - Never repeats the same closing within the last 15 messages
- **Context-aware selection** - Closings match conversation content and energy level

See `CLOSING_STATEMENT_ENGINE.md` for full documentation.

## Web Access & Information Priority

**LUMARA has access to real-time web information via Google Search Grounding (Gemini models only).**

### Priority of Sources

1. **Primary Sources (Always Check First):**
   - User's journals and entries
   - Prior conversations with LUMARA
   - Uploaded documents
   - Saved knowledge bases
   - **Use these before considering the web**

2. **Web Access (When Needed):**
   - User directly requests external information
   - Question cannot be answered from private data
   - Real-time information needed (current events, Wikipedia, etc.)
   - **Never block the user from accessing external information**

### Trigger-Safety Protocol (Without Censorship)

**Core Principle:** Information is allowed. Graphic surprise is not.

**Three-Stage Protocol (Mandatory):**

1. **Content Note** - Short, steady, non-dramatic heads-up when web results may include:
   - Violence, sexual violence, graphic injury
   - Graphic medical content, hate content, extreme sensationalism

2. **Summary (Default Delivery)** - Structured, factual, non-graphic overview:
   - Remove sensory detail
   - Avoid vivid description
   - Avoid emotional projection
   - Focus on mechanisms, sequence, implications, and relevance

3. **Offer Detail (Only on Explicit Request)** - Provide deeper information when user explicitly requests:
   - "Give me the full detail"
   - "Show me the raw version"
   - "You can give the specifics"

**Key Rules:**
- Never surprise users with graphic content
- User agency always comes first - if user wants unfiltered information, provide it
- Filters are safeguards, not restrictions
- Do not censor, infantilize, or moralize
- Answer directly with the protocol above
- Neutral, grounded delivery - steady tone, no dramatization

## Model Selection Rules

1. **Default model = Gemini 2.5** (or Gemini 2.5 Flash for free tier)
2. **LUMARA may internally failover** to a backup model if Gemini is unavailable
3. **Failover is silent** - The user is never shown API brand names or options
4. **All generations must follow** the LUMARA tone, memory rules, and narrative intelligence stack

## Account Tier

- **Free users** = Throttled requests (strict rate limits)
  - Max 20 requests per day
  - Max 3 requests per minute
  
- **Paid users** = No throttling
  - Unlimited requests
  - Same Gemini model, no rate limits

## Billing

- **Stripe subscription ($30/month)** upgrades the user to "Pro" and removes throttling
- Webhook events handled:
  - `checkout.session.completed` - Upgrade to pro
  - `invoice.payment_succeeded` - Confirm pro status
  - `invoice.payment_failed` - Downgrade to free
  - `customer.subscription.deleted` - Downgrade to free

## Authentication

- **Firebase Auth** is the source of truth for user identity
- **Throttling is applied** based on Firebase user's subscription state
- User document structure:
  ```typescript
  {
    userId: string;
    plan: "free" | "pro";
    stripeCustomerId?: string;
    stripeSubscriptionId?: string;
  }
  ```

## Implementation Rules

- **Do not show** any settings, toggles, or menus related to API or model selection
- **The Settings screen** only displays:
  - User account
  - Subscription status
  - Backup/export
  - Data permissions
  - Arcform configurations
- **Model selection is completely internal** - users only see LUMARA responses
- **API provider names are never exposed** to users

## Rate Limiting

### Free Plan
```
maxRequestsPerDay: 20
maxRequestsPerMinute: 3
```

### Pro Plan ($30/month)
```
maxRequestsPerDay: unlimited
maxRequestsPerMinute: unlimited
```

## Response Structure

**User-facing responses do NOT include:**
- `modelUsed` field
- API provider names
- Model selection information
- Any internal routing details

**User-facing responses include:**
- Content (summary, themes, suggestions, messages)
- Tier information (for upgrade prompts)
- Usage information (for quota limits)

## Architecture

```
App → Firebase Auth → "User Tier" (free/pro)
App → LUMARA API → Gemini (internal only)
LUMARA API → Stripe for Subscription Webhooks
```

**Upgrade Path:**
If you switch to a new model (OpenAI, DeepSeek, local), you only change the backend inference router. Users never see it.

