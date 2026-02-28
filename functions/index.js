// functions/index.js

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const cors = require("cors")({ origin: true });
const { GoogleGenerativeAI } = require("@google/generative-ai");
const Stripe = require("stripe");

// Initialize Firebase Admin
initializeApp();

// Define secrets
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
const STRIPE_PRICE_ID_MONTHLY = defineSecret("STRIPE_PRICE_ID_MONTHLY");
const STRIPE_PRICE_ID_ANNUAL = defineSecret("STRIPE_PRICE_ID_ANNUAL");
const STRIPE_FOUNDER_PRICE_ID_UPFRONT = defineSecret("STRIPE_FOUNDER_PRICE_ID_UPFRONT");

// Simple Gemini API proxy - hides API key from client
exports.proxyGemini = onCall(
  { secrets: [GEMINI_API_KEY], invoker: "public" },
  async (request) => {
    const { system, user, jsonExpected } = request.data;

    if (!user) {
      throw new HttpsError("invalid-argument", "user prompt is required");
    }

    const userId = request.auth?.uid || `mvp_test_${Date.now()}`;
    logger.info(`Proxying Gemini request for user ${userId}`);

    try {
      const apiKey = GEMINI_API_KEY.value();
      if (!apiKey) {
        throw new HttpsError("internal", "Gemini API key not configured");
      }

      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: "gemini-3-flash-preview",
        tools: [{ googleSearch: {} }],
        generationConfig: jsonExpected
          ? { responseMimeType: "application/json" }
          : undefined,
      });

      const chat = model.startChat({
        history: system
          ? [
              { role: "user", parts: [{ text: system }] },
              { role: "model", parts: [{ text: "Ok." }] },
            ]
          : [],
      });

      const result = await chat.sendMessage(user);
      const response = result.response.text();

      logger.info(`Gemini proxy successful for user ${userId}`);
      return { response };
    } catch (error) {
      logger.error(`Gemini proxy error:`, error);
      throw new HttpsError("internal", `Gemini API error: ${error.message || "Unknown error"}`);
    }
  }
);

// Define the secret we created in the previous step
const veniceApiKey = defineSecret("VENICE_API_KEY");

// The main Cloud Function
exports.veniceproxy = onRequest(
  // Grant the function access to the secret
  { secrets: [veniceApiKey] },
  async (req, res) => {
    // ENFORCE CORS
    cors(req, res, async () => {
      // 1. SECURITY: Check for Firebase Authentication
      // The user must be logged in to your app via Google Sign-In
      if (!req.user) {
        logger.error("Unauthenticated request attempted.");
        res.status(403).send({ error: "Unauthorized. Please log in." });
        return;
      }
      
      // Log the UID of the user making the request for debugging
      logger.info(`Request from authenticated user: \${req.user.uid}`);

      // 2. VALIDATE THE REQUEST BODY
      // We expect a JSON object with a "prompt" key
      if (req.method !== "POST" || !req.body || !req.body.prompt) {
        res.status(400).send({ error: "Invalid request. Please send a POST request with a 'prompt' in the body." });
        return;
      }

      const userPrompt = req.body.prompt;

      try {
        // 3. CALL THE VENICE AI API
        const veniceResponse = await fetch("https://api.venice.ai/api/v1/chat/completions", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            // Use the secret API key
            "Authorization": `Bearer \${veniceApiKey.value()}`,
          },
          body: JSON.stringify({
            model: "glm-4.6", // The specific model you requested
            messages: [
              {
                role: "user",
                content: userPrompt,
              },
            ],
            // You can add other parameters like temperature, max_tokens, etc. here if needed
          }),
        });

        if (!veniceResponse.ok) {
          const errorBody = await veniceResponse.text();
          logger.error(`Venice API Error: ${veniceResponse.status} - ${errorBody}`);
          res.status(500).send({ error: "Failed to get a response from Venice AI." });
          return;
        }

        const veniceData = await veniceResponse.json();
        const aiResponse = veniceData.choices[0].message.content;

        // 4. SEND THE RESPONSE BACK TO YOUR APP
        res.status(200).send({ response: aiResponse });

      } catch (error) {
        logger.error("Internal server error:", error);
        res.status(500).send({ error: "An internal error occurred." });
      }
    });
  }
);

// ============================================================================
// STRIPE PAYMENT INTEGRATION
// ============================================================================

/**
 * Get user subscription tier
 * Returns premium for marcyap@orbitalai.net, free for others
 */
