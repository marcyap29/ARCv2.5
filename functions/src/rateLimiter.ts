// rateLimiter.ts - Rate limiting for FREE tier users

import { admin } from "./admin";
import { QuotaCheckResult, UserDocument, RateLimitDocument } from "./types";
import { FREE_MAX_REQUESTS_PER_DAY, FREE_MAX_REQUESTS_PER_MINUTE } from "./config";

const db = admin.firestore();

/**
 * Check if user can make a request based on rate limits
 * 
 * Rules:
 * - FREE tier: 
 *   - Max 4 requests per conversation (entryId or chatId)
 *   - Max 3 requests per minute (global)
 * - PAID/PRO tier: Unlimited
 * 
 * This is the primary quota enforcement mechanism.
 */
export async function checkRateLimit(
  userId: string,
  conversationId?: string  // entryId for journal, chatId for chat
): Promise<QuotaCheckResult> {
  try {
    // Load or create user document
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    
    let user: UserDocument;
    if (!userDoc.exists) {
      // Auto-create new user with free tier
      user = {
        userId: userId,
        plan: "free",
        subscriptionTier: "FREE",
        createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
        updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
      };
      await userRef.set(user);
    } else {
      user = userDoc.data() as UserDocument;
    }
    // Support both 'plan' and 'subscriptionTier' fields
    const userPlan = user.plan;
    const userTier = user.subscriptionTier;
    let plan: "free" | "pro" = "free";
    
    if (userPlan === "pro") {
      plan = "pro";
    } else if (userTier === "PAID") {
      plan = "pro";
    }
    
    const isPro = plan === "pro";

    // Pro/Paid tier: Unlimited
    if (isPro) {
      return { allowed: true };
    }

    // Check if throttle is unlocked via password (dev/admin feature)
    if (user.throttleUnlocked === true) {
      return { allowed: true };
    }

    const now = admin.firestore.Timestamp.now();

    // If conversationId provided, check per-conversation limit (4 per conversation)
    if (conversationId) {
      const conversationLimitRef = db.collection("rateLimits").doc(`${userId}_conv_${conversationId}`);
      const conversationLimitDoc = await conversationLimitRef.get();

      let conversationLimit: RateLimitDocument;

      if (!conversationLimitDoc.exists) {
        // First request for this conversation - initialize
        conversationLimit = {
          userId,
          requestsToday: 0,
          requestsLastMinute: 0,
          lastRequestTimestamp: now,
          lastMinuteWindowStart: now,
          lastDayWindowStart: now,
          updatedAt: now,
        };
        await conversationLimitRef.set(conversationLimit);
      } else {
        conversationLimit = conversationLimitDoc.data() as RateLimitDocument;
      }

      const maxPerConversation = 4; // 4 requests per conversation

      // Check per-conversation limit
      if (conversationLimit.requestsToday >= maxPerConversation) {
        return {
          allowed: false,
          error: {
            code: "RATE_LIMIT_CONVERSATION_EXCEEDED",
            message: `You've reached the limit of ${maxPerConversation} LUMARA requests per conversation. Upgrade to Pro for unlimited access.`,
            currentUsage: conversationLimit.requestsToday,
            limit: maxPerConversation,
            upgradeRequired: true,
            tier: "FREE",
            retryAfter: 0,
          },
        };
      }

      // Increment per-conversation counter
      conversationLimit.requestsToday += 1;
      conversationLimit.lastRequestTimestamp = now;
      conversationLimit.updatedAt = now;
      await conversationLimitRef.set(conversationLimit, { merge: true });
    }

    // Check global per-minute limit (applies to all requests)
    const rateLimitRef = db.collection("rateLimits").doc(`${userId}_global`);
    const rateLimitDoc = await rateLimitRef.get();

    let rateLimit: RateLimitDocument;

    if (!rateLimitDoc.exists) {
      // First request - initialize
      rateLimit = {
        userId,
        requestsToday: 0,
        requestsLastMinute: 0,
        lastRequestTimestamp: now,
        lastMinuteWindowStart: now,
        lastDayWindowStart: now,
        updatedAt: now,
      };
      await rateLimitRef.set(rateLimit);
    } else {
      rateLimit = rateLimitDoc.data() as RateLimitDocument;
    }

    // Check if we need to reset minute window
    const oneMinuteAgo = new Date(now.toMillis() - 60 * 1000);

    // Reset minute window if needed
    if (rateLimit.lastMinuteWindowStart.toMillis() < oneMinuteAgo.getTime()) {
      rateLimit.requestsLastMinute = 0;
      rateLimit.lastMinuteWindowStart = now;
    }

    const maxPerMinute = parseInt(FREE_MAX_REQUESTS_PER_MINUTE.value(), 10);

    // Check per-minute limit
    if (rateLimit.requestsLastMinute >= maxPerMinute) {
      const nextReset = new Date(rateLimit.lastMinuteWindowStart.toMillis() + 60 * 1000);
      const retryAfter = Math.ceil((nextReset.getTime() - Date.now()) / 1000);

      return {
        allowed: false,
        error: {
          code: "RATE_LIMIT_MINUTE_EXCEEDED",
          message: `Rate limit exceeded: ${maxPerMinute} requests per minute. Please wait ${retryAfter} seconds or upgrade to Pro.`,
          currentUsage: rateLimit.requestsLastMinute,
          limit: maxPerMinute,
          upgradeRequired: true,
          tier: "FREE",
          retryAfter: retryAfter > 0 ? retryAfter : 0,
        },
      };
    }

    // Allowed - increment global minute counter
    rateLimit.requestsLastMinute += 1;
    rateLimit.lastRequestTimestamp = now;
    rateLimit.updatedAt = now;
    await rateLimitRef.set(rateLimit, { merge: true });

    return { allowed: true };
  } catch (error) {
    console.error("Error checking rate limit:", error);
    return {
      allowed: false,
      error: {
        code: "RATE_LIMIT_CHECK_ERROR",
        message: "Error checking rate limit",
        currentUsage: 0,
        limit: 0,
        upgradeRequired: false,
        tier: "FREE",
      },
    };
  }
}

