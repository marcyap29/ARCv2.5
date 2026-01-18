"use strict";
// getWisprApiKey.ts - Securely serve Wispr Flow API key to authenticated clients
Object.defineProperty(exports, "__esModule", { value: true });
exports.getWisprApiKey = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const firebase_functions_1 = require("firebase-functions");
// Define secret (must be set via: firebase functions:secrets:set WISPR_FLOW_API_KEY)
const wisprApiKey = (0, params_1.defineSecret)("WISPR_FLOW_API_KEY");
/**
 * Get Wispr Flow API Key
 *
 * Returns the Wispr API key to authenticated clients for voice transcription.
 *
 * Security:
 * - Requires Firebase authentication
 * - API key stored as Firebase Functions secret
 * - Never logged or exposed in error messages
 *
 * @returns {Object} { apiKey: string }
 */
exports.getWisprApiKey = (0, https_1.onCall)({ secrets: [wisprApiKey] }, async (request) => {
    // Verify user is authenticated (same pattern as getUserSubscription)
    if (!request.auth?.uid) {
        firebase_functions_1.logger.warn("getWisprApiKey: Unauthenticated request");
        throw new https_1.HttpsError("unauthenticated", "User must be authenticated");
    }
    const userId = request.auth.uid;
    firebase_functions_1.logger.info(`getWisprApiKey: Request from user ${userId}`);
    // Get API key from secret
    const apiKeyValue = wisprApiKey.value();
    if (!apiKeyValue || apiKeyValue.trim() === "") {
        firebase_functions_1.logger.error("WISPR_FLOW_API_KEY secret is not set");
        throw new https_1.HttpsError("failed-precondition", "Voice service is not configured. Please contact support.");
    }
    firebase_functions_1.logger.info(`Wispr API key retrieved for user: ${userId}`);
    return {
        apiKey: apiKeyValue,
    };
});
//# sourceMappingURL=getWisprApiKey.js.map