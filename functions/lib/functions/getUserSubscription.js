"use strict";
// functions/getUserSubscription.ts - Get user subscription tier
Object.defineProperty(exports, "__esModule", { value: true });
exports.getUserSubscription = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const admin_1 = require("../admin");
const db = admin_1.admin.firestore();
/**
 * Get User Subscription Tier
 *
 * Called from Flutter app to determine user's subscription status
 * Returns subscription tier and related information
 *
 * Flow:
 * 1. Verify user authentication
 * 2. Query user document in Firestore
 * 3. Return subscription tier and status
 * 4. Default to 'free' tier if no subscription found
 */
exports.getUserSubscription = (0, https_1.onCall)(async (request) => {
    // Verify user is authenticated
    if (!request.auth?.uid) {
        firebase_functions_1.logger.warn("getUserSubscription: Unauthenticated request");
        throw new https_1.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const userId = request.auth.uid;
    try {
        firebase_functions_1.logger.info(`getUserSubscription: Checking subscription for user ${userId}`);
        // Get user document from Firestore
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            firebase_functions_1.logger.info(`getUserSubscription: User ${userId} not found, creating with free tier`);
            // Create user document with free tier as default
            const defaultSubscription = {
                tier: 'free',
                status: 'active'
            };
            await db.collection('users').doc(userId).set({
                createdAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
                subscriptionTier: defaultSubscription.tier,
                subscriptionStatus: defaultSubscription.status,
            }, { merge: true });
            return defaultSubscription;
        }
        const userData = userDoc.data();
        // Extract subscription information
        const subscription = {
            tier: userData?.subscriptionTier || 'free',
            status: userData?.subscriptionStatus || 'active',
            subscriptionId: userData?.subscriptionId,
            currentPeriodEnd: userData?.currentPeriodEnd,
            customerId: userData?.customerId,
        };
        firebase_functions_1.logger.info(`getUserSubscription: User ${userId} has tier ${subscription.tier}`);
        return subscription;
    }
    catch (error) {
        firebase_functions_1.logger.error(`getUserSubscription: Error for user ${userId}:`, error);
        throw new https_1.HttpsError('internal', 'Failed to get subscription information');
    }
});
//# sourceMappingURL=getUserSubscription.js.map