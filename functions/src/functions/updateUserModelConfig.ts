// updateUserModelConfig.ts - Save per-user LLM provider, model, and API key
//
// Callable from Settings UI or in-chat flow. Validates API key before storing.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { enforceAuth } from "../authGuard";
import { LLM_SETTINGS_ENCRYPTION_KEY } from "../config";
import { saveUserModelConfig, saveUserModelConfigWithProjectKey } from "../saveUserModelConfig";
import { getProvider, canUseProjectKey, type ProviderId } from "../config/providers";

/** Valid provider IDs */
const VALID_PROVIDERS: ProviderId[] = ["groq", "openai", "anthropic", "gemini", "cloudflare", "swarmspace"];

/**
 * Update user's LLM configuration (provider, model, API key).
 * For groq/gemini, useProjectKey: true uses project's key (no apiKey needed).
 * For cloudflare, accountId is required.
 *
 * Request: { provider: string, modelId: string, apiKey?: string, accountId?: string, useProjectKey?: boolean }
 * Response: { success: true, provider, modelId }
 */
export const updateUserModelConfig = onCall(
  {
    secrets: [LLM_SETTINGS_ENCRYPTION_KEY],
  },
  async (request) => {
    const { provider: providerInput, modelId, apiKey, accountId, useProjectKey } = request.data ?? {};

    if (!providerInput || typeof providerInput !== "string") {
      throw new HttpsError("invalid-argument", "provider is required");
    }
    if (!modelId || typeof modelId !== "string") {
      throw new HttpsError("invalid-argument", "modelId is required");
    }

    const provider = providerInput.toLowerCase().trim() as ProviderId;
    if (!VALID_PROVIDERS.includes(provider)) {
      throw new HttpsError(
        "invalid-argument",
        `Provider must be one of: ${VALID_PROVIDERS.join(", ")}`
      );
    }

    const cfg = getProvider(provider);
    if (cfg.requiresAccountId) {
      if (!accountId || typeof accountId !== "string" || !accountId.trim()) {
        throw new HttpsError("invalid-argument", `${cfg.displayName} requires accountId`);
      }
    }

    if (modelId.length < 2 || modelId.length > 128) {
      throw new HttpsError("invalid-argument", "modelId must be 2-128 characters");
    }

    const { userId } = await enforceAuth(request);

    if (useProjectKey && canUseProjectKey(provider)) {
      await saveUserModelConfigWithProjectKey(userId, provider, modelId.trim());
      logger.info(`User ${userId} updated LLM config (project default): ${cfg.displayName} / ${modelId}`);
      return { success: true, provider, modelId: modelId.trim(), displayName: cfg.displayName };
    }

    if (!apiKey || typeof apiKey !== "string") {
      throw new HttpsError("invalid-argument", "apiKey is required (or use useProjectKey for groq/gemini)");
    }

    const encKey = LLM_SETTINGS_ENCRYPTION_KEY.value();
    if (!encKey) {
      logger.error("LLM_SETTINGS_ENCRYPTION_KEY not configured");
      throw new HttpsError(
        "failed-precondition",
        "Model configuration is not available. Please contact support."
      );
    }

    try {
      await saveUserModelConfig(userId, provider, modelId.trim(), apiKey, encKey, cfg.requiresAccountId ? accountId?.trim() : undefined);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "API key validation failed";
      logger.warn(`API key validation failed for user ${userId}: ${msg}`);
      throw new HttpsError("invalid-argument", `Invalid API key or model. ${msg}`);
    }

    logger.info(`User ${userId} updated LLM config: ${cfg.displayName} / ${modelId}`);

    return {
      success: true,
      provider,
      modelId: modelId.trim(),
      displayName: cfg.displayName,
    };
  }
);
