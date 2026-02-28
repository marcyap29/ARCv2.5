"use strict";
// llmRouter.ts - Unified LLM routing for multi-provider chat
//
// Model-agnostic: provider + modelId + apiKey are inputs.
// When providers add new models, users just change modelId — no code deploy.
Object.defineProperty(exports, "__esModule", { value: true });
exports.PROVIDER_REGISTRY = void 0;
exports.llmChatCompletion = llmChatCompletion;
exports.validateApiKey = validateApiKey;
const providers_1 = require("./config/providers");
Object.defineProperty(exports, "PROVIDER_REGISTRY", { enumerable: true, get: function () { return providers_1.PROVIDER_REGISTRY; } });
const REQUEST_TIMEOUT_MS = 85000;
/** Unified chat completion — routes to correct API based on provider */
async function llmChatCompletion(options) {
    const { system = "", user, conversationHistory = [], modelId, provider, apiKey, accountId, temperature = 0.7, maxTokens = 8192, } = options;
    const config = (0, providers_1.getProvider)(provider);
    // SwarmSpace gemini-flash uses Gemini API
    const effectiveProvider = provider === "swarmspace" ? "gemini" : provider;
    const effectiveModelId = provider === "swarmspace" && modelId === "gemini-flash" ? "gemini-3-flash-preview" : modelId;
    const effectiveConfig = (0, providers_1.getProvider)(effectiveProvider);
    const baseUrl = (0, providers_1.buildBaseUrl)(effectiveProvider, accountId);
    switch (effectiveConfig.apiShape) {
        case "openai":
            return openaiCompletion(baseUrl, effectiveConfig.authType, apiKey, {
                model: effectiveModelId,
                system,
                user,
                conversationHistory,
                temperature,
                maxTokens,
            });
        case "anthropic":
            return anthropicCompletion(baseUrl, apiKey, {
                model: effectiveModelId,
                system,
                user,
                conversationHistory,
                temperature,
                maxTokens,
            });
        case "gemini":
            return geminiCompletion(baseUrl, apiKey, {
                model: effectiveModelId,
                system,
                user,
                conversationHistory,
                temperature,
                maxTokens,
            });
        default:
            throw new Error(`Unsupported API shape: ${config.apiShape}`);
    }
}
/** OpenAI-compatible API (Groq, OpenAI) */
async function openaiCompletion(baseUrl, authType, apiKey, opts) {
    const messages = [];
    if (opts.system.trim()) {
        messages.push({ role: "system", content: opts.system });
    }
    for (const m of opts.conversationHistory) {
        messages.push({ role: m.role, content: m.content });
    }
    messages.push({ role: "user", content: opts.user });
    const body = JSON.stringify({
        model: opts.model,
        messages,
        temperature: opts.temperature,
        max_tokens: opts.maxTokens,
        stream: false,
    });
    const url = `${baseUrl}/chat/completions`;
    const headers = {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body).toString(),
    };
    if (authType === "bearer") {
        headers["Authorization"] = `Bearer ${apiKey}`;
    }
    else if (authType === "x-api-key") {
        headers["x-api-key"] = apiKey;
    }
    const fullUrl = authType === "query" ? `${url}?key=${apiKey}` : url;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    try {
        const res = await fetch(fullUrl, {
            method: "POST",
            headers,
            body,
            signal: controller.signal,
        });
        const text = await res.text();
        if (!res.ok) {
            throw new Error(`OpenAI-compatible API error: ${res.status} - ${text}`);
        }
        const parsed = JSON.parse(text);
        const content = parsed.choices?.[0]?.message?.content;
        if (content == null) {
            throw new Error("API returned no content");
        }
        return content;
    }
    finally {
        clearTimeout(timeout);
    }
}
/** Anthropic API */
async function anthropicCompletion(baseUrl, apiKey, opts) {
    const messages = [];
    for (const m of opts.conversationHistory) {
        messages.push({ role: m.role, content: m.content });
    }
    messages.push({ role: "user", content: opts.user });
    const body = JSON.stringify({
        model: opts.model,
        max_tokens: opts.maxTokens,
        temperature: opts.temperature,
        system: opts.system || undefined,
        messages,
    });
    const url = `${baseUrl}/messages`;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    try {
        const res = await fetch(url, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
            },
            body,
            signal: controller.signal,
        });
        const text = await res.text();
        if (!res.ok) {
            throw new Error(`Anthropic API error: ${res.status} - ${text}`);
        }
        const parsed = JSON.parse(text);
        const content = parsed.content?.[0]?.text;
        if (content == null) {
            throw new Error("Anthropic API returned no content");
        }
        return content;
    }
    finally {
        clearTimeout(timeout);
    }
}
/** Gemini API */
async function geminiCompletion(baseUrl, apiKey, opts) {
    const contents = [];
    for (const m of opts.conversationHistory) {
        contents.push({
            role: m.role === "user" ? "user" : "model",
            parts: [{ text: m.content }],
        });
    }
    contents.push({ role: "user", parts: [{ text: opts.user }] });
    const body = {
        contents,
        generationConfig: {
            temperature: opts.temperature,
            maxOutputTokens: opts.maxTokens,
        },
    };
    if (opts.system.trim()) {
        body.systemInstruction = { parts: [{ text: opts.system }] };
    }
    const url = `${baseUrl}/models/${opts.model}:generateContent?key=${apiKey}`;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    try {
        const res = await fetch(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(body),
            signal: controller.signal,
        });
        const text = await res.text();
        if (!res.ok) {
            throw new Error(`Gemini API error: ${res.status} - ${text}`);
        }
        const parsed = JSON.parse(text);
        const content = parsed.candidates?.[0]?.content?.parts?.[0]?.text;
        if (content == null) {
            throw new Error("Gemini API returned no content");
        }
        return content;
    }
    finally {
        clearTimeout(timeout);
    }
}
/**
 * Validate API key with a minimal test call.
 * For swarmspace, validates against Gemini (gemini-flash plugin uses Gemini).
 */
async function validateApiKey(provider, modelId, apiKey, accountId) {
    // SwarmSpace gemini-flash uses Gemini API; validate with Gemini model
    const effectiveProvider = provider === "swarmspace" ? "gemini" : provider;
    const effectiveModel = provider === "swarmspace" ? "gemini-3-flash-preview" : modelId;
    await llmChatCompletion({
        provider: effectiveProvider,
        modelId: effectiveModel,
        apiKey,
        accountId: provider === "cloudflare" ? accountId : undefined,
        user: "Reply with exactly: OK",
        conversationHistory: [],
        maxTokens: 10,
    });
}
//# sourceMappingURL=llmRouter.js.map