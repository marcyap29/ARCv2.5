"use strict";
// config.ts - Environment configuration and model settings
Object.defineProperty(exports, "__esModule", { value: true });
exports.GEMINI_BASE_URL = exports.FREE_MAX_CHAT_TURNS_PER_THREAD = exports.FREE_MAX_ANALYSES_PER_ENTRY = exports.FREE_MAX_REQUESTS_PER_MINUTE = exports.FREE_MAX_REQUESTS_PER_DAY = exports.GEMINI_PRO_MODEL_ID = exports.GEMINI_FLASH_MODEL_ID = exports.THROTTLE_UNLOCK_PASSWORD = exports.ASSEMBLYAI_API_KEY = exports.GEMINI_API_KEY = void 0;
exports.getModelConfig = getModelConfig;
const params_1 = require("firebase-functions/params");
/**
 * Environment variables and secrets
 * These are set via Firebase Functions config or secrets
 */
exports.GEMINI_API_KEY = (0, params_1.defineSecret)("GEMINI_API_KEY");
// AssemblyAI API key for cloud transcription
exports.ASSEMBLYAI_API_KEY = (0, params_1.defineSecret)("ASSEMBLYAI_API_KEY");
// Throttle unlock password (stored as secret for security)
exports.THROTTLE_UNLOCK_PASSWORD = (0, params_1.defineSecret)("THROTTLE_UNLOCK_PASSWORD");
// Model IDs - easily swappable for Gemini 3.0 or newer models
// Hardcoded for MVP - TODO: Move to secrets after testing
exports.GEMINI_FLASH_MODEL_ID = {
    value: () => "gemini-2.5-flash"
};
exports.GEMINI_PRO_MODEL_ID = {
    value: () => "gemini-2.5"
};
// Rate limiting configuration - Hardcoded for MVP
exports.FREE_MAX_REQUESTS_PER_DAY = {
    value: () => "50"
};
exports.FREE_MAX_REQUESTS_PER_MINUTE = {
    value: () => "10"
};
// Legacy quota limits (kept for backward compatibility, but rate limiting takes precedence)
exports.FREE_MAX_ANALYSES_PER_ENTRY = {
    value: () => "4"
};
exports.FREE_MAX_CHAT_TURNS_PER_THREAD = {
    value: () => "200"
};
/**
 * API Base URLs
 */
exports.GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta";
/**
 * Model configuration factory
 * Returns ModelConfig based on model family
 */
function getModelConfig(family) {
    switch (family) {
        case "GEMINI_FLASH":
            return {
                family: "GEMINI_FLASH",
                modelId: exports.GEMINI_FLASH_MODEL_ID.value(),
                apiKey: exports.GEMINI_API_KEY.value(),
                baseUrl: exports.GEMINI_BASE_URL,
                maxTokens: 8192,
                temperature: 0.7,
            };
        case "GEMINI_PRO":
            return {
                family: "GEMINI_PRO",
                modelId: exports.GEMINI_PRO_MODEL_ID.value(),
                apiKey: exports.GEMINI_API_KEY.value(),
                baseUrl: exports.GEMINI_BASE_URL,
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
//# sourceMappingURL=config.js.map