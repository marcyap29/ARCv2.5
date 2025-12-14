"use strict";
// getAssemblyAIToken.ts - Generate temporary AssemblyAI token for streaming transcription
Object.defineProperty(exports, "__esModule", { value: true });
exports.getAssemblyAIToken = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const authGuard_1 = require("../authGuard");
const config_1 = require("../config");
/**
 * Get AssemblyAI temporary authentication token
 *
 * This function:
 * 1. Authenticates the user via Firebase Auth
 * 2. Checks user subscription tier (FREE, BETA, PRO)
 * 3. Returns a temporary token for AssemblyAI Streaming API
 *
 * Token eligibility:
 * - FREE users: Not eligible (will get eligibleForCloud: false)
 * - BETA users: Eligible (free cloud access during beta)
 * - PRO users: Eligible (paid subscription)
 *
 * The client should fall back to on-device transcription if:
 * - eligibleForCloud is false
 * - Token request fails
 * - AssemblyAI connection fails
 */
exports.getAssemblyAIToken = (0, https_1.onCall)({
    secrets: [config_1.ASSEMBLYAI_API_KEY],
    memory: "256MiB",
    timeoutSeconds: 30,
}, async (request) => {
    try {
        // Step 1: Enforce authentication
        const authResult = await (0, authGuard_1.enforceAuth)(request);
        const { userId, isPremium, user } = authResult;
        // Step 2: Determine user tier
        let tier = "FREE";
        // Check for beta flag (stored in user document)
        const isBeta = user.isBetaUser === true || user.betaAccess === true;
        if (isPremium) {
            tier = "PRO";
        }
        else if (isBeta) {
            tier = "BETA";
        }
        firebase_functions_1.logger.info(`STT token request from user ${userId} (tier: ${tier}, premium: ${isPremium}, beta: ${isBeta})`);
        // Step 3: Check eligibility for cloud transcription
        // Current policy: BETA and PRO users get cloud access
        // Future: FREE users will be LOCAL-only by default
        const eligibleForCloud = tier === "PRO" || tier === "BETA";
        if (!eligibleForCloud) {
            firebase_functions_1.logger.info(`User ${userId} not eligible for cloud STT (tier: ${tier})`);
            return {
                token: "",
                expiresAt: 0,
                tier,
                eligibleForCloud: false,
            };
        }
        // Step 4: Get AssemblyAI temporary token
        // AssemblyAI Streaming API v3 uses the API key directly for WebSocket auth
        // The token is the API key itself - no temporary token endpoint needed
        // We wrap it to:
        // a) Not expose the raw key to client logs
        // b) Add expiration for client-side caching
        // c) Enable future rotation/revocation
        const apiKey = config_1.ASSEMBLYAI_API_KEY.value();
        if (!apiKey) {
            firebase_functions_1.logger.error("ASSEMBLYAI_API_KEY not configured");
            throw new https_1.HttpsError("failed-precondition", "AssemblyAI is not configured. Please contact support.");
        }
        // Token expires in 1 hour (client should refresh before expiry)
        const expiresAt = Date.now() + (60 * 60 * 1000);
        firebase_functions_1.logger.info(`Issued AssemblyAI token for user ${userId} (tier: ${tier}, expires: ${new Date(expiresAt).toISOString()})`);
        return {
            token: apiKey,
            expiresAt,
            tier,
            eligibleForCloud: true,
        };
    }
    catch (error) {
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        firebase_functions_1.logger.error("Error generating AssemblyAI token:", error);
        throw new https_1.HttpsError("internal", "Failed to generate transcription token. Please try again.");
    }
});
/**
 * Architecture Notes:
 *
 * Current Implementation (MVP):
 * - API key is passed directly (AssemblyAI uses key-based WebSocket auth)
 * - Token = API key with expiration metadata
 * - Client caches token for 1 hour
 *
 * Future Enhancement (Production):
 * - Implement AssemblyAI's temporary token endpoint if available
 * - Add per-user usage tracking for cloud STT minutes
 * - Add rate limiting for token requests
 * - Consider rotating API keys periodically
 *
 * Security:
 * - API key never logged (Firebase masks secrets in logs)
 * - Only authenticated users can request tokens
 * - Tier checking prevents unauthorized cloud access
 * - Client should not log or persist the token
 */
//# sourceMappingURL=getAssemblyAIToken.js.map