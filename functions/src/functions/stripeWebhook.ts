// functions/stripeWebhook.ts - Stripe subscription webhook handler

import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { admin } from "../admin";
import { SubscriptionTier, SubscriptionStatus } from "../types";

const db = admin.firestore();

/**
 * Stripe Webhook Handler
 * 
 * Updates user subscription tier in Firestore when Stripe events occur
 * 
 * Events handled:
 * - customer.subscription.created
 * - customer.subscription.updated
 * - customer.subscription.deleted
 * 
 * Flow:
 * 1. Receive Stripe webhook event
 * 2. Verify webhook signature (in production, use Stripe SDK)
 * 3. Map customerId → userId (requires customerId stored in user doc)
 * 4. Update subscriptionTier and subscriptionStatus in Firestore
 * 
 * Note: This is a simplified version. In production, you should:
 * - Verify webhook signatures using Stripe SDK
 * - Handle idempotency
 * - Add retry logic
 * - Log all events for debugging
 */
export const stripeWebhook = onRequest(
  {
    cors: true,
  },
  async (req, res) => {
    // In production, verify webhook signature
    // const signature = req.headers["stripe-signature"];
    // const event = stripe.webhooks.constructEvent(req.body, signature, STRIPE_WEBHOOK_SECRET);

    const event = req.body;

    logger.info(`Received Stripe webhook: ${event.type}`);

    try {
      switch (event.type) {
        case "customer.subscription.created":
        case "customer.subscription.updated": {
          const subscription = event.data.object;
          const customerId = subscription.customer;
          const status = subscription.status;

          // Map customerId to userId
          // In production, you might have a customers/{customerId} collection
          // or store customerId in users/{userId}/stripeCustomerId
          const usersSnapshot = await db
            .collection("users")
            .where("stripeCustomerId", "==", customerId)
            .limit(1)
            .get();

          if (usersSnapshot.empty) {
            logger.warn(`No user found for Stripe customer: ${customerId}`);
            res.status(200).send({ received: true });
            return;
          }

          const userId = usersSnapshot.docs[0].id;
          const subscriptionStatus: SubscriptionStatus =
            status === "active" ? "active" : status === "canceled" ? "canceled" : "trial";

          // Update user document
          await db.collection("users").doc(userId).update({
            subscriptionTier: "PAID",
            subscriptionStatus: subscriptionStatus,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          logger.info(`Updated user ${userId} to PAID tier, status: ${subscriptionStatus}`);
          break;
        }

        case "customer.subscription.deleted": {
          const subscription = event.data.object;
          const customerId = subscription.customer;

          // Find user by customerId
          const usersSnapshot = await db
            .collection("users")
            .where("stripeCustomerId", "==", customerId)
            .limit(1)
            .get();

          if (usersSnapshot.empty) {
            logger.warn(`No user found for Stripe customer: ${customerId}`);
            res.status(200).send({ received: true });
            return;
          }

          const userId = usersSnapshot.docs[0].id;

          // Downgrade to FREE tier
          await db.collection("users").doc(userId).update({
            subscriptionTier: "FREE",
            subscriptionStatus: "canceled",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          logger.info(`Downgraded user ${userId} to FREE tier`);
          break;
        }

        default:
          logger.info(`Unhandled Stripe event type: ${event.type}`);
      }

      // Always return 200 to acknowledge receipt
      res.status(200).send({ received: true });
    } catch (error) {
      logger.error("Error processing Stripe webhook:", error);
      res.status(500).send({ error: "Webhook processing failed" });
    }
  }
);

/**
 * Production improvements needed:
 * 
 * 1. Webhook signature verification:
 *    import Stripe from "stripe";
 *    const stripe = new Stripe(STRIPE_SECRET_KEY);
 *    const event = stripe.webhooks.constructEvent(req.body, signature, webhookSecret);
 * 
 * 2. Idempotency:
 *    - Store processed event IDs
 *    - Skip duplicate events
 * 
 * 3. Error handling:
 *    - Retry failed updates
 *    - Dead letter queue for persistent failures
 * 
 * 4. Customer mapping:
 *    - Consider a customers/{customerId} collection
 *    - Store userId in customer document
 *    - Faster lookups
 */

