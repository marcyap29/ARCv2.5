"use strict";
// authGuard.ts - Authentication and usage limits for free users
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthErrorCodes = exports.FREE_TIER_LIMITS = exports.ADMIN_EMAILS = void 0;
exports.isAdminEmail = isAdminEmail;
exports.enforceAuth = enforceAuth;
exports.checkJournalEntryLimit = checkJournalEntryLimit;
exports.checkChatLimit = checkChatLimit;
exports.canLinkAccount = canLinkAccount;
exports.linkAccountData = linkAccountData;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const admin_1 = require("./admin");
const db = admin_1.admin.firestore();
/**
 * Admin emails with full privileges (unlimited access, bypasses all limits)
 */
exports.ADMIN_EMAILS = [
    "marcyap@orbitalai.net",
];
/**
 * Check if an email has admin privileges
 */
function isAdminEmail(email) {
    if (!email)
        return false;
    return exports.ADMIN_EMAILS.includes(email.toLowerCase());
}
/**
 * Usage limits for free tier (applies to ALL free users, anonymous or not)
 */
exports.FREE_TIER_LIMITS = {
    JOURNAL_COMMENTS_PER_ENTRY: 5, // Max in-journal LUMARA comments per entry
    CHAT_MESSAGES_PER_CHAT: 20, // Max in-chat LUMARA messages per chat
};
/**
 * Custom error codes for auth-related issues
 */
exports.AuthErrorCodes = {
    UNAUTHENTICATED: "UNAUTHENTICATED",
    JOURNAL_LIMIT_REACHED: "JOURNAL_LIMIT_REACHED",
    CHAT_LIMIT_REACHED: "CHAT_LIMIT_REACHED",
};
/**
 * Enforce authentication (no usage limit checking)
 *
 * This function:
 * 1. Requires Firebase Auth (rejects unauthenticated requests)
 * 2. Returns user info and subscription status
 *
 * @throws HttpsError if unauthenticated
 */
async function enforceAuth(request) {
    // Step 1: Require authentication (no more public access)
    if (!request.auth) {
        firebase_functions_1.logger.warn("Unauthenticated request rejected");
        throw new https_1.HttpsError("unauthenticated", "Authentication required. Please sign in to continue.", { code: exports.AuthErrorCodes.UNAUTHENTICATED });
    }
    const userId = request.auth.uid;
    const firebaseUser = request.auth.token;
    const userEmail = firebaseUser.email;
    // Check if user is anonymous
    const signInProvider = firebaseUser.firebase?.sign_in_provider;
    const isAnonymous = signInProvider === "anonymous";
    // Check if user is an admin
    const isAdmin = isAdminEmail(userEmail);
    if (isAdmin) {
        firebase_functions_1.logger.info(`🔑 Admin user detected: ${userEmail}`);
    }
    firebase_functions_1.logger.info(`Auth enforced for user ${userId} (anonymous: ${isAnonymous}, provider: ${signInProvider}, email: ${userEmail || 'none'})`);
    // Step 2: Load or create user document
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    let user;
    if (!userDoc.exists) {
        // Create new user document
        // Admin users automatically get "pro" plan
        const plan = isAdmin ? "pro" : "free";
        const subscriptionTier = isAdmin ? "PAID" : "FREE";
        firebase_functions_1.logger.info(`Creating new user document for ${userId} (plan: ${plan})`);
        user = {
            userId: userId,
            plan: plan,
            subscriptionTier: subscriptionTier,
            isAnonymous: isAnonymous,
            createdAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
        };
        await userRef.set(user);
    }
    else {
        user = userDoc.data();
        // Auto-upgrade admin users to pro if they aren't already
        if (isAdmin && user.plan !== "pro") {
            firebase_functions_1.logger.info(`🔑 Auto-upgrading admin user ${userEmail} to pro`);
            await userRef.update({
                plan: "pro",
                subscriptionTier: "PAID",
                updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
            });
            user.plan = "pro";
            user.subscriptionTier = "PAID";
        }
        // Update isAnonymous flag if user upgraded from anonymous to real account
        if (user.isAnonymous && !isAnonymous) {
            firebase_functions_1.logger.info(`User ${userId} upgraded from anonymous to real account`);
            await userRef.update({
                isAnonymous: false,
                updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
            });
            user.isAnonymous = false;
        }
    }
    // Check if user is premium (admin users are always premium)
    const isPremium = isAdmin || user.plan === "pro" || user.subscriptionTier === "PAID";
    return {
        userId,
        isAnonymous,
        isPremium,
        user,
    };
}
/**
 * Check and enforce per-entry limit for in-journal LUMARA comments
 *
 * @param userId - The user's ID
 * @param entryId - The journal entry ID
 * @param isPremium - Whether user has premium subscription
 * @throws HttpsError if limit reached
 */
