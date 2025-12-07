"use strict";
// quotaGuards.ts - Tier and quota enforcement
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkCanAnalyzeEntry = checkCanAnalyzeEntry;
exports.checkCanSendMessage = checkCanSendMessage;
exports.incrementAnalysisCount = incrementAnalysisCount;
exports.incrementMessageCount = incrementMessageCount;
const admin_1 = require("./admin");
const config_1 = require("./config");
const db = admin_1.admin.firestore();
/**
 * Check if user can perform a deep analysis on a journal entry
 *
 * Rules:
 * - FREE tier: Max 4 analyses per entry
 * - PAID tier: Unlimited
 */
async function checkCanAnalyzeEntry(userId, entryId) {
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
        const tier = user.subscriptionTier;
        // Paid tier: Unlimited
        if (tier === "PAID") {
            return { allowed: true };
        }
        // Free tier: Check limit
        const entryDoc = await db.collection("journalEntries").doc(entryId).get();
        if (!entryDoc.exists) {
            return {
                allowed: false,
                error: {
                    code: "ENTRY_NOT_FOUND",
                    message: "Journal entry not found",
                    currentUsage: 0,
                    limit: 0,
                    upgradeRequired: false,
                    tier: "FREE",
                },
            };
        }
        const entry = entryDoc.data();
        const currentCount = entry.analysisCount || 0;
        const limit = parseInt(config_1.FREE_MAX_ANALYSES_PER_ENTRY.value(), 10);
        if (currentCount >= limit) {
            return {
                allowed: false,
                error: {
                    code: "ANALYSIS_LIMIT_REACHED",
                    message: `You've reached the limit of ${limit} analyses per entry. Upgrade to PAID for unlimited analyses.`,
                    currentUsage: currentCount,
                    limit: limit,
                    upgradeRequired: true,
                    tier: "FREE",
                },
            };
        }
        return { allowed: true };
    }
    catch (error) {
        console.error("Error checking analysis quota:", error);
        return {
            allowed: false,
            error: {
                code: "QUOTA_CHECK_ERROR",
                message: "Error checking quota",
                currentUsage: 0,
                limit: 0,
                upgradeRequired: false,
                tier: "FREE",
            },
        };
    }
}
/**
 * Check if user can send a chat message in a thread
 *
 * Rules:
 * - FREE tier: Max 200 messages per thread
 * - PAID tier: Unlimited
 */
async function checkCanSendMessage(userId, threadId) {
    try {
        // Load or create user document
        const userRef = db.collection("users").doc(userId);
        const userDoc = await userRef.get();
        let user;
        if (!userDoc.exists) {
            // Auto-create new user with free tier
            user = {
                userId: userId,
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
        const tier = user.subscriptionTier;
        // Paid tier: Unlimited
        if (tier === "PAID") {
            return { allowed: true };
        }
        // Free tier: Check limit
        const threadDoc = await db.collection("chatThreads").doc(threadId).get();
        if (!threadDoc.exists) {
            // New thread, allowed
            return { allowed: true };
        }
        const thread = threadDoc.data();
        const currentCount = thread.messageCount || 0;
        const limit = parseInt(config_1.FREE_MAX_CHAT_TURNS_PER_THREAD.value(), 10);
        if (currentCount >= limit) {
            return {
                allowed: false,
                error: {
                    code: "CHAT_LIMIT_REACHED",
                    message: `You've reached the limit of ${limit} messages per thread. Upgrade to PAID for unlimited chat.`,
                    currentUsage: currentCount,
                    limit: limit,
                    upgradeRequired: true,
                    tier: "FREE",
                },
            };
        }
        return { allowed: true };
    }
    catch (error) {
        console.error("Error checking chat quota:", error);
        return {
            allowed: false,
            error: {
                code: "QUOTA_CHECK_ERROR",
                message: "Error checking quota",
                currentUsage: 0,
                limit: 0,
                upgradeRequired: false,
                tier: "FREE",
            },
        };
    }
}
/**
 * Increment analysis count for a journal entry
 */
async function incrementAnalysisCount(entryId) {
    const entryRef = db.collection("journalEntries").doc(entryId);
    await entryRef.update({
        analysisCount: admin_1.admin.firestore.FieldValue.increment(1),
        updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
    });
}
/**
 * Increment message count for a chat thread
 */
async function incrementMessageCount(threadId) {
    const threadRef = db.collection("chatThreads").doc(threadId);
    await threadRef.update({
        messageCount: admin_1.admin.firestore.FieldValue.increment(1),
        updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
    });
}
//# sourceMappingURL=quotaGuards.js.map