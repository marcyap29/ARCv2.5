"use strict";
// userLlmSettings.ts - Load and decrypt per-user LLM settings
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadUserLlmSettings = loadUserLlmSettings;
const admin_1 = require("./admin");
const crypto_1 = require("./crypto");
/**
 * Load user's LLM config from Firestore. Returns null if none set.
 * Decrypts API key using LLM_SETTINGS_ENCRYPTION_KEY.
 */
async function loadUserLlmSettings(userId, encryptionKey) {
    const doc = await admin_1.admin
        .firestore()
        .collection("users")
        .doc(userId)
        .collection("settings")
        .doc("llm")
        .get();
    if (!doc.exists)
        return null;
    const data = doc.data();
    if (!data?.provider || !data?.modelId) {
        return null;
    }
    // useProjectKey: user chose project default (no API key stored)
    if (data.useProjectKey) {
        return {
            provider: data.provider,
            modelId: data.modelId,
            useProjectKey: true,
            accountId: data.accountId,
        };
    }
    if (!data.apiKeyEncrypted)
        return null;
    try {
        const apiKey = (0, crypto_1.decrypt)(data.apiKeyEncrypted, encryptionKey);
        return {
            provider: data.provider,
            modelId: data.modelId,
            apiKey,
            accountId: data.accountId,
        };
    }
    catch {
        return null;
    }
}
//# sourceMappingURL=userLlmSettings.js.map