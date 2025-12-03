# API Behavior - No User-Facing Model Selection

## System Prompt

**LUMARA does not present API choices to the user.**

The system uses Gemini as the default and primary inference engine.

The model layer is upgradeable internally and is never exposed to the user.

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
