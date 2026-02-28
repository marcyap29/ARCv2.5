"use strict";
// updateUserModelConfig.ts - Save per-user LLM provider, model, and API key
//
// Callable from Settings UI or in-chat flow. Validates API key before storing.
Object.defineProperty(exports, "__esModule", { value: true });
exports.updateUserModelConfig = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const authGuard_1 = require("../authGuard");
const config_1 = require("../config");
const saveUserModelConfig_1 = require("../saveUserModelConfig");
const providers_1 = require("../config/providers");
/** Valid provider IDs */
const VALID_PROVIDERS = ["groq", "openai", "anthropic", "gemini", "cloudflare", "swarmspace"];
/**
 * Update user's LLM configuration (provider, model, API key).
 * For groq/gemini, useProjectKey: true uses project's key (no apiKey needed).
 * For cloudflare, accountId is required.
 *
 * Request: { provider: string, modelId: string, apiKey?: string, accountId?: string, useProjectKey?: boolean }
 * Response: { success: true, provider, modelId }
 */
exports.updateUserModelConfig = (0, https_1.onCall)({
    secrets: [config_1.LLM_SETTINGS_ENCRYPTION_KEY],
}, async (request) => {
    const { provider: providerInput, modelId, apiKey, accountId, useProjectKey } = request.data ?? {};
    if (!providerInput || typeof providerInput !== "string") {
        throw new https_1.HttpsError("invalid-argument", "provider is required");
    }
    if (!modelId || typeof modelId !== "string") {
        throw new https_1.HttpsError("invalid-argument", "modelId is required");
    }
    const provider = providerInput.toLowerCase().trim();
    if (!VALID_PROVIDERS.includes(provider)) {
        throw new https_1.HttpsError("invalid-argument", `Provider must be one of: ${VALID_PROVIDERS.join(", ")}`);
    }
    const cfg = (0, providers_1.getProvider)(provider);
    if (cfg.requiresAccountId) {
        if (!accountId || typeof accountId !== "string" || !accountId.trim()) {
            throw new https_1.HttpsError("invalid-argument", `${cfg.displayName} requires accountId`);
        }
    }
    if (modelId.length < 2 || modelId.length > 128) {
        throw new https_1.HttpsError("invalid-argument", "modelId must be 2-128 characters");
    }
    const { userId } = await (0, authGuard_1.enforceAuth)(request);
    if (useProjectKey && (0, providers_1.canUseProjectKey)(provider)) {
        await (0, saveUserModelConfig_1.saveUserModelConfigWithProjectKey)(userId, provider, modelId.trim());
        firebase_functions_1.logger.info(`User ${userId} updated LLM config (project default): ${cfg.displayName} / ${modelId}`);
        return { success: true, provider, modelId: modelId.trim(), displayName: cfg.displayName };
    }
    if (!apiKey || typeof apiKey !== "string") {
        throw new https_1.HttpsError("invalid-argument", "apiKey is required (or use useProjectKey for groq/gemini)");
    }
    const encKey = config_1.LLM_SETTINGS_ENCRYPTION_KEY.value();
    if (!encKey) {
        firebase_functions_1.logger.error("LLM_SETTINGS_ENCRYPTION_KEY not configured");
        throw new https_1.HttpsError("failed-precondition", "Model configuration is not available. Please contact support.");
    }
    try {
        await (0, saveUserModelConfig_1.saveUserModelConfig)(userId, provider, modelId.trim(), apiKey, encKey, cfg.requiresAccountId ? accountId?.trim() : undefined);
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : "API key validation failed";
        firebase_functions_1.logger.warn(`API key validation failed for user ${userId}: ${msg}`);
        throw new https_1.HttpsError("invalid-argument", `Invalid API key or model. ${msg}`);
    }
    firebase_functions_1.logger.info(`User ${userId} updated LLM config: ${cfg.displayName} / ${modelId}`);
    return {
        success: true,
        provider,
        modelId: modelId.trim(),
        displayName: cfg.displayName,
    };
});
//# sourceMappingURL=updateUserModelConfig.js.map