# Per-User Model Configuration Setup

Users can configure their own LLM provider (Groq, OpenAI, Anthropic, Gemini) and API key via in-chat flow or the `updateUserModelConfig` callable.

## Prerequisites

1. **Encryption key** — Required for storing API keys. Generate a 32-byte (64 hex char) key:

   ```bash
   node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
   ```

2. **Set the secret**:

   ```bash
   firebase functions:secrets:set LLM_SETTINGS_ENCRYPTION_KEY
   # Paste the 64-char hex string when prompted
   ```

3. **Redeploy** functions that use it (`sendChatMessage`, `updateUserModelConfig`).

## Supported Providers

- **groq** — Groq (GPT-OSS, Llama)
- **openai** — OpenAI (GPT-4, etc.)
- **anthropic** — Anthropic (Claude)
- **gemini** — Google Gemini
- **cloudflare** — Cloudflare Workers AI (requires accountId)
- **swarmspace** — SwarmSpace LLM plugins (e.g. gemini-flash)

## In-Chat Flow

1. User: "I want to change my model"
2. LUMARA: "Which provider? (groq, openai, anthropic, gemini, cloudflare, swarmspace)"
3. User: "gemini" (or "groq", etc.)
4. For **groq** or **gemini**: LUMARA asks "Use **default** (no API key) or **own** (your key)?"
   - **default** → uses project's GEMINI_API_KEY or GROQ_API_KEY (no setup)
   - **own** → user provides their API key
5. For **cloudflare**: LUMARA asks for account ID first, then model ID
6. For others: LUMARA: "What's the model ID?"
7. User: enters model ID
8. If own key: LUMARA: "Please provide your API key."
9. LUMARA: "Done. Your chat is now using ..."

## SwarmSpace Integration

When a user configures **swarmspace** or **gemini**, the swarmspaceRouter passes their API key to SwarmSpace LLM plugins (e.g. gemini-flash) via `params._apiKeyOverride`. The Cloudflare worker must support this parameter to use the user's key.

## API (Callable)

From Settings or your app:

```ts
// Use project default (groq/gemini only — no API key needed)
const result = await httpsCallable(functions, 'updateUserModelConfig')({
  provider: 'gemini',
  modelId: 'gemini-3-flash-preview',
  useProjectKey: true,
});

// Use your own API key
const result = await httpsCallable(functions, 'updateUserModelConfig')({
  provider: 'anthropic',
  modelId: 'claude-3-5-sonnet-20241022',
  apiKey: 'sk-ant-...',
  accountId: 'required-for-cloudflare',
});
// { success: true, provider, modelId, displayName }
```

## Flexible Prompt Architecture

- **Provider registry** (`config/providers.ts`): Add new providers without changing chat logic.
- **Model IDs**: User-provided. When Groq adds `llama-4-200b`, users just enter it—no deploy.
- **System prompt**: Centralized in `prompts.ts`; model-agnostic.
- **To add a provider** (e.g. Mistral): Add entry to `PROVIDER_REGISTRY`, implement API shape in `llmRouter.ts` if needed.
