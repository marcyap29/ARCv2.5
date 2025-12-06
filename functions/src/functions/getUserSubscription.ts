// functions/getUserSubscription.ts - Get user subscription tier

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { admin } from "../admin";

const db = admin.firestore();

export interface UserSubscription {
  tier: 'free' | 'premium';
  status: string;
  subscriptionId?: string;
  currentPeriodEnd?: number;
  customerId?: string;
}

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
export const getUserSubscription = onCall(async (request) => {
  // Verify user is authenticated
  if (!request.auth?.uid) {
    logger.warn("getUserSubscription: Unauthenticated request");
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = request.auth.uid;

  try {
    logger.info(`getUserSubscription: Checking subscription for user ${userId}`);

    // Get user document from Firestore
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      logger.info(`getUserSubscription: User ${userId} not found, creating with free tier`);

      // Create user document with free tier as default
      const defaultSubscription: UserSubscription = {
        tier: 'free',
        status: 'active'
      };

      await db.collection('users').doc(userId).set({
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        subscriptionTier: defaultSubscription.tier,
        subscriptionStatus: defaultSubscription.status,
      }, { merge: true });

      return defaultSubscription;
    }

    const userData = userDoc.data();

    // Extract subscription information
    const subscription: UserSubscription = {
      tier: userData?.subscriptionTier || 'free',
      status: userData?.subscriptionStatus || 'active',
      subscriptionId: userData?.subscriptionId,
      currentPeriodEnd: userData?.currentPeriodEnd,
      customerId: userData?.customerId,
    };

    logger.info(`getUserSubscription: User ${userId} has tier ${subscription.tier}`);

    return subscription;

  } catch (error) {
    logger.error(`getUserSubscription: Error for user ${userId}:`, error);
    throw new HttpsError('internal', 'Failed to get subscription information');
  }
});