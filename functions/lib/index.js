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
const proxyGemini_1 = require("./functions/proxyGemini");
Object.defineProperty(exports, "proxyGemini", { enumerable: true, get: function () { return proxyGemini_1.proxyGemini; } });
/**
 * Architecture Overview (Priority 3: Authentication & Security):
 *
 * Client (Flutter)
 *   ↓ HTTPS + Firebase Auth Token (REQUIRED)
 * Firebase Cloud Function (onCall)
 *   ↓ enforceAuth() - Verify Token + Anonymous Trial Check
 * Auth Guard
 *   ↓ If anonymous: Check trial limit (5 requests)
 *   ↓ If trial expired: Throw ANONYMOUS_TRIAL_EXPIRED
 * Load User from Firestore
 *   ↓ Check Subscription Tier
 * Rate Limiter (checkRateLimit)
 *   ↓ FREE: 20/day, 3/minute | PAID: Unlimited
 * Quota Guard (checkCanAnalyzeEntry / checkCanSendMessage)
 *   ↓ Enforce Limits
 * Model Router (selectModel)
 *   ↓ Choose Model (Gemini Flash/Pro)
 * LLM Client (GeminiClient)
 *   ↓ Call API
 * Gemini API
 *   ↓ Response
 * Parse & Structure Response
 *   ↓ Update Firestore (increment counters)
 * Return to Client
 *
 * Security Features (Priority 3):
 * - No more `invoker: "public"` - all functions require auth
 * - Anonymous users get 5 free requests before sign-in required
 * - Anonymous → Real account linking preserves user data
 * - Per-user rate limiting tied to real identity
 * - Firestore rules enforce data isolation
 */
//# sourceMappingURL=index.js.map