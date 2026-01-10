const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const https = require("https");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const Stripe = require("stripe");

// Initialize Firebase Admin
initializeApp();

// Define secrets
const ASSEMBLYAI_API_KEY = defineSecret("ASSEMBLYAI_API_KEY");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
const STRIPE_PRICE_ID_MONTHLY = defineSecret("STRIPE_PRICE_ID_MONTHLY");
const STRIPE_PRICE_ID_ANNUAL = defineSecret("STRIPE_PRICE_ID_ANNUAL");

/**
 * Get user subscription tier
 * Returns premium for marcyap@orbitalai.net, free for others
 */
exports.getUserSubscription = onCall(
  {
    // Allow authenticated users to invoke this function
    // For callable functions, this should allow Firebase Auth users
    cors: true,
  },
  async (request) => {
  // Verify authentication
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email;

  console.log(`getUserSubscription called by user: ${uid} (${email})`);

  // Premium users - add more emails here as needed
  const premiumEmails = [
    'marcyap@orbitalai.net',
    // Add more premium emails here
  ];

  // Check if user has premium access
  const tier = premiumEmails.includes(email) ? 'premium' : 'free';

  console.log(`Returning subscription tier: ${tier} for ${email}`);

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
 * Get AssemblyAI token for cloud transcription
 * Returns test token for development - replace with real AssemblyAI token generation
 */
exports.getAssemblyAIToken = onCall(
  {
    // Allow authenticated users to invoke this function
    cors: true,
    secrets: [ASSEMBLYAI_API_KEY],
  },
  async (request) => {
  // Verify authentication
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email;

  console.log(`getAssemblyAIToken called by user: ${uid} (${email})`);

  // Premium users get cloud transcription
  const premiumEmails = [
    'marcyap@orbitalai.net',
    // Add more premium emails here
  ];

  const isPremium = premiumEmails.includes(email);

  if (!isPremium) {
    console.log(`User ${email} is not premium, denying AssemblyAI access`);
    return {
      eligibleForCloud: false,
      tier: 'free',
      message: 'Upgrade to premium for cloud transcription'
    };
  }

  // For premium users, return the AssemblyAI API key
  // Universal Streaming v3 accepts the API key directly as a token query parameter
  const apiKey = ASSEMBLYAI_API_KEY.value().trim();
  
  if (!apiKey || apiKey.length === 0) {
    console.error('ASSEMBLYAI_API_KEY not configured');
    throw new HttpsError(
      'failed-precondition',
      'AssemblyAI is not configured. Please contact support.'
    );
  }
  
  const expiresAt = Date.now() + (60 * 60 * 1000); // 1 hour from now

  console.log(`Returning AssemblyAI API key for premium user: ${email} (key length: ${apiKey.length})`);

  return {
    token: apiKey,
    expiresAt: expiresAt,
    tier: 'premium',
    eligibleForCloud: true,
    uid: uid
  };
  }
);

/**
 * Proxy Gemini API calls - hides API key from client
 */
exports.proxyGemini = onCall(
  {
    cors: true,
    secrets: [GEMINI_API_KEY],
  },
  async (request) => {
    // Verify authentication
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const { system, user, jsonExpected } = request.data;
    const uid = request.auth.uid;
    const email = request.auth.token.email;

    if (!system || !user) {
      throw new HttpsError("invalid-argument", "system and user parameters are required");
    }

    console.log(`proxyGemini called by user: ${uid} (${email})`);

    try {
      const apiKey = GEMINI_API_KEY.value();
      if (!apiKey) {
        throw new HttpsError("internal", "Gemini API key not configured");
      }

      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash-exp",
        tools: [{ googleSearch: {} }], // Enable Google Search for internet access
        generationConfig: jsonExpected
          ? { responseMimeType: "application/json" }
          : undefined,
      });

      // Use startChat for proper tool support (googleSearch)
      const chat = model.startChat({
        history: system
          ? [
              { role: "user", parts: [{ text: system }] },
              { role: "model", parts: [{ text: "Ok." }] },
            ]
          : [],
      });

      const result = await chat.sendMessage(user);
      const response = result.response;
      const text = response.text();

      console.log(`proxyGemini: Successfully generated response for ${email}`);

      if (jsonExpected) {
        try {
          const jsonData = JSON.parse(text);
          return { response: jsonData };
        } catch (e) {
          return { response: text };
        }
      }

      return { response: text };
    } catch (error) {
      console.error('proxyGemini error:', error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", `Gemini API error: ${error.message || "Unknown error"}`);
    }
  }
);

/**
 * Create Stripe Checkout Session for subscription
 */
exports.createCheckoutSession = onCall(
  {
    cors: true,
    secrets: [STRIPE_SECRET_KEY, STRIPE_PRICE_ID_MONTHLY, STRIPE_PRICE_ID_ANNUAL],
  },
  async (request) => {
    // Verify authentication
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be logged in to subscribe");
    }

    const userId = request.auth.uid;
    const userEmail = request.auth.token.email;
    const { billingInterval, successUrl, cancelUrl } = request.data;

    console.log(`createCheckoutSession called by user: ${userId} (${userEmail})`);

    // Determine which price to use (monthly or annual)
    const interval = billingInterval || "monthly"; // "monthly" or "annual"

    // Get price IDs from Firebase Secret Manager
    const priceIdMonthly = STRIPE_PRICE_ID_MONTHLY.value();
    const priceIdAnnual = STRIPE_PRICE_ID_ANNUAL.value();

    const priceId = interval === "annual" ? priceIdAnnual : priceIdMonthly;

    if (!priceId) {
      throw new HttpsError(
        "failed-precondition",
        `Price ID not configured for ${interval} billing`
      );
    }

    try {
      // Initialize Stripe with secret key
      const stripe = new Stripe(STRIPE_SECRET_KEY.value(), {
        apiVersion: "2023-10-16",
      });

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
      const session = await stripe.checkout.sessions.create({
        customer: customerId,
        payment_method_types: ["card"],
        line_items: [
          {
            price: priceId,
            quantity: 1,
          },
        ],
        mode: "subscription",
        success_url: successUrl || "https://arc-app.com/success?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: cancelUrl || "https://arc-app.com/cancel",
        subscription_data: {
          metadata: {
            firebaseUID: userId,
            billingInterval: interval,
          },
        },
        allow_promotion_codes: true, // Enable discount codes
        billing_address_collection: "auto",
        customer_update: {
          address: "auto",
          name: "auto",
        },
      });

      // Log checkout attempt
      await db.collection("users").doc(userId).set(
        {
          lastCheckoutAttempt: new Date(),
          lastCheckoutInterval: interval,
        },
        { merge: true }
      );

      console.log(`Created checkout session ${session.id} for user ${userId}`);

      return {
        sessionId: session.id,
        url: session.url,
      };

    } catch (error) {
      console.error("Stripe checkout error:", error);
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
    invoker: "private", // Only authenticated users can invoke
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }

    const userId = request.auth.uid;
    const { returnUrl } = request.data;

    console.log(`createPortalSession called by user: ${userId}`);

    try {
      // Initialize Stripe
      const stripe = new Stripe(STRIPE_SECRET_KEY.value(), {
        apiVersion: "2023-10-16",
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

      console.log(`Created portal session for user ${userId}`);

      return { url: portalSession.url };

    } catch (error) {
      console.error("Portal session error:", error);
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
        apiVersion: "2023-10-16",
      });

      // Verify webhook signature
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        sig,
        STRIPE_WEBHOOK_SECRET.value()
      );
    } catch (err) {
      console.error("Webhook signature verification failed:", err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    console.log(`Received webhook event: ${event.type}`);

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
          console.log(`Unhandled event type: ${event.type}`);
      }

      res.status(200).json({ received: true });

    } catch (error) {
      console.error("Webhook handler error:", error);
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

  console.log(`Handling checkout complete for customer: ${customerId}`);

  const db = getFirestore();

  // Find user by Stripe customer ID
  const usersSnapshot = await db
    .collection("users")
    .where("stripeCustomerId", "==", customerId)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.error("No user found for customer:", customerId);
    return;
  }

  const userDoc = usersSnapshot.docs[0];

  await userDoc.ref.update({
    subscriptionTier: "premium",
    subscriptionStatus: "active",
    stripeSubscriptionId: subscriptionId,
    subscribedAt: new Date(),
  });

  console.log(`User ${userDoc.id} upgraded to premium`);
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

  console.log(`Handling subscription update for customer: ${customerId}, status: ${status}`);

  const db = getFirestore();

  const usersSnapshot = await db
    .collection("users")
    .where("stripeCustomerId", "==", customerId)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.error("No user found for customer:", customerId);
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

  console.log(`Updated subscription for user ${userDoc.id}: tier=${tier}, status=${status}`);
}

