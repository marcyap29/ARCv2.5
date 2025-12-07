// functions/createCheckoutSession.ts - Create Stripe checkout session for premium subscription

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { admin } from "../admin";

const db = admin.firestore();

// Note: In production, you would initialize Stripe here:
// import Stripe from 'stripe';
// const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2023-10-16' });

export interface CheckoutSessionRequest {
  priceId: string;
  successUrl?: string;
  cancelUrl?: string;
}

/**
 * Create Stripe Checkout Session for Premium Subscription
 *
 * Creates a Stripe checkout session for $30/month premium subscription
 * Links the Stripe customer to the authenticated Firebase user
 *
 * Flow:
 * 1. Verify user authentication
 * 2. Get or create Stripe customer
 * 3. Create checkout session with premium price
 * 4. Return checkout URL for client to redirect to
 *
 * Note: This is a simplified implementation for MVP
 * In production, you should:
 * - Use actual Stripe SDK
 * - Add proper error handling
 * - Implement customer creation/retrieval
 * - Handle webhook verification
 */
export const createCheckoutSession = onCall(async (request) => {
  // Verify user is authenticated
  if (!request.auth?.uid) {
    logger.warn("createCheckoutSession: Unauthenticated request");
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = request.auth.uid;
  const userEmail = request.auth.token.email;
  // @ts-ignore - unused for now
  const data = request.data as CheckoutSessionRequest;

  try {
    logger.info(`createCheckoutSession: Creating session for user ${userId}`);

    // For MVP, we'll return a mock checkout URL
    // In production, this would create an actual Stripe session
    const mockCheckoutUrl = `https://checkout.stripe.com/pay/premium-subscription?customer=${userId}&email=${userEmail}`;

    // Store checkout session attempt in Firestore for tracking
    await db.collection('users').doc(userId).set({
      lastCheckoutAttempt: admin.firestore.FieldValue.serverTimestamp(),
      email: userEmail,
    }, { merge: true });

    logger.info(`createCheckoutSession: Mock session created for user ${userId}`);

    return {
      checkoutUrl: mockCheckoutUrl,
      sessionId: `mock_session_${userId}_${Date.now()}`,
    };

    // Production implementation would look like this:
    /*
    // Get or create Stripe customer
    let customerId = await getStripeCustomerId(userId);

    if (!customerId) {
      const customer = await stripe.customers.create({
        email: userEmail,
        metadata: {
          firebaseUid: userId,
        },
      });
      customerId = customer.id;

      // Store customer ID in Firestore
      await db.collection('users').doc(userId).set({
        customerId: customerId,
      }, { merge: true });
    }

    // Create checkout session
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      payment_method_types: ['card'],
      line_items: [{
        price: data.priceId, // 'price_premium_monthly' from Stripe dashboard
        quantity: 1,
      }],
      mode: 'subscription',
      success_url: data.successUrl || 'https://your-app.com/success?session_id={CHECKOUT_SESSION_ID}',
      cancel_url: data.cancelUrl || 'https://your-app.com/cancel',
      metadata: {
        firebaseUid: userId,
      },
    });

    return {
      checkoutUrl: session.url,
      sessionId: session.id,
    };
    */

  } catch (error) {
    logger.error(`createCheckoutSession: Error for user ${userId}:`, error);
    throw new HttpsError('internal', 'Failed to create checkout session');
  }
});

/**
 * Helper function to get Stripe customer ID for a user
 * In production, this would query Firestore for existing customer ID
 */
// @ts-ignore - unused for now
async function getStripeCustomerId(userId: string): Promise<string | null> {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    return userData?.customerId || null;
  } catch (error) {
    logger.error(`getStripeCustomerId: Error for user ${userId}:`, error);
    return null;
  }
}