exports.getUserSubscription = onCall(
  {
    cors: true,
  },
  async (request) => {
    // Verify authentication
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const uid = request.auth.uid;
    const email = request.auth.token.email;

    logger.info(`getUserSubscription called by user: ${uid} (${email})`);

    // Premium users - add more emails here as needed
    const premiumEmails = [
      'marcyap@orbitalai.net',
      // Add more premium emails here
    ];

    // Check if user has premium access
    const tier = premiumEmails.includes(email) ? 'premium' : 'free';

    logger.info(`Returning subscription tier: ${tier} for ${email}`);

    return {
      tier: tier,
      uid: uid,
      email: email,
      features: {
        lumaraThrottled: tier === 'free',
        phaseHistoryRestricted: tier === 'free',
        dailyLumaraLimit: tier === 'premium' ? -1 : 50
      }
    };
  }
);

/**
 * Create Stripe Checkout Session for subscription
 */
exports.createCheckoutSession = onCall(
  {
    cors: true,
    secrets: [
      STRIPE_SECRET_KEY,
      STRIPE_PRICE_ID_MONTHLY,
      STRIPE_PRICE_ID_ANNUAL,
      STRIPE_FOUNDER_PRICE_ID_UPFRONT,
    ],
  },
  async (request) => {
    // Verify authentication
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be logged in to subscribe");
    }

    const userId = request.auth.uid;
    const userEmail = request.auth.token.email;
    const { billingInterval, successUrl, cancelUrl } = request.data;

    logger.info(`createCheckoutSession called by user: ${userId} (${userEmail})`);

    // Determine which price to use (monthly or annual)
    const interval = billingInterval || "monthly"; // "monthly", "annual", or "founders_upfront"
    const isFoundersUpfront = interval === "founders_upfront";

    // Get Stripe secrets from Secret Manager with error handling
    let stripeSecretKey, priceIdMonthly, priceIdAnnual, priceIdFounders;
    
    try {
      stripeSecretKey = STRIPE_SECRET_KEY.value();
      priceIdMonthly = STRIPE_PRICE_ID_MONTHLY.value();
      priceIdAnnual = STRIPE_PRICE_ID_ANNUAL.value();
      priceIdFounders = STRIPE_FOUNDER_PRICE_ID_UPFRONT.value();
    } catch (secretError) {
      logger.error("createCheckoutSession: Stripe secrets not configured", {
        error: secretError.message,
        userId: userId
      });
      throw new HttpsError(
        "failed-precondition",
        "Payment system is not configured. Please contact support or try again later."
      );
    }
    
    if (!stripeSecretKey || stripeSecretKey.trim() === "") {
      logger.error("createCheckoutSession: STRIPE_SECRET_KEY is empty");
      throw new HttpsError(
        "failed-precondition",
        "Payment system is not configured. Please contact support."
      );
    }

    const priceId = isFoundersUpfront
      ? priceIdFounders
      : (interval === "annual" ? priceIdAnnual : priceIdMonthly);

    if (
      isFoundersUpfront &&
      (priceIdFounders === priceIdMonthly || priceIdFounders === priceIdAnnual)
    ) {
      logger.error("createCheckoutSession: Founders price ID misconfigured (matches monthly/annual)");
      throw new HttpsError(
        "failed-precondition",
        "Founders pricing is misconfigured. Please contact support."
      );
    }

    if (!priceId || priceId.trim() === "") {
      logger.error(`createCheckoutSession: Price ID not configured for ${interval} billing`);
      throw new HttpsError(
        "failed-precondition",
        `Subscription pricing is not configured for ${interval} billing. Please contact support.`
      );
    }

    try {
      // Initialize Stripe with secret key
      // Using basil API version (2023-10-16) - stable and well-tested
      const stripe = new Stripe(stripeSecretKey, {
        apiVersion: "2023-10-16", // Basil - stable version // Basil - stable version
      });
      
      logger.info("createCheckoutSession: Stripe initialized successfully");
      
      logger.info("createCheckoutSession: Stripe initialized successfully");

      const db = getFirestore();

      // Check if user already has a Stripe customer ID
      const userDoc = await db.collection("users").doc(userId).get();
      let customerId = userDoc.data()?.stripeCustomerId;

      // Create Stripe customer if doesn't exist
      if (!customerId) {
        const customer = await stripe.customers.create({
          email: userEmail,
          metadata: {
            firebaseUID: userId,
          },
        });
        customerId = customer.id;

        // Store customer ID in Firestore
        await db.collection("users").doc(userId).set(
          { stripeCustomerId: customerId },
          { merge: true }
        );
      }

      // Create checkout session
      const sessionPayload = {
        customer: customerId,
        payment_method_types: ["card"],
        line_items: [
          {
            price: priceId,
            quantity: 1,
          },
        ],
        mode: isFoundersUpfront ? "payment" : "subscription",
        success_url: successUrl || "https://arc-app.com/success?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: cancelUrl || "https://arc-app.com/cancel",
        metadata: {
          firebaseUID: userId,
          billingInterval: interval,
          planType: isFoundersUpfront ? "founders" : "premium",
        },
        allow_promotion_codes: true, // Enable discount codes
        billing_address_collection: "auto",
        customer_update: {
          address: "auto",
          name: "auto",
        },
      };

      if (isFoundersUpfront) {
        sessionPayload.payment_intent_data = {
          metadata: {
            firebaseUID: userId,
            billingInterval: interval,
            planType: "founders",
          },
        };
      } else {
        sessionPayload.subscription_data = {
          metadata: {
            firebaseUID: userId,
            billingInterval: interval,
            planType: "premium",
          },
        };
      }

      const session = await stripe.checkout.sessions.create(sessionPayload);

      // Log checkout attempt
      await db.collection("users").doc(userId).set(
        {
          lastCheckoutAttempt: new Date(),
          lastCheckoutInterval: interval,
        },
        { merge: true }
      );

      logger.info(`Created checkout session ${session.id} for user ${userId}`);

      return {
        sessionId: session.id,
        url: session.url,
      };

    } catch (error) {
      logger.error("Stripe checkout error:", error);
      throw new HttpsError("internal", `Payment initialization failed: ${error.message}`);
    }
  }
);

