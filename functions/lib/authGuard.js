"use strict";
// authGuard.ts - Authentication enforcement with anonymous trial support
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthErrorCodes = exports.ANONYMOUS_TRIAL_LIMIT = void 0;
exports.enforceAuth = enforceAuth;
exports.canLinkAccount = canLinkAccount;
exports.linkAccountData = linkAccountData;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const admin_1 = require("./admin");
const db = admin_1.admin.firestore();
/**
 * Anonymous trial configuration
 */
exports.ANONYMOUS_TRIAL_LIMIT = 5; // Max requests before requiring sign-in
/**
 * Custom error codes for auth-related issues
 */
exports.AuthErrorCodes = {
    UNAUTHENTICATED: "UNAUTHENTICATED",
    ANONYMOUS_TRIAL_EXPIRED: "ANONYMOUS_TRIAL_EXPIRED",
};
/**
 * Enforce authentication with anonymous trial support
 *
 * This function:
 * 1. Requires Firebase Auth (rejects unauthenticated requests)
 * 2. Allows anonymous users a limited trial (5 requests)
 * 3. Returns user info and trial status
 *
 * After trial expires, anonymous users must sign in with Google/Email
 * to continue using the app.
 *
 * @throws HttpsError if unauthenticated or trial expired
 */
async function enforceAuth(request) {
    // Step 1: Require authentication (no more public access)
    if (!request.auth) {
        firebase_functions_1.logger.warn("Unauthenticated request rejected");
        throw new https_1.HttpsError("unauthenticated", "Authentication required. Please sign in to continue.", { code: exports.AuthErrorCodes.UNAUTHENTICATED });
    }
    const userId = request.auth.uid;
    const firebaseUser = request.auth.token;
    // Debug log the token structure to understand anonymous detection
    firebase_functions_1.logger.info(`Auth token structure: email=${firebaseUser.email}, firebase.sign_in_provider=${firebaseUser.firebase?.sign_in_provider}, provider_id=${firebaseUser.provider_id}`);
    // Check if user is anonymous (Firebase Auth provides this in the token)
    // For onCall functions, the sign_in_provider is in firebase.sign_in_provider
    const signInProvider = firebaseUser.firebase?.sign_in_provider;
    const isAnonymous = signInProvider === "anonymous";
    firebase_functions_1.logger.info(`Auth enforced for user ${userId} (anonymous: ${isAnonymous}, provider: ${signInProvider})`);
    // Step 2: Load or create user document
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    let user;
    if (!userDoc.exists) {
        // Create new user document
        firebase_functions_1.logger.info(`Creating new user document for ${userId}`);
        user = {
            userId: userId,
            plan: "free",
            subscriptionTier: "FREE",
            isAnonymous: isAnonymous,
            anonymousRequestCount: 0,
            createdAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
        };
        await userRef.set(user);
    }
    else {
        user = userDoc.data();
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
    // Step 3: For anonymous users, check and enforce trial limit
    if (isAnonymous) {
        const currentCount = user.anonymousRequestCount || 0;
        if (currentCount >= exports.ANONYMOUS_TRIAL_LIMIT) {
            firebase_functions_1.logger.warn(`Anonymous trial expired for user ${userId} (${currentCount}/${exports.ANONYMOUS_TRIAL_LIMIT})`);
            throw new https_1.HttpsError("permission-denied", `Your free trial of ${exports.ANONYMOUS_TRIAL_LIMIT} requests has ended. Please sign in with Google or Email to continue using the app.`, {
                code: exports.AuthErrorCodes.ANONYMOUS_TRIAL_EXPIRED,
                trialLimit: exports.ANONYMOUS_TRIAL_LIMIT,
                requestCount: currentCount,
            });
        }
        // Increment anonymous request count
        await userRef.update({
            anonymousRequestCount: admin_1.admin.firestore.FieldValue.increment(1),
            updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
        });
        const trialRemaining = exports.ANONYMOUS_TRIAL_LIMIT - currentCount - 1;
        firebase_functions_1.logger.info(`Anonymous user ${userId} trial: ${trialRemaining} requests remaining`);
        return {
            userId,
            isAnonymous: true,
            trialRemaining,
            user,
        };
    }
    // Real (non-anonymous) user - full access
    return {
        userId,
        isAnonymous: false,
        user,
    };
}
/**
 * Check if a user can link their anonymous account to a real account
 *
 * This is called from the Flutter side when user decides to sign in
 * after using anonymous auth.
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
 *
 * Called after Firebase Auth linkWithCredential succeeds on client.
 * Transfers subscription data and clears anonymous flags.
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
            anonymousRequestCount: 0, // Reset trial counter
            linkedFromAnonymous: oldAnonymousUid,
            linkedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        // Optionally: Delete or mark old anonymous user document
        batch.update(oldUserRef, {
            linkedToAccount: newRealUid,
            updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    await batch.commit();
    firebase_functions_1.logger.info(`Linked anonymous account ${oldAnonymousUid} to real account ${newRealUid}`);
}
//# sourceMappingURL=authGuard.js.map