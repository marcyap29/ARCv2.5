"use strict";
// functions/stripeWebhook.ts - Stripe subscription webhook handler
Object.defineProperty(exports, "__esModule", { value: true });
exports.stripeWebhook = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const admin_1 = require("../admin");
const db = admin_1.admin.firestore();
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
exports.stripeWebhook = (0, https_1.onRequest)({
    cors: true,
}, async (req, res) => {
    // In production, verify webhook signature
    // const signature = req.headers["stripe-signature"];
    // const event = stripe.webhooks.constructEvent(req.body, signature, STRIPE_WEBHOOK_SECRET);
    const event = req.body;
    firebase_functions_1.logger.info(`Received Stripe webhook: ${event.type}`);
    try {
        switch (event.type) {
            case "checkout.session.completed": {
                // User completed checkout - upgrade to pro
                const session = event.data.object;
                const customerId = session.customer;
                const subscriptionId = session.subscription;
                const usersSnapshot = await db
                    .collection("users")
                    .where("stripeCustomerId", "==", customerId)
                    .limit(1)
                    .get();
                if (usersSnapshot.empty) {
                    firebase_functions_1.logger.warn(`No user found for Stripe customer: ${customerId}`);
                    res.status(200).send({ received: true });
                    return;
                }
                const userId = usersSnapshot.docs[0].id;
                // Upgrade to pro
                await db.collection("users").doc(userId).update({
                    plan: "pro",
                    subscriptionTier: "PAID", // Legacy field
                    subscriptionStatus: "active",
                    stripeSubscriptionId: subscriptionId,
                    updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
                });
                firebase_functions_1.logger.info(`Upgraded user ${userId} to pro plan`);
                break;
            }
            case "invoice.payment_succeeded": {
                // Payment succeeded - ensure user is pro
                const invoice = event.data.object;
                const customerId = invoice.customer;
                const subscriptionId = invoice.subscription;
                const usersSnapshot = await db
                    .collection("users")
                    .where("stripeCustomerId", "==", customerId)
                    .limit(1)
                    .get();
                if (!usersSnapshot.empty) {
                    const userId = usersSnapshot.docs[0].id;
                    await db.collection("users").doc(userId).update({
                        plan: "pro",
                        subscriptionTier: "PAID", // Legacy field
                        subscriptionStatus: "active",
                        stripeSubscriptionId: subscriptionId,
                        updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
                    });
                    firebase_functions_1.logger.info(`Confirmed pro status for user ${userId}`);
                }
                break;
            }
            case "invoice.payment_failed": {
                // Payment failed - downgrade to free
                const invoice = event.data.object;
                const customerId = invoice.customer;
                const usersSnapshot = await db
                    .collection("users")
                    .where("stripeCustomerId", "==", customerId)
                    .limit(1)
                    .get();
                if (!usersSnapshot.empty) {
                    const userId = usersSnapshot.docs[0].id;
                    await db.collection("users").doc(userId).update({
                        plan: "free",
                        subscriptionTier: "FREE", // Legacy field
                        subscriptionStatus: "canceled",
                        updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
                    });
                    firebase_functions_1.logger.info(`Downgraded user ${userId} to free plan (payment failed)`);
                }
                break;
            }
            case "customer.subscription.deleted": {
                // Subscription canceled - downgrade to free
                const subscription = event.data.object;
                const customerId = subscription.customer;
                const usersSnapshot = await db
                    .collection("users")
                    .where("stripeCustomerId", "==", customerId)
                    .limit(1)
                    .get();
                if (usersSnapshot.empty) {
                    firebase_functions_1.logger.warn(`No user found for Stripe customer: ${customerId}`);
                    res.status(200).send({ received: true });
                    return;
                }
                const userId = usersSnapshot.docs[0].id;
                // Downgrade to free
                await db.collection("users").doc(userId).update({
                    plan: "free",
                    subscriptionTier: "FREE", // Legacy field
                    subscriptionStatus: "canceled",
                    updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
                });
                firebase_functions_1.logger.info(`Downgraded user ${userId} to free plan`);
                break;
            }
            case "customer.subscription.created":
            case "customer.subscription.updated": {
                // Legacy support - handle subscription events
                const subscription = event.data.object;
                const customerId = subscription.customer;
                const status = subscription.status;
                const usersSnapshot = await db
                    .collection("users")
                    .where("stripeCustomerId", "==", customerId)
                    .limit(1)
                    .get();
                if (usersSnapshot.empty) {
                    firebase_functions_1.logger.warn(`No user found for Stripe customer: ${customerId}`);
                    res.status(200).send({ received: true });
                    return;
                }
                const userId = usersSnapshot.docs[0].id;
                const isActive = status === "active";
                await db.collection("users").doc(userId).update({
                    plan: isActive ? "pro" : "free",
                    subscriptionTier: isActive ? "PAID" : "FREE", // Legacy field
                    subscriptionStatus: status === "active" ? "active" : status === "canceled" ? "canceled" : "trial",
                    stripeSubscriptionId: subscription.id,
                    updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
                });
                firebase_functions_1.logger.info(`Updated user ${userId} to ${isActive ? "pro" : "free"} plan`);
                break;
            }
            default:
                firebase_functions_1.logger.info(`Unhandled Stripe event type: ${event.type}`);
        }
        // Always return 200 to acknowledge receipt
        res.status(200).send({ received: true });
    }
    catch (error) {
        firebase_functions_1.logger.error("Error processing Stripe webhook:", error);
        res.status(500).send({ error: "Webhook processing failed" });
    }
});
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
//# sourceMappingURL=stripeWebhook.js.map