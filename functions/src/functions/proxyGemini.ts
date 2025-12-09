// functions/proxyGemini.ts - Simple API key proxy for Gemini calls

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { GEMINI_API_KEY } from "../config";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { enforceAuth, checkJournalEntryLimit } from "../authGuard";

/**
 * Simple proxy to hide Gemini API key from client
 * 
 * This function:
 * 1. Enforces authentication
 * 2. Checks per-entry usage limits for free users (if entryId provided)
 * 3. Accepts system + user prompts from client
 * 4. Adds the secret API key
 * 5. Forwards to Gemini API
 * 6. Returns the response
 * 
 * All LUMARA logic runs on the client (has access to local journals)
 */
export const proxyGemini = onCall(
  {
    secrets: [GEMINI_API_KEY],
    // Auth enforced via enforceAuth() - no invoker: "public"
  },
  async (request) => {
    const { system, user, jsonExpected, entryId } = request.data;

    if (!user) {
      throw new HttpsError(
        "invalid-argument",
        "user prompt is required"
      );
    }

    // Enforce authentication
    const authResult = await enforceAuth(request);
    const { userId, isAnonymous, isPremium } = authResult;
    
    logger.info(`Proxying Gemini request for user ${userId} (anonymous: ${isAnonymous}, premium: ${isPremium})`);

    // Check per-entry limit for in-journal LUMARA (if entryId provided)
    if (entryId) {
      const limitResult = await checkJournalEntryLimit(userId, entryId, isPremium);
      logger.info(`Journal entry limit check: ${limitResult.remaining} remaining for entry ${entryId}`);
    }

    try {
      const apiKey = GEMINI_API_KEY.value();
      
      if (!apiKey) {
        throw new HttpsError("internal", "Gemini API key not configured");
      }

      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: "gemini-2.5-flash",
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

      logger.info(`Gemini proxy successful for user ${userId}`);

      return { response };
    } catch (error: any) {
      // Re-throw HttpsErrors (like limit exceeded) as-is
      if (error instanceof HttpsError) {
        throw error;
      }
      
      logger.error(`Gemini proxy error:`, error);
      
      if (error.message?.includes("429") || error.message?.includes("quota")) {
        throw new HttpsError(
          "resource-exhausted",
          "Rate limit exceeded. Please try again later."
        );
      }
      
      throw new HttpsError(
        "internal",
        `Gemini API error: ${error.message || "Unknown error"}`
      );
    }
  }
);
