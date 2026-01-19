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
import { generateJournalReflection } from "./functions/generateJournalReflection";
import { getUserSubscription } from "./functions/getUserSubscription";
import { createCheckoutSession } from "./functions/createCheckoutSession";
import { proxyGemini } from "./functions/proxyGemini";
import { getAssemblyAIToken } from "./functions/getAssemblyAIToken";
import { getWisprApiKey } from "./functions/getWisprApiKey";

// Export all Cloud Functions
export { analyzeJournalEntry };
export { sendChatMessage };
export { stripeWebhook };
export { unlockThrottle, lockThrottle, checkThrottleStatus };
export { generateJournalPrompts };
export { generateJournalReflection };
export { getUserSubscription };
export { createCheckoutSession };
export { proxyGemini };
export { getAssemblyAIToken };
export { getWisprApiKey };

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

