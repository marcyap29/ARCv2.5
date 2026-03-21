"use strict";
// functions/proxyGroq.ts - Groq API proxy for LUMARA (primary cloud inference path from Flutter groq_send.dart)
Object.defineProperty(exports, "__esModule", { value: true });
exports.proxyGroq = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const config_1 = require("../config");
const authGuard_1 = require("../authGuard");
const rateLimiter_1 = require("../rateLimiter");
const groqClient_1 = require("../groqClient");
const ALLOWED_MODELS = new Set([
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
    "llama-3.3-70b-versatile",
]);
/**
 * Proxies chat completions to Groq; enforces the same unified daily limit as other LUMARA entry points.
 */
exports.proxyGroq = (0, https_1.onCall)({
    secrets: [config_1.GROQ_API_KEY],
}, async (request) => {
    if (request.data?._ping === true) {
        return { ok: true, ts: Date.now() };
    }
    const { system, user, model = "openai/gpt-oss-120b", temperature = 0.7, maxTokens, entryId, chatId, localCalendarDate, } = request.data ?? {};
    if (user == null || typeof user !== "string") {
        throw new https_1.HttpsError("invalid-argument", "user prompt is required");
    }
    if (!ALLOWED_MODELS.has(model)) {
        throw new https_1.HttpsError("invalid-argument", `Unsupported model. Allowed: ${[...ALLOWED_MODELS].join(", ")}`);
    }
    const authResult = await (0, authGuard_1.enforceAuth)(request);
    const { userId, isPremium } = authResult;
    const userEmail = request.auth?.token?.email;
    firebase_functions_1.logger.info(`Proxying Groq request for user ${userId} (premium: ${isPremium})`);
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
    const apiKey = config_1.GROQ_API_KEY.value();
    if (!apiKey) {
        throw new https_1.HttpsError("internal", "Groq API key not configured");
    }
    try {
        const text = await (0, groqClient_1.groqChatCompletion)(apiKey, {
            system: typeof system === "string" ? system : "",
            user,
            model,
            temperature: typeof temperature === "number" ? temperature : 0.7,
            maxTokens: typeof maxTokens === "number" ? maxTokens : undefined,
        });
        firebase_functions_1.logger.info(`Groq proxy successful for user ${userId}`);
        return { response: text };
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        firebase_functions_1.logger.error("Groq proxy error:", msg);
        if (msg.includes("429")) {
            throw new https_1.HttpsError("resource-exhausted", "Groq rate limit. Try again later.");
        }
        throw new https_1.HttpsError("internal", msg.length > 0 && msg.length < 200 ? msg : "AI service error. Try again.");
    }
});
//# sourceMappingURL=proxyGroq.js.map