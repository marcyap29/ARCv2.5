"use strict";
// functions/proxyGemini.ts - Simple API key proxy for Gemini calls
Object.defineProperty(exports, "__esModule", { value: true });
exports.proxyGemini = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const config_1 = require("../config");
const generative_ai_1 = require("@google/generative-ai");
const authGuard_1 = require("../authGuard");
/**
 * Simple proxy to hide Gemini API key from client
 *
 * This function:
 * 1. Enforces authentication
 * 2. Checks per-entry usage limits for free users (if entryId provided)
 * 3. Checks per-chat usage limits for free users (if chatId provided)
 * 4. Accepts system + user prompts from client
 * 5. Adds the secret API key
 * 6. Forwards to Gemini API
 * 7. Returns the response
 *
 * All LUMARA logic runs on the client (has access to local journals)
 */
exports.proxyGemini = (0, https_1.onCall)({
    secrets: [config_1.GEMINI_API_KEY],
    // Auth enforced via enforceAuth() - no invoker: "public"
}, async (request) => {
    const { system, user, jsonExpected, entryId, chatId } = request.data;
    if (!user) {
        throw new https_1.HttpsError("invalid-argument", "user prompt is required");
    }
    // Enforce authentication
    const authResult = await (0, authGuard_1.enforceAuth)(request);
    const { userId, isAnonymous, isPremium } = authResult;
    firebase_functions_1.logger.info(`Proxying Gemini request for user ${userId} (anonymous: ${isAnonymous}, premium: ${isPremium})`);
    // Check per-entry limit for in-journal LUMARA (if entryId provided)
    if (entryId) {
        const limitResult = await (0, authGuard_1.checkJournalEntryLimit)(userId, entryId, isPremium);
        firebase_functions_1.logger.info(`Journal entry limit check: ${limitResult.remaining} remaining for entry ${entryId}`);
    }
    // Check per-chat limit for in-chat LUMARA (if chatId provided)
    if (chatId) {
        const limitResult = await (0, authGuard_1.checkChatLimit)(userId, chatId, isPremium);
        firebase_functions_1.logger.info(`Chat limit check: ${limitResult.remaining} remaining for chat ${chatId}`);
    }
    try {
        const apiKey = config_1.GEMINI_API_KEY.value();
        if (!apiKey) {
            throw new https_1.HttpsError("internal", "Gemini API key not configured");
        }
        const genAI = new generative_ai_1.GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({
            model: "gemini-3-flash-preview",
            generationConfig: jsonExpected
                ? { responseMimeType: "application/json" }
                : undefined,
        });
        // Create chat with system prompt as initial exchange
        const chat = model.startChat({
            history: system
                ? [
                    { role: "user", parts: [{ text: system }] },
                    { role: "model", parts: [{ text: "Ok." }] },
                ]
                : [],
        });
        const result = await chat.sendMessage(user);
        const response = result.response.text();
        firebase_functions_1.logger.info(`Gemini proxy successful for user ${userId}`);
        return { response };
    }
    catch (error) {
        // Re-throw HttpsErrors (like limit exceeded) as-is
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        const errMsg = error?.message ?? String(error);
        const errStr = typeof error === "object" ? JSON.stringify(error, null, 0).slice(0, 500) : String(error);
        firebase_functions_1.logger.error("Gemini proxy error:", errMsg, errStr);
        if (errMsg.includes("429") || errMsg.includes("quota")) {
            throw new https_1.HttpsError("resource-exhausted", "Rate limit exceeded. Please try again later.");
        }
        // Surface a clearer message; avoid leaking internals
        const userMsg = errMsg && errMsg !== "INTERNAL" && errMsg.length < 200
            ? `Gemini API error: ${errMsg}`
            : "AI service error. Try again or use a shorter message.";
        throw new https_1.HttpsError("internal", userMsg);
    }
});
//# sourceMappingURL=proxyGemini.js.map