/**
 * Create Stripe Customer Portal Session for subscription management
 */
exports.createPortalSession = onCall(
  {
    cors: true,
    secrets: [STRIPE_SECRET_KEY],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }

    const userId = request.auth.uid;
    const { returnUrl } = request.data;

    logger.info(`createPortalSession called by user: ${userId}`);

    try {
      // Initialize Stripe
      const stripe = new Stripe(STRIPE_SECRET_KEY.value(), {
        apiVersion: "2023-10-16", // Basil - stable version
      });

      const db = getFirestore();

      const userDoc = await db.collection("users").doc(userId).get();
      const customerId = userDoc.data()?.stripeCustomerId;

      if (!customerId) {
        throw new HttpsError(
          "failed-precondition",
          "No subscription found for this user"
        );
      }

      // Create portal session - handles cancellation, payment method updates, billing history
      const portalSession = await stripe.billingPortal.sessions.create({
        customer: customerId,
        return_url: returnUrl || "https://arc-app.com/settings",
      });

      logger.info(`Created portal session for user ${userId}`);

      return { url: portalSession.url };

    } catch (error) {
      logger.error("Portal session error:", error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", `Could not create portal session: ${error.message}`);
    }
  }
);

/**
 * Stripe Webhook Handler with Signature Verification
 */
exports.stripeWebhook = onRequest(
  {
    cors: true,
    secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET],
  },
  async (req, res) => {
    const sig = req.headers["stripe-signature"];

    let event;

    try {
      // Initialize Stripe
      const stripe = new Stripe(STRIPE_SECRET_KEY.value(), {
        apiVersion: "2023-10-16", // Basil - stable version
      });

      // Verify webhook signature
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        sig,
        STRIPE_WEBHOOK_SECRET.value()
      );
    } catch (err) {
      logger.error("Webhook signature verification failed:", err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    logger.info(`Received webhook event: ${event.type}`);

    // Handle the event
    try {
      switch (event.type) {
        case "checkout.session.completed":
          await handleCheckoutComplete(event.data.object);
          break;

        case "customer.subscription.created":
        case "customer.subscription.updated":
          await handleSubscriptionUpdate(event.data.object);
          break;

        case "customer.subscription.deleted":
          await handleSubscriptionCanceled(event.data.object);
          break;

        case "invoice.payment_succeeded":
          await handlePaymentSucceeded(event.data.object);
          break;

        case "invoice.payment_failed":
          await handlePaymentFailed(event.data.object);
          break;

        default:
          logger.info(`Unhandled event type: ${event.type}`);
      }

      res.status(200).json({ received: true });

    } catch (error) {
      logger.error("Webhook handler error:", error);
      res.status(500).json({ error: "Webhook handler failed" });
    }
  }
);