async function checkJournalEntryLimit(userId, entryId, isPremium) {
    // Premium users have unlimited access
    if (isPremium) {
        firebase_functions_1.logger.info(`Premium user ${userId} - no journal entry limit`);
        return { remaining: -1 }; // -1 indicates unlimited
    }
    // Get or create entry usage document
    const usageRef = db.collection("usageLimits").doc(`${userId}_entry_${entryId}`);
    const usageDoc = await usageRef.get();
    let currentCount = 0;
    if (usageDoc.exists) {
        currentCount = usageDoc.data()?.count || 0;
    }
    const limit = exports.FREE_TIER_LIMITS.JOURNAL_COMMENTS_PER_ENTRY;
    if (currentCount >= limit) {
        firebase_functions_1.logger.warn(`Journal entry limit reached for user ${userId}, entry ${entryId} (${currentCount}/${limit})`);
        throw new https_1.HttpsError("resource-exhausted", `The free version of Arc is limited to ${limit} LUMARA in-journal comments per entry.`, {
            code: exports.AuthErrorCodes.JOURNAL_LIMIT_REACHED,
            limit: limit,
            currentCount: currentCount,
            entryId: entryId,
        });
    }
    // Increment usage counter
    await usageRef.set({
        userId,
        entryId,
        count: admin_1.admin.firestore.FieldValue.increment(1),
        updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    const remaining = limit - currentCount - 1;
    firebase_functions_1.logger.info(`Journal entry usage for user ${userId}, entry ${entryId}: ${currentCount + 1}/${limit} (${remaining} remaining)`);
    return { remaining };
}
/**
 * Check and enforce per-chat limit for in-chat LUMARA messages
 *
 * @param userId - The user's ID
 * @param chatId - The chat/thread ID
 * @param isPremium - Whether user has premium subscription
 * @throws HttpsError if limit reached
 */
async function checkChatLimit(userId, chatId, isPremium) {
    // Premium users have unlimited access
    if (isPremium) {
        firebase_functions_1.logger.info(`Premium user ${userId} - no chat limit`);
        return { remaining: -1 }; // -1 indicates unlimited
    }
    // Get or create chat usage document
    const usageRef = db.collection("usageLimits").doc(`${userId}_chat_${chatId}`);
    const usageDoc = await usageRef.get();
    let currentCount = 0;
    if (usageDoc.exists) {
        currentCount = usageDoc.data()?.count || 0;
    }
    const limit = exports.FREE_TIER_LIMITS.CHAT_MESSAGES_PER_CHAT;
    if (currentCount >= limit) {
        firebase_functions_1.logger.warn(`Chat limit reached for user ${userId}, chat ${chatId} (${currentCount}/${limit})`);
        throw new https_1.HttpsError("resource-exhausted", `The free version of Arc is limited to ${limit} LUMARA messages per chat.`, {
            code: exports.AuthErrorCodes.CHAT_LIMIT_REACHED,
            limit: limit,
            currentCount: currentCount,
            chatId: chatId,
        });
    }
    // Increment usage counter
    await usageRef.set({
        userId,
        chatId,
        count: admin_1.admin.firestore.FieldValue.increment(1),
        updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    const remaining = limit - currentCount - 1;
    firebase_functions_1.logger.info(`Chat usage for user ${userId}, chat ${chatId}: ${currentCount + 1}/${limit} (${remaining} remaining)`);
    return { remaining };
}
/**
 * Check if a user can link their anonymous account to a real account
 */
async function canLinkAccount(userId) {
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
        return false;
    }
    const user = userDoc.data();
    return user.isAnonymous === true;
}
/**
 * Link anonymous user data to a new real account
 */
async function linkAccountData(oldAnonymousUid, newRealUid) {
    const batch = db.batch();
    // Get old user document
    const oldUserRef = db.collection("users").doc(oldAnonymousUid);
    const oldUserDoc = await oldUserRef.get();
    if (oldUserDoc.exists) {
        const oldUser = oldUserDoc.data();
        // Create/update new user document with transferred data
        const newUserRef = db.collection("users").doc(newRealUid);
        batch.set(newUserRef, {
            ...oldUser,
            userId: newRealUid,
            isAnonymous: false,
            linkedFromAnonymous: oldAnonymousUid,
            linkedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        // Mark old anonymous user document as linked
        batch.update(oldUserRef, {
            linkedToAccount: newRealUid,
            updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    await batch.commit();
    firebase_functions_1.logger.info(`Linked anonymous account ${oldAnonymousUid} to real account ${newRealUid}`);
}
//# sourceMappingURL=authGuard.js.map