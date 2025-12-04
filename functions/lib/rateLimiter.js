"use strict";
// rateLimiter.ts - Rate limiting for FREE tier users
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkRateLimit = checkRateLimit;
const admin_1 = require("./admin");
const config_1 = require("./config");
const db = admin_1.admin.firestore();
/**
 * Check if user can make a request based on rate limits
 *
 * Rules:
 * - FREE tier:
 *   - Max 20 requests per day
 *   - Max 3 requests per minute
 * - PAID/PRO tier: Unlimited
 *
 * This is the primary quota enforcement mechanism.
 * Legacy per-entry/thread limits are secondary.
 */
async function checkRateLimit(userId) {
    try {
        // Load user document
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) {
            return {
                allowed: false,
                error: {
                    code: "USER_NOT_FOUND",
                    message: "User not found",
                    currentUsage: 0,
                    limit: 0,
                    upgradeRequired: false,
                    tier: "FREE",
                },
            };
        }
        const user = userDoc.data();
        // Support both 'plan' and 'subscriptionTier' fields
        const userPlan = user.plan;
        const userTier = user.subscriptionTier;
        let plan = "free";
        if (userPlan === "pro") {
            plan = "pro";
        }
        else if (userTier === "PAID") {
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
        // Free tier: Check rate limits
        const now = admin_1.admin.firestore.Timestamp.now();
        const rateLimitRef = db.collection("rateLimits").doc(userId);
        const rateLimitDoc = await rateLimitRef.get();
        let rateLimit;
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
        }
        else {
            rateLimit = rateLimitDoc.data();
        }
        // Check if we need to reset windows
        const oneMinuteAgo = new Date(now.toMillis() - 60 * 1000);
        const oneDayAgo = new Date(now.toMillis() - 24 * 60 * 60 * 1000);
        // Reset minute window if needed
        if (rateLimit.lastMinuteWindowStart.toMillis() < oneMinuteAgo.getTime()) {
            rateLimit.requestsLastMinute = 0;
            rateLimit.lastMinuteWindowStart = now;
        }
        // Reset day window if needed
        if (rateLimit.lastDayWindowStart.toMillis() < oneDayAgo.getTime()) {
            rateLimit.requestsToday = 0;
            rateLimit.lastDayWindowStart = now;
        }
        const maxPerDay = parseInt(config_1.FREE_MAX_REQUESTS_PER_DAY.value(), 10);
        const maxPerMinute = parseInt(config_1.FREE_MAX_REQUESTS_PER_MINUTE.value(), 10);
        // Check daily limit
        if (rateLimit.requestsToday >= maxPerDay) {
            const nextReset = new Date(rateLimit.lastDayWindowStart.toMillis() + 24 * 60 * 60 * 1000);
            const retryAfter = Math.ceil((nextReset.getTime() - Date.now()) / 1000);
            return {
                allowed: false,
                error: {
                    code: "RATE_LIMIT_DAILY_EXCEEDED",
                    message: `You've reached the daily limit of ${maxPerDay} requests. Upgrade to Pro for unlimited access.`,
                    currentUsage: rateLimit.requestsToday,
                    limit: maxPerDay,
                    upgradeRequired: true,
                    tier: "FREE",
                    retryAfter: retryAfter > 0 ? retryAfter : 0,
                },
            };
        }
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
        // Allowed - increment counters
        rateLimit.requestsToday += 1;
        rateLimit.requestsLastMinute += 1;
        rateLimit.lastRequestTimestamp = now;
        rateLimit.updatedAt = now;
        await rateLimitRef.set(rateLimit, { merge: true });
        return { allowed: true };
    }
    catch (error) {
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
//# sourceMappingURL=rateLimiter.js.map