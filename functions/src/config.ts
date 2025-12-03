// config.ts - Environment configuration and model settings

import { defineString, defineSecret } from "firebase-functions/params";

/**
 * Environment variables and secrets
 * These are set via Firebase Functions config or secrets
 */
export const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
export const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

// Model IDs - easily swappable for Gemini 3.0 or newer models
export const GEMINI_FLASH_MODEL_ID = defineString("GEMINI_FLASH_MODEL_ID", {
  default: "gemini-2.5-flash", // Updated to Gemini 2.5 Flash (1.5 and 2.0 are deprecated) - Free tier with backend-enforced quotas
  description: "Gemini Flash model ID (free tier - backend limits usage)",
});

export const GEMINI_PRO_MODEL_ID = defineString("GEMINI_PRO_MODEL_ID", {
  default: "gemini-2.5", // Updated to Gemini 2.5 (1.5 is deprecated) - Same model as Flash, backend enforces free tier limits
  description: "Gemini 2.5 model ID (paid tier - unlimited access to same model)",
});

export const CLAUDE_HAIKU_MODEL_ID = defineString("CLAUDE_HAIKU_MODEL_ID", {
  default: "claude-3-haiku-20240307",
  description: "Claude Haiku model ID (paid tier, fast operations)",
});

export const CLAUDE_SONNET_MODEL_ID = defineString("CLAUDE_SONNET_MODEL_ID", {
  default: "claude-3-5-sonnet-20241022",
  description: "Claude Sonnet model ID (paid tier, deep reflection)",
});

// Quota limits
export const FREE_MAX_ANALYSES_PER_ENTRY = defineString("FREE_MAX_ANALYSES_PER_ENTRY", {
  default: "4",
  description: "Maximum deep analyses per journal entry for free tier",
});

export const FREE_MAX_CHAT_TURNS_PER_THREAD = defineString("FREE_MAX_CHAT_TURNS_PER_THREAD", {
  default: "200",
  description: "Maximum chat turns per thread for free tier",
});

/**
 * API Base URLs
 */
export const GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta";
export const ANTHROPIC_BASE_URL = "https://api.anthropic.com/v1";

/**
 * Model configuration factory
 * Returns ModelConfig based on model family
 */
export function getModelConfig(family: ModelFamily): ModelConfig {
  switch (family) {
    case "GEMINI_FLASH":
      return {
        family: "GEMINI_FLASH",
        modelId: GEMINI_FLASH_MODEL_ID.value(),
        apiKey: GEMINI_API_KEY.value(),
        baseUrl: GEMINI_BASE_URL,
        maxTokens: 8192,
        temperature: 0.7,
      };
    case "GEMINI_PRO":
      return {
        family: "GEMINI_PRO",
        modelId: GEMINI_PRO_MODEL_ID.value(),
        apiKey: GEMINI_API_KEY.value(),
        baseUrl: GEMINI_BASE_URL,
        maxTokens: 8192,
        temperature: 0.7,
      };
    case "CLAUDE_HAIKU":
      return {
        family: "CLAUDE_HAIKU",
        modelId: CLAUDE_HAIKU_MODEL_ID.value(),
        apiKey: ANTHROPIC_API_KEY.value(),
        baseUrl: ANTHROPIC_BASE_URL,
        maxTokens: 4096,
        temperature: 0.7,
      };
    case "CLAUDE_SONNET":
      return {
        family: "CLAUDE_SONNET",
        modelId: CLAUDE_SONNET_MODEL_ID.value(),
        apiKey: ANTHROPIC_API_KEY.value(),
        baseUrl: ANTHROPIC_BASE_URL,
        maxTokens: 8192,
        temperature: 0.8,
      };
    case "LOCAL_EIS":
      // Future: Local EIS-O1/EIS-E1 model
      // This would connect to a local inference server
      return {
        family: "LOCAL_EIS",
        modelId: "eis-o1-preview", // Placeholder
        apiKey: "", // Not needed for local
        baseUrl: "http://localhost:8080", // Local inference server
        maxTokens: 8192,
        temperature: 0.7,
      };
    default:
      throw new Error(`Unknown model family: ${family}`);
  }
}

/**
 * Model Version History:
 * - Gemini 1.5 (deprecated) → Gemini 2.0 (deprecated) → Gemini 2.5 (current as of Dec 2024)
 * - Updated defaults: gemini-2.5-flash (free tier), gemini-2.5 (paid tier)
 * 
 * Tier Difference:
 * - FREE tier: Uses gemini-2.5-flash with backend-enforced quotas (4 analyses/entry, 200 messages/thread)
 * - PAID tier: Uses gemini-2.5 with unlimited access (backend removes all quotas)
 * - Both tiers use the same underlying Gemini 2.5 model - difference is backend quota enforcement
 * 
 * Migration notes for Gemini 3.0:
 * 
 * To upgrade to Gemini 3.0:
 * 1. Update GEMINI_FLASH_MODEL_ID to "gemini-3.0-flash" (or equivalent)
 * 2. Update GEMINI_PRO_MODEL_ID to "gemini-3.0" (or equivalent)
 * 3. No code changes needed - the model router uses these config values
 * 4. Test API compatibility (response format should remain the same)
 * 
 * Example:
 * firebase functions:config:set gemini.flash_model_id="gemini-3.0-flash"
 * firebase functions:config:set gemini.pro_model_id="gemini-3.0"
 */

