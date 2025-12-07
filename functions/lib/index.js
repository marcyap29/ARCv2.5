"use strict";
// index.ts - Main entry point for Cloud Functions
Object.defineProperty(exports, "__esModule", { value: true });
exports.proxyGemini = exports.createCheckoutSession = exports.getUserSubscription = exports.generateJournalReflection = exports.generateJournalPrompts = exports.checkThrottleStatus = exports.lockThrottle = exports.unlockThrottle = exports.stripeWebhook = exports.sendChatMessage = exports.analyzeJournalEntry = void 0;
/**
 * Firebase Cloud Functions - ARC Backend
 *
 * Refactored from Venice AI to Gemini + Claude architecture
 *
 * Functions:
 * - analyzeJournalEntry: Deep analysis of journal entries
 * - sendChatMessage: Chat with LUMARA AI companion
 * - stripeWebhook: Handle Stripe subscription events
 */
const analyzeJournalEntry_1 = require("./functions/analyzeJournalEntry");
Object.defineProperty(exports, "analyzeJournalEntry", { enumerable: true, get: function () { return analyzeJournalEntry_1.analyzeJournalEntry; } });
const sendChatMessage_1 = require("./functions/sendChatMessage");
Object.defineProperty(exports, "sendChatMessage", { enumerable: true, get: function () { return sendChatMessage_1.sendChatMessage; } });
const stripeWebhook_1 = require("./functions/stripeWebhook");
Object.defineProperty(exports, "stripeWebhook", { enumerable: true, get: function () { return stripeWebhook_1.stripeWebhook; } });
const unlockThrottle_1 = require("./functions/unlockThrottle");
Object.defineProperty(exports, "unlockThrottle", { enumerable: true, get: function () { return unlockThrottle_1.unlockThrottle; } });
Object.defineProperty(exports, "lockThrottle", { enumerable: true, get: function () { return unlockThrottle_1.lockThrottle; } });
Object.defineProperty(exports, "checkThrottleStatus", { enumerable: true, get: function () { return unlockThrottle_1.checkThrottleStatus; } });
const generateJournalPrompts_1 = require("./functions/generateJournalPrompts");
Object.defineProperty(exports, "generateJournalPrompts", { enumerable: true, get: function () { return generateJournalPrompts_1.generateJournalPrompts; } });
const generateJournalReflection_1 = require("./functions/generateJournalReflection");
Object.defineProperty(exports, "generateJournalReflection", { enumerable: true, get: function () { return generateJournalReflection_1.generateJournalReflection; } });
const getUserSubscription_1 = require("./functions/getUserSubscription");
Object.defineProperty(exports, "getUserSubscription", { enumerable: true, get: function () { return getUserSubscription_1.getUserSubscription; } });
const createCheckoutSession_1 = require("./functions/createCheckoutSession");
Object.defineProperty(exports, "createCheckoutSession", { enumerable: true, get: function () { return createCheckoutSession_1.createCheckoutSession; } });

// proxyGemini - Pure JavaScript implementation (no TypeScript compilation needed)
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { defineSecret } = require("firebase-functions/params");
const { GoogleGenerativeAI } = require("@google/generative-ai");

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

exports.proxyGemini = onCall(
  { secrets: [GEMINI_API_KEY], invoker: "public" },
  async (request) => {
    const { system, user, jsonExpected, systemInstruction, contents } = request.data || {};

    // Accept both legacy shape (system/user) and new shape (systemInstruction/contents)
    let userPrompt = user;
    if (!userPrompt && Array.isArray(contents) && contents.length > 0) {
      const parts = contents[0]?.parts;
      if (Array.isArray(parts) && parts.length > 0) {
        const text = parts[0]?.text;
        if (typeof text === "string") userPrompt = text;
      }
    }

    const systemPrompt = systemInstruction || system || "";

    if (!userPrompt) {
      throw new HttpsError("invalid-argument", "user prompt is required");
    }

    const userId = request.auth?.uid || `mvp_test_${Date.now()}`;
    logger.info(`Proxying Gemini request for user ${userId}`);
    try {
      const apiKey = GEMINI_API_KEY.value();
      if (!apiKey) {
        throw new HttpsError("internal", "Gemini API key not configured");
      }

      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: "gemini-2.5-flash",
        tools: [{ googleSearch: {} }],
        generationConfig: jsonExpected ? { responseMimeType: "application/json" } : undefined,
      });

      const history = systemPrompt
        ? [{ role: "user", parts: [{ text: systemPrompt }] }, { role: "model", parts: [{ text: "Ok." }] }]
        : [];

      const chat = model.startChat({ history });
      const result = await chat.sendMessage(userPrompt);

      // Return a simple string to match client fallback parsing
      const response = result.response.text();
      logger.info(`Gemini proxy successful for user ${userId}`);
      return { response };
    } catch (error) {
      logger.error(`Gemini proxy error:`, error);
      throw new HttpsError("internal", `Gemini API error: ${error.message || "Unknown error"}`);
    }
  }
);

/**
 * Architecture Overview:
 *
 * Client (Flutter)
 *   ↓ HTTPS + Firebase Auth Token
 * Firebase Cloud Function (onCall)
 *   ↓ Verify Auth Token
 * Load User from Firestore
 *   ↓ Check Subscription Tier
 * Quota Guard (checkCanAnalyzeEntry / checkCanSendMessage)
 *   ↓ Enforce Limits
 * Model Router (selectModel)
 *   ↓ Choose Model (Gemini Flash/Pro or Claude)
 * LLM Client (GeminiClient / ClaudeClient)
 *   ↓ Call API
 * Gemini/Claude API
 *   ↓ Response
 * Parse & Structure Response
 *   ↓ Update Firestore (increment counters)
 * Return to Client
 */
//# sourceMappingURL=index.js.map