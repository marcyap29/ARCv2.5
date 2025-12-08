// functions/proxyGemini.ts - Simple API key proxy for Gemini calls

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { GEMINI_API_KEY } from "../config";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { enforceAuth } from "../authGuard";

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
export const proxyGemini = onCall(
  {
    secrets: [GEMINI_API_KEY],
    // Auth enforced via enforceAuth() - no invoker: "public"
  },
  async (request) => {
    const { system, user, jsonExpected } = request.data;

    if (!user) {
      throw new HttpsError(
        "invalid-argument",
        "user prompt is required"
      );
    }

    // Enforce authentication (supports anonymous trial)
    const authResult = await enforceAuth(request);
    const { userId, isAnonymous, trialRemaining } = authResult;
    
    logger.info(`Proxying Gemini request for user ${userId} (anonymous: ${isAnonymous}, trial remaining: ${trialRemaining ?? 'N/A'})`);

    try {
      const apiKey = GEMINI_API_KEY.value();
      
      if (!apiKey) {
        throw new HttpsError("internal", "Gemini API key not configured");
      }

      const genAI = new GoogleGenerativeAI(apiKey);
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

      logger.info(`Gemini proxy successful for user ${userId}`);

      return { response };
    } catch (error: any) {
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
