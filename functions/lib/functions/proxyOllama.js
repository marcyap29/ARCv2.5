"use strict";
// functions/proxyOllama.ts - Proxy for Ollama Cloud API (3rd fallback: Gemini → Groq → Ollama)
// See https://docs.ollama.com/cloud
Object.defineProperty(exports, "__esModule", { value: true });
exports.proxyOllama = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const config_1 = require("../config");
const authGuard_1 = require("../authGuard");
const rateLimiter_1 = require("../rateLimiter");
const OLLAMA_CHAT_URL = "https://ollama.com/api/chat";
// Default: NVIDIA Nemotron 3 Super 120B (Ollama Cloud). See https://ollama.com/library/nemotron-3-super
const DEFAULT_MODEL = "nemotron-3-super:cloud";
/**
 * Proxies chat requests to Ollama Cloud (ollama.com) so the API key never touches the client.
 * Used as the 3rd fallback when Gemini and Groq fail.
 *
 * Set the secret: firebase functions:secrets:set OLLAMA_API_KEY
 * Create an API key at https://ollama.com/settings/keys
 */
exports.proxyOllama = (0, https_1.onCall)({
    secrets: [config_1.OLLAMA_API_KEY],
}, async (request) => {
    const { system, user, temperature, maxTokens, entryId, chatId, localCalendarDate, } = request.data ?? {};
    if (!user || typeof user !== "string") {
        throw new https_1.HttpsError("invalid-argument", "user prompt is required");
    }
    const authResult = await (0, authGuard_1.enforceAuth)(request);
    const { userId, isPremium } = authResult;
    const userEmail = request.auth?.token?.email;
    firebase_functions_1.logger.info(`Proxying Ollama request for user ${userId}`);
    const dailyCheck = await (0, rateLimiter_1.checkUnifiedDailyLimit)(userId, userEmail, localCalendarDate);
    if (!dailyCheck.allowed) {
        throw new https_1.HttpsError("resource-exhausted", dailyCheck.error?.message || "Daily limit reached", dailyCheck.error);
    }
    const rateLimitCheck = await (0, rateLimiter_1.checkRateLimit)(userId, userEmail);
    if (!rateLimitCheck.allowed) {
        throw new https_1.HttpsError("resource-exhausted", rateLimitCheck.error?.message || "Rate limit exceeded", rateLimitCheck.error);
    }
    if (entryId && typeof entryId === "string") {
        await (0, authGuard_1.checkJournalEntryLimit)(userId, entryId, isPremium);
    }
    if (chatId && typeof chatId === "string") {
        await (0, authGuard_1.checkChatLimit)(userId, chatId, isPremium);
    }
    const apiKey = config_1.OLLAMA_API_KEY.value();
    if (!apiKey) {
        throw new https_1.HttpsError("failed-precondition", "Ollama Cloud is not configured. Set OLLAMA_API_KEY secret.");
    }
    const messages = [];
    if (system && typeof system === "string" && system.trim()) {
        messages.push({ role: "system", content: system.trim() });
    }
    messages.push({ role: "user", content: user });
    const body = {
        model: DEFAULT_MODEL,
        messages,
        stream: false,
    };
    if (temperature != null && typeof temperature === "number") {
        body.temperature = temperature;
    }
    if (maxTokens != null && typeof maxTokens === "number") {
        body.options = { num_predict: maxTokens };
    }
    try {
        const res = await fetch(OLLAMA_CHAT_URL, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${apiKey}`,
            },
            body: JSON.stringify(body),
        });
        if (!res.ok) {
            const text = await res.text();
            firebase_functions_1.logger.warn(`Ollama API error ${res.status}: ${text.slice(0, 300)}`);
            if (res.status === 401) {
                throw new https_1.HttpsError("failed-precondition", "Ollama API key invalid or expired.");
            }
            if (res.status === 429) {
                throw new https_1.HttpsError("resource-exhausted", "Ollama rate limit. Try again later.");
            }
            throw new https_1.HttpsError("internal", `Ollama API error: ${res.status}. Try again.`);
        }
        const data = (await res.json());
        const content = data?.message?.content;
        if (content == null) {
            throw new https_1.HttpsError("internal", "Ollama returned no content.");
        }
        firebase_functions_1.logger.info(`Ollama proxy successful for user ${userId}`);
        return { response: String(content).trim() };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        const msg = err instanceof Error ? err.message : String(err);
        firebase_functions_1.logger.error("Ollama proxy error:", msg);
        throw new https_1.HttpsError("internal", `Ollama error: ${msg.slice(0, 100)}`);
    }
});
//# sourceMappingURL=proxyOllama.js.map