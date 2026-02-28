// config/providers.ts - Data-driven LLM provider registry
//
// Model-agnostic: Only defines API shape and auth format per provider.
// Model IDs are user-provided (e.g. "llama-4-200b", "gemini-3-flash-preview").
// When providers add new models, users just enter the new model ID — no code deploy.

export type ProviderId = "groq" | "openai" | "anthropic" | "gemini" | "cloudflare" | "swarmspace";

/** API shape: OpenAI-compatible (Groq, OpenAI, Cloudflare), Anthropic, or Gemini */
export type ApiShape = "openai" | "anthropic" | "gemini";

export interface ProviderConfig {
  id: ProviderId;
  displayName: string;
  /** Base URL (use {accountId} for cloudflare) */
  baseUrl: string;
  apiShape: ApiShape;
  /** How to pass API key: "bearer" | "x-api-key" | "query" (Gemini uses ?key=) */
  authType: "bearer" | "x-api-key" | "query";
  /** Default model ID for this provider (used as hint, user can override) */
  defaultModelId: string;
  /** If true, updateUserModelConfig requires accountId (e.g. Cloudflare) */
  requiresAccountId?: boolean;
  temperature?: number;
  maxTokens?: number;
}

/**
 * Provider registry - add new providers here; model IDs stay user-configurable.
 * To support a new provider (e.g. Mistral): add entry, implement in llmRouter.
 */
export const PROVIDER_REGISTRY: Record<ProviderId, ProviderConfig> = {
  groq: {
    id: "groq",
    displayName: "Groq",
    baseUrl: "https://api.groq.com/openai/v1",
    apiShape: "openai",
    authType: "bearer",
    defaultModelId: "openai/gpt-oss-120b",
    temperature: 0.7,
    maxTokens: 8192,
  },
  openai: {
    id: "openai",
    displayName: "OpenAI",
    baseUrl: "https://api.openai.com/v1",
    apiShape: "openai",
    authType: "bearer",
    defaultModelId: "gpt-4o",
    temperature: 0.7,
    maxTokens: 8192,
  },
  anthropic: {
    id: "anthropic",
    displayName: "Anthropic (Claude)",
    baseUrl: "https://api.anthropic.com/v1",
    apiShape: "anthropic",
    authType: "x-api-key",
    defaultModelId: "claude-3-5-sonnet-20241022",
    temperature: 0.7,
    maxTokens: 8192,
  },
  gemini: {
    id: "gemini",
    displayName: "Google (Gemini)",
    baseUrl: "https://generativelanguage.googleapis.com/v1beta",
    apiShape: "gemini",
    authType: "query",
    defaultModelId: "gemini-3-flash-preview",
    temperature: 0.7,
    maxTokens: 8192,
  },
  cloudflare: {
    id: "cloudflare",
    displayName: "Cloudflare Workers AI",
    baseUrl: "https://api.cloudflare.com/client/v4/accounts/{accountId}/ai/v1",
    apiShape: "openai",
    authType: "bearer",
    defaultModelId: "@cf/meta/llama-3.1-8b-instruct",
    requiresAccountId: true,
    temperature: 0.7,
    maxTokens: 8192,
  },
  swarmspace: {
    id: "swarmspace",
    displayName: "SwarmSpace (LLM plugins)",
    baseUrl: "https://generativelanguage.googleapis.com/v1beta",
    apiShape: "gemini",
    authType: "query",
    defaultModelId: "gemini-flash",
    temperature: 0.7,
    maxTokens: 8192,
  },
};

/** Aliases users might type (e.g. "claude" -> anthropic) */
export const PROVIDER_ALIASES: Record<string, ProviderId> = {
  claude: "anthropic",
  gpt: "openai",
  chatgpt: "openai",
  google: "gemini",
  cf: "cloudflare",
  workers: "cloudflare",
  swarm: "swarmspace",
};

export function resolveProvider(input: string): ProviderId | null {
  const lower = input.toLowerCase().trim();
  if (lower in PROVIDER_REGISTRY) return lower as ProviderId;
  if (lower in PROVIDER_ALIASES) return PROVIDER_ALIASES[lower];
  return null;
}

export function getProvider(providerId: ProviderId): ProviderConfig {
  const cfg = PROVIDER_REGISTRY[providerId];
  if (!cfg) throw new Error(`Unknown provider: ${providerId}`);
  return cfg;
}

/** Providers that can use project's API key (no user key required) */
export const PROVIDERS_WITH_PROJECT_KEY: ProviderId[] = ["groq", "gemini"];

export function canUseProjectKey(providerId: ProviderId): boolean {
  return PROVIDERS_WITH_PROJECT_KEY.includes(providerId);
}

/** Build baseUrl for providers that need runtime values (e.g. Cloudflare accountId) */
export function buildBaseUrl(providerId: ProviderId, accountId?: string): string {
  const cfg = PROVIDER_REGISTRY[providerId];
  if (!cfg) throw new Error(`Unknown provider: ${providerId}`);
  if (providerId === "cloudflare") {
    if (!accountId) throw new Error("Cloudflare requires accountId");
    return cfg.baseUrl.replace("{accountId}", accountId);
  }
  return cfg.baseUrl;
}