/**
 * Handle subscription cancellation
 */
async function handleSubscriptionCanceled(subscription) {
  const customerId = subscription.customer;

  console.log(`Handling subscription canceled for customer: ${customerId}`);

  const db = getFirestore();

  const usersSnapshot = await db
    .collection("users")
    .where("stripeCustomerId", "==", customerId)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.error("No user found for customer:", customerId);
    return;
  }

  const userDoc = usersSnapshot.docs[0];

  await userDoc.ref.update({
    subscriptionTier: "free",
    subscriptionStatus: "canceled",
    canceledAt: new Date(),
  });

  console.log(`User ${userDoc.id} subscription canceled`);
}

/**
 * Handle successful payment
 */
async function handlePaymentSucceeded(invoice) {
  const customerId = invoice.customer;

  console.log(`Handling payment succeeded for customer: ${customerId}`);

  const db = getFirestore();

  const usersSnapshot = await db
    .collection("users")
    .where("stripeCustomerId", "==", customerId)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.error("No user found for customer:", customerId);
    return;
  }

  const userDoc = usersSnapshot.docs[0];

  await userDoc.ref.update({
    lastPaymentAt: new Date(),
    lastPaymentStatus: "succeeded",
  });

  console.log(`Payment succeeded for user ${userDoc.id}`);
}

/**
 * Handle failed payment
 */
async function handlePaymentFailed(invoice) {
  const customerId = invoice.customer;

  console.log(`Handling payment failed for customer: ${customerId}`);

  const db = getFirestore();

  const usersSnapshot = await db
    .collection("users")
    .where("stripeCustomerId", "==", customerId)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.error("No user found for customer:", customerId);
    return;
  }

  const userDoc = usersSnapshot.docs[0];

  await userDoc.ref.update({
    lastPaymentStatus: "failed",
    paymentFailedAt: new Date(),
  });

  console.log(`Payment failed for user ${userDoc.id}`);
}

/**
 * Health check function
 */
exports.healthCheck = onRequest(
  {
    cors: true,
    invoker: "public", // Anyone can access health check
  },
  async (req, res) => {
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      functions: ['getUserSubscription', 'getAssemblyAIToken', 'proxyGemini', 'createCheckoutSession', 'createPortalSession', 'stripeWebhook']
    });
  }
);