/**
 * Handle successful checkout completion
 */
async function handleCheckoutComplete(session) {
  const customerId = session.customer;
  const subscriptionId = session.subscription;
  const isFoundersUpfront = session.mode === "payment" || session.metadata?.planType === "founders";

  logger.info(`Handling checkout complete for customer: ${customerId}`);

  const db = getFirestore();

  // Find user by Stripe customer ID
  const usersSnapshot = await db
    .collection("users")
    .where("stripeCustomerId", "==", customerId)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    logger.error("No user found for customer:", customerId);
    return;
  }

  const userDoc = usersSnapshot.docs[0];

  const updatePayload = {
    subscriptionTier: "premium",
    subscriptionStatus: isFoundersUpfront ? "founders" : "active",
    subscribedAt: new Date(),
    billingInterval: isFoundersUpfront ? "founders_upfront" : (session.metadata?.billingInterval || "monthly"),
  };

  if (!isFoundersUpfront && subscriptionId) {
    updatePayload.stripeSubscriptionId = subscriptionId;
  }

  if (isFoundersUpfront) {
    updatePayload.foundersCommit = true;
    updatePayload.foundersTermMonths = 36;
  }

  await userDoc.ref.update(updatePayload);

  logger.info(`User ${userDoc.id} upgraded to premium`);
}

/**
 * Handle subscription updates
 */
async function handleSubscriptionUpdate(subscription) {
  const customerId = subscription.customer;
  const status = subscription.status;
  const currentPeriodEnd = new Date(subscription.current_period_end * 1000);
  const billingInterval = subscription.metadata?.billingInterval ||
    (subscription.items?.data[0]?.price?.recurring?.interval === "year" ? "annual" : "monthly");

  logger.info(`Handling subscription update for customer: ${customerId}, status: ${status}`);

  const db = getFirestore();

  const usersSnapshot = await db
    .collection("users")
    .where("stripeCustomerId", "==", customerId)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    logger.error("No user found for customer:", customerId);
    return;
  }

  const userDoc = usersSnapshot.docs[0];

  // Map Stripe status to app tier
  const tier = ["active", "trialing"].includes(status) ? "premium" : "free";

  await userDoc.ref.update({
    subscriptionTier: tier,
    subscriptionStatus: status,
    billingInterval: billingInterval,
    currentPeriodEnd: currentPeriodEnd,
    stripeSubscriptionId: subscription.id,
  });

  logger.info(`Updated subscription for user ${userDoc.id}: tier=${tier}, status=${status}`);
}

/**
 * Handle subscription cancellation
 */
async function handleSubscriptionCanceled(subscription) {
  const customerId = subscription.customer;

  logger.info(`Handling subscription canceled for customer: ${customerId}`);

  const db = getFirestore();

  const usersSnapshot = await db
    .collection("users")
    .where("stripeCustomerId", "==", customerId)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    logger.error("No user found for customer:", customerId);
    return;
  }

  const userDoc = usersSnapshot.docs[0];

  await userDoc.ref.update({
    subscriptionTier: "free",
    subscriptionStatus: "canceled",
    canceledAt: new Date(),
  });

  logger.info(`User ${userDoc.id} subscription canceled`);
}

/**
 * Handle successful payment
 */
async function handlePaymentSucceeded(invoice) {
  const customerId = invoice.customer;

  logger.info(`Handling payment succeeded for customer: ${customerId}`);

  const db = getFirestore();

  const usersSnapshot = await db
    .collection("users")
    .where("stripeCustomerId", "==", customerId)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    logger.error("No user found for customer:", customerId);
    return;
  }

  const userDoc = usersSnapshot.docs[0];

  await userDoc.ref.update({
    lastPaymentAt: new Date(),
    lastPaymentStatus: "succeeded",
  });

  logger.info(`Payment succeeded for user ${userDoc.id}`);
}

/**
 * Handle failed payment
 */
async function handlePaymentFailed(invoice) {
  const customerId = invoice.customer;

  logger.info(`Handling payment failed for customer: ${customerId}`);

  const db = getFirestore();

  const usersSnapshot = await db
    .collection("users")
    .where("stripeCustomerId", "==", customerId)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    logger.error("No user found for customer:", customerId);
    return;
  }

  const userDoc = usersSnapshot.docs[0];

  await userDoc.ref.update({
    lastPaymentStatus: "failed",
    paymentFailedAt: new Date(),
  });

  logger.info(`Payment failed for user ${userDoc.id}`);
}