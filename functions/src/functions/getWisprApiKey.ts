// getWisprApiKey.ts - Securely serve Wispr Flow API key to authenticated clients

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";

// Define secret (must be set via: firebase functions:secrets:set WISPR_FLOW_API_KEY)
const wisprApiKey = defineSecret("WISPR_FLOW_API_KEY");

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
export const getWisprApiKey = onCall(
  { 
    secrets: [wisprApiKey],
    region: 'us-central1',
  },
  async (request) => {
    // Verify user is authenticated (same pattern as getUserSubscription)
    if (!request.auth?.uid) {
      logger.warn("getWisprApiKey: Unauthenticated request");
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const userId = request.auth.uid;
    logger.info(`getWisprApiKey: Request from user ${userId}`);

    // Get API key from secret
    const apiKeyValue = wisprApiKey.value();

    if (!apiKeyValue || apiKeyValue.trim() === "") {
      logger.error("WISPR_FLOW_API_KEY secret is not set");
      throw new HttpsError(
        "failed-precondition",
        "Voice service is not configured. Please contact support."
      );
    }

    logger.info(`Wispr API key retrieved for user: ${userId}`);

    return {
      apiKey: apiKeyValue,
    };
  }
);
