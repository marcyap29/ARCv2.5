"use strict";
// saveUserModelConfig.ts - Shared logic to validate and save user LLM config
// Used by updateUserModelConfig (callable) and sendChatMessage (in-chat flow)
Object.defineProperty(exports, "__esModule", { value: true });
exports.saveUserModelConfigWithProjectKey = saveUserModelConfigWithProjectKey;
exports.saveUserModelConfig = saveUserModelConfig;
const admin_1 = require("./admin");
const crypto_1 = require("./crypto");
const llmRouter_1 = require("./llmRouter");
const providers_1 = require("./config/providers");
const db = admin_1.admin.firestore();
/**
 * Save config using project's API key (no user key stored).
 * Only for groq and gemini.
 */
async function saveUserModelConfigWithProjectKey(userId, provider, modelId) {
    if (!(0, providers_1.canUseProjectKey)(provider)) {
        throw new Error(`Provider ${provider} does not support project default`);
    }
    const settingsRef = db.collection("users").doc(userId).collection("settings").doc("llm");
    await settingsRef.set({
        provider,
        modelId: modelId.trim(),
        useProjectKey: true,
        updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
    });
}
/**
 * Validate API key and save encrypted config to Firestore.
 * For cloudflare, accountId is required.
 */
async function saveUserModelConfig(userId, provider, modelId, apiKey, encryptionKey, accountId) {
    await (0, llmRouter_1.validateApiKey)(provider, modelId, apiKey, accountId);
    const apiKeyEncrypted = (0, crypto_1.encrypt)(apiKey, encryptionKey);
    const settingsRef = db.collection("users").doc(userId).collection("settings").doc("llm");
    const data = {
        provider,
        modelId: modelId.trim(),
        apiKeyEncrypted,
        updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
    };
    if (accountId)
        data.accountId = accountId.trim();
    await settingsRef.set(data);
}
//# sourceMappingURL=saveUserModelConfig.js.map