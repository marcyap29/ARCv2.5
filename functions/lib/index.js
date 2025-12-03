"use strict";
// index.ts - Main entry point for Cloud Functions
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkThrottleStatus = exports.lockThrottle = exports.unlockThrottle = exports.stripeWebhook = exports.sendChatMessage = exports.analyzeJournalEntry = void 0;
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