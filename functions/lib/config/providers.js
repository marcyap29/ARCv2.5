"use strict";
// config/providers.ts - Data-driven LLM provider registry
//
// Model-agnostic: Only defines API shape and auth format per provider.
// Model IDs are user-provided (e.g. "llama-4-200b", "gemini-3-flash-preview").
// When providers add new models, users just enter the new model ID — no code deploy.
Object.defineProperty(exports, "__esModule", { value: true });
exports.PROVIDERS_WITH_PROJECT_KEY = exports.PROVIDER_ALIASES = exports.PROVIDER_REGISTRY = void 0;
exports.resolveProvider = resolveProvider;
exports.getProvider = getProvider;
exports.canUseProjectKey = canUseProjectKey;
exports.buildBaseUrl = buildBaseUrl;
/**
 * Provider registry - add new providers here; model IDs stay user-configurable.
 * To support a new provider (e.g. Mistral): add entry, implement in llmRouter.
 */
exports.PROVIDER_REGISTRY = {
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
exports.PROVIDER_ALIASES = {
    claude: "anthropic",
    gpt: "openai",
    chatgpt: "openai",
    google: "gemini",
    cf: "cloudflare",
    workers: "cloudflare",
    swarm: "swarmspace",
};
function resolveProvider(input) {
    const lower = input.toLowerCase().trim();
    if (lower in exports.PROVIDER_REGISTRY)
        return lower;
    if (lower in exports.PROVIDER_ALIASES)
        return exports.PROVIDER_ALIASES[lower];
    return null;
}
function getProvider(providerId) {
    const cfg = exports.PROVIDER_REGISTRY[providerId];
    if (!cfg)
        throw new Error(`Unknown provider: ${providerId}`);
    return cfg;
}
/** Providers that can use project's API key (no user key required) */
exports.PROVIDERS_WITH_PROJECT_KEY = ["groq", "gemini"];
function canUseProjectKey(providerId) {
    return exports.PROVIDERS_WITH_PROJECT_KEY.includes(providerId);
}
/** Build baseUrl for providers that need runtime values (e.g. Cloudflare accountId) */
function buildBaseUrl(providerId, accountId) {
    const cfg = exports.PROVIDER_REGISTRY[providerId];
    if (!cfg)
        throw new Error(`Unknown provider: ${providerId}`);
    if (providerId === "cloudflare") {
        if (!accountId)
            throw new Error("Cloudflare requires accountId");
        return cfg.baseUrl.replace("{accountId}", accountId);
    }
    return cfg.baseUrl;
}
//# sourceMappingURL=providers.js.map