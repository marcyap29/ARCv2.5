// config.ts - Environment configuration and model settings

import { defineSecret } from "firebase-functions/params";
import { ModelFamily, ModelConfig } from "./types";

/**
 * Environment variables and secrets
 * These are set via Firebase Functions config or secrets
 */
export const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
export const GROQ_API_KEY = defineSecret("GROQ_API_KEY");

// AssemblyAI API key for cloud transcription
export const ASSEMBLYAI_API_KEY = defineSecret("ASSEMBLYAI_API_KEY");

// Throttle unlock password (stored as secret for security)
export const THROTTLE_UNLOCK_PASSWORD = defineSecret("THROTTLE_UNLOCK_PASSWORD");

// Encryption key for per-user LLM API keys (32-byte hex string)
// Set via: firebase functions:secrets:set LLM_SETTINGS_ENCRYPTION_KEY
export const LLM_SETTINGS_ENCRYPTION_KEY = defineSecret("LLM_SETTINGS_ENCRYPTION_KEY");

// Model IDs - easily swappable for Gemini 3.0 or newer models
// Hardcoded for MVP - TODO: Move to secrets after testing
export const GEMINI_FLASH_MODEL_ID = {
  value: () => "gemini-3-flash-preview"
};

export const GEMINI_PRO_MODEL_ID = {
  value: () => "gemini-3-flash-preview"
};

// Rate limiting configuration - Hardcoded for MVP
export const FREE_MAX_REQUESTS_PER_DAY = {
  value: () => "50"
};

export const FREE_MAX_REQUESTS_PER_MINUTE = {
  value: () => "10"
};

// Legacy quota limits (kept for backward compatibility, but rate limiting takes precedence)
export const FREE_MAX_ANALYSES_PER_ENTRY = {
  value: () => "4"
};

export const FREE_MAX_CHAT_TURNS_PER_THREAD = {
  value: () => "200"
};

/**
 * API Base URLs
 */
export const GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta";

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
 * - Gemini 1.5/2.0/2.5 (deprecated) → Gemini 3 Flash (current)
 * - Defaults: gemini-3-flash-preview (free and paid tiers)
 *
 * Tier Difference:
 * - FREE tier: Uses gemini-3-flash-preview with backend-enforced quotas
 * - PAID tier: Uses gemini-3-flash-preview with unlimited access
 */
