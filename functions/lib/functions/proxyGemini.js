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
 * This function just:
 * 1. Enforces authentication (with anonymous trial support)
 * 2. Accepts system + user prompts from client
 * 3. Adds the secret API key
 * 4. Forwards to Gemini API
 * 5. Returns the response
 *
 * All LUMARA logic runs on the client (has access to local journals)
 */
exports.proxyGemini = (0, https_1.onCall)({
    secrets: [config_1.GEMINI_API_KEY],
    // Auth enforced via enforceAuth() - no invoker: "public"
}, async (request) => {
    const { system, user, jsonExpected } = request.data;
    if (!user) {
        throw new https_1.HttpsError("invalid-argument", "user prompt is required");
    }
    // Enforce authentication (supports anonymous trial)
    const authResult = await (0, authGuard_1.enforceAuth)(request);
    const { userId, isAnonymous, trialRemaining } = authResult;
    firebase_functions_1.logger.info(`Proxying Gemini request for user ${userId} (anonymous: ${isAnonymous}, trial remaining: ${trialRemaining ?? 'N/A'})`);
    try {
        const apiKey = config_1.GEMINI_API_KEY.value();
        if (!apiKey) {
            throw new https_1.HttpsError("internal", "Gemini API key not configured");
        }
        const genAI = new generative_ai_1.GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({
            model: "gemini-2.5-flash",
            // Note: googleSearch tool removed due to SDK type issues
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
        firebase_functions_1.logger.error(`Gemini proxy error:`, error);
        if (error.message?.includes("429") || error.message?.includes("quota")) {
            throw new https_1.HttpsError("resource-exhausted", "Rate limit exceeded. Please try again later.");
        }
        throw new https_1.HttpsError("internal", `Gemini API error: ${error.message || "Unknown error"}`);
    }
});
//# sourceMappingURL=proxyGemini.js.map