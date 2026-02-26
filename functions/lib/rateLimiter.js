"use strict";
// rateLimiter.ts - Rate limiting for FREE tier users
Object.defineProperty(exports, "__esModule", { value: true });
exports.FREE_TIER_DAILY_LUMARA_LIMIT = void 0;
exports.checkUnifiedDailyLimit = checkUnifiedDailyLimit;
exports.checkRateLimit = checkRateLimit;
const admin_1 = require("./admin");
const config_1 = require("./config");
const db = admin_1.admin.firestore();
/** Unified daily request limit for free tier users (chat + reflections + voice) */
exports.FREE_TIER_DAILY_LUMARA_LIMIT = 50;
/** Emails that are always exempt from rate limiting */
const EXEMPT_EMAILS = [
    "marcyap@orbitalai.net",
    "marcyap@fastmail.com",
];
/**
 * Check and enforce the unified daily LUMARA limit (50 requests/day).
 *
 * This single pool covers ALL free-tier LUMARA interactions:
 * chat messages, journal reflections, journal analyses, and prompt generation.
 * Uses the same `lumaraDailyUsage` Firestore field as proxyGemini so all
 * call paths share one counter.
 *
 * - Exempt emails: unlimited
 * - Premium (plan=pro / subscriptionTier=PAID / throttleUnlocked): unlimited
 * - Free: max FREE_TIER_DAILY_LUMARA_LIMIT per calendar day (UTC)
 */
async function checkUnifiedDailyLimit(userId, userEmail) {
    try {
        // Exempt emails bypass all limits
        if (userEmail && EXEMPT_EMAILS.includes(userEmail.toLowerCase())) {
            return { allowed: true };
        }
        const userRef = db.collection("users").doc(userId);
        const userDoc = await userRef.get();
        let userData = {};
        if (!userDoc.exists) {
            // Auto-create new user with free tier
            const newUser = {
                userId,
                plan: "free",
                subscriptionTier: "FREE",
                createdAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
            };
            await userRef.set(newUser);
        }
        else {
            userData = userDoc.data();
        }
        // Premium / unlocked users: unlimited
        const isPremium = userData.plan === "pro" ||
            userData.subscriptionTier === "PAID" ||
            userData.throttleUnlocked === true;
        if (isPremium) {
            return { allowed: true };
        }
        // Check and increment daily usage (shared with proxyGemini via lumaraDailyUsage)
        const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD UTC
        const usage = userData.lumaraDailyUsage || {};
        const currentCount = usage.date === today ? (usage.count || 0) : 0;
        if (currentCount >= exports.FREE_TIER_DAILY_LUMARA_LIMIT) {
            return {
                allowed: false,
                error: {
                    code: "DAILY_LIMIT_REACHED",
                    message: `Daily limit of ${exports.FREE_TIER_DAILY_LUMARA_LIMIT} LUMARA requests reached. Upgrade to premium for unlimited access.`,
                    currentUsage: currentCount,
                    limit: exports.FREE_TIER_DAILY_LUMARA_LIMIT,
                    upgradeRequired: true,
                    tier: "FREE",
                    retryAfter: 0,
                },
            };
        }
        await userRef.set({ lumaraDailyUsage: { date: today, count: currentCount + 1 } }, { merge: true });
        return { allowed: true };
    }
    catch (error) {
        console.error("Error checking unified daily limit:", error);
        // Fail open to avoid blocking users on infrastructure errors
        return { allowed: true };
    }
}
/**
 * Per-minute spam protection (applies to free users only).
 * Does NOT enforce the daily quota — use checkUnifiedDailyLimit for that.
 */
async function checkRateLimit(userId, userEmail) {
    try {
        // Exempt emails bypass all limits
        if (userEmail && EXEMPT_EMAILS.includes(userEmail.toLowerCase())) {
            return { allowed: true };
        }
        const userRef = db.collection("users").doc(userId);
        const userDoc = await userRef.get();
        let user;
        if (!userDoc.exists) {
            user = {
                userId,
                plan: "free",
                subscriptionTier: "FREE",
                createdAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
            };
            await userRef.set(user);
        }
        else {
            user = userDoc.data();
        }
        // Premium / unlocked: unlimited
        const isPro = user.plan === "pro" ||
            user.subscriptionTier === "PAID" ||
            user.throttleUnlocked === true;
        if (isPro) {
            return { allowed: true };
        }
        const now = admin_1.admin.firestore.Timestamp.now();
        const rateLimitRef = db.collection("rateLimits").doc(`${userId}_global`);
        const rateLimitDoc = await rateLimitRef.get();
        let rateLimit;
        if (!rateLimitDoc.exists) {
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
        const oneMinuteAgo = new Date(now.toMillis() - 60 * 1000);
        if (rateLimit.lastMinuteWindowStart.toMillis() < oneMinuteAgo.getTime()) {
            rateLimit.requestsLastMinute = 0;
            rateLimit.lastMinuteWindowStart = now;
        }
        const maxPerMinute = parseInt(config_1.FREE_MAX_REQUESTS_PER_MINUTE.value(), 10);
        if (rateLimit.requestsLastMinute >= maxPerMinute) {
            const nextReset = new Date(rateLimit.lastMinuteWindowStart.toMillis() + 60 * 1000);
            const retryAfter = Math.ceil((nextReset.getTime() - Date.now()) / 1000);
            return {
                allowed: false,
                error: {
                    code: "RATE_LIMIT_MINUTE_EXCEEDED",
                    message: `Too many requests: please wait ${retryAfter} seconds before trying again.`,
                    currentUsage: rateLimit.requestsLastMinute,
                    limit: maxPerMinute,
                    upgradeRequired: false,
                    tier: "FREE",
                    retryAfter: retryAfter > 0 ? retryAfter : 0,
                },
            };
        }
        rateLimit.requestsLastMinute += 1;
        rateLimit.lastRequestTimestamp = now;
        rateLimit.updatedAt = now;
        await rateLimitRef.set(rateLimit, { merge: true });
        return { allowed: true };
    }
    catch (error) {
        console.error("Error checking rate limit:", error);
        return { allowed: true };
    }
}
//# sourceMappingURL=rateLimiter.js.map