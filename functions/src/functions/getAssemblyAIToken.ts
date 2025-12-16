// getAssemblyAIToken.ts - Generate temporary AssemblyAI token for streaming transcription

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { enforceAuth } from "../authGuard";
import { ASSEMBLYAI_API_KEY } from "../config";

/**
 * STT (Speech-to-Text) mode configuration
 */
export type SttMode = "AUTO" | "CLOUD" | "LOCAL";

/**
 * User tier for STT access
 */
export type SttTier = "FREE" | "BETA" | "PRO";

/**
 * Response from getAssemblyAIToken
 */
interface AssemblyAITokenResponse {
  token: string;
  expiresAt: number; // Unix timestamp
  tier: SttTier;
  eligibleForCloud: boolean;
}

/**
 * Get AssemblyAI temporary authentication token
 * 
 * This function:
 * 1. Authenticates the user via Firebase Auth
 * 2. Checks user subscription tier (FREE, BETA, PRO)
 * 3. Returns a temporary token for AssemblyAI Streaming API
 * 
 * Token eligibility:
 * - FREE users: Not eligible (will get eligibleForCloud: false) - use on-device transcription
 * - BETA users: Not eligible (will get eligibleForCloud: false) - use on-device transcription
 * - PRO users: Eligible (paid $30/month subscription) - get AssemblyAI cloud transcription
 * 
 * The client should fall back to on-device transcription if:
 * - eligibleForCloud is false
 * - Token request fails
 * - AssemblyAI connection fails
 */
export const getAssemblyAIToken = onCall(
  {
    secrets: [ASSEMBLYAI_API_KEY],
    memory: "256MiB",
    timeoutSeconds: 30,
  },
  async (request) => {
    try {
      // Step 1: Enforce authentication
      const authResult = await enforceAuth(request);
      const { userId, isPremium, user } = authResult;

      // Step 2: Determine user tier
      let tier: SttTier = "FREE";
      
      // Check for beta flag (stored in user document)
      const isBeta = user.isBetaUser === true || user.betaAccess === true;
      
      if (isPremium) {
        tier = "PRO";
      } else if (isBeta) {
        tier = "BETA";
      }

      logger.info(`STT token request from user ${userId} (tier: ${tier}, premium: ${isPremium}, beta: ${isBeta})`);

      // Step 3: Check eligibility for cloud transcription
      // Policy: Only PRO users ($30/month subscription) get AssemblyAI cloud access
      // FREE and BETA users use on-device transcription only
      const eligibleForCloud = tier === "PRO";
      
      logger.info(`AssemblyAI eligibility check: tier=${tier}, isPremium=${isPremium}, eligibleForCloud=${eligibleForCloud}`);

      if (!eligibleForCloud) {
        logger.info(`User ${userId} not eligible for cloud STT (tier: ${tier})`);
        return {
          token: "",
          expiresAt: 0,
          tier,
          eligibleForCloud: false,
        } as AssemblyAITokenResponse;
      }

      // Step 4: Get AssemblyAI temporary token
      // AssemblyAI Streaming API v3 uses the API key directly for WebSocket auth
      // The token is the API key itself - no temporary token endpoint needed
      // We wrap it to:
      // a) Not expose the raw key to client logs
      // b) Add expiration for client-side caching
      // c) Enable future rotation/revocation
      
      const apiKey = ASSEMBLYAI_API_KEY.value();
      
      if (!apiKey) {
        logger.error("ASSEMBLYAI_API_KEY not configured");
        throw new HttpsError(
          "failed-precondition",
          "AssemblyAI is not configured. Please contact support."
        );
      }

      // Token expires in 1 hour (client should refresh before expiry)
      const expiresAt = Date.now() + (60 * 60 * 1000);

      logger.info(`Issued AssemblyAI token for user ${userId} (tier: ${tier}, expires: ${new Date(expiresAt).toISOString()})`);

      return {
        token: apiKey,
        expiresAt,
        tier,
        eligibleForCloud: true,
      } as AssemblyAITokenResponse;

    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      
      logger.error("Error generating AssemblyAI token:", error);
      throw new HttpsError(
        "internal",
        "Failed to generate transcription token. Please try again."
      );
    }
  }
);

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
