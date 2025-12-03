// index.ts - Main entry point for Cloud Functions

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

import { analyzeJournalEntry } from "./functions/analyzeJournalEntry";
import { sendChatMessage } from "./functions/sendChatMessage";
import { stripeWebhook } from "./functions/stripeWebhook";
import { unlockThrottle, lockThrottle, checkThrottleStatus } from "./functions/unlockThrottle";
import { generateJournalPrompts } from "./functions/generateJournalPrompts";

// Export all Cloud Functions
export { analyzeJournalEntry };
export { sendChatMessage };
export { stripeWebhook };
export { unlockThrottle, lockThrottle, checkThrottleStatus };
export { generateJournalPrompts };

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

