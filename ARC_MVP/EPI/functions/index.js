const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const https = require("https");
const { GoogleGenerativeAI } = require("@google/generative-ai");

const GROQ_REQUEST_TIMEOUT_MS = 85000; // Slightly under proxyGroq timeoutSeconds

/**
 * Sanitize API key from Secret Manager - removes newlines, carriage returns, BOM, extra whitespace.
 * Firebase secrets can have trailing newlines when set via interactive prompt.
 */
function sanitizeApiKey(raw) {
  if (typeof raw !== "string") return (raw || "").toString();
  return raw
    .replace(/\r\n/g, "")
    .replace(/\n/g, "")
    .replace(/\r/g, "")
    .replace(/\uFEFF/g, "") // BOM
    .trim();
}

/** Call Groq OpenAI-compatible API (non-streaming) with request timeout */
function groqChatCompletion(apiKey, body) {
  const completionPromise = new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request(
      {
        hostname: "api.groq.com",
        path: "/openai/v1/chat/completions",
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
          "Content-Length": Buffer.byteLength(data),
        },
      },
      (res) => {
        let buf = "";
        res.on("data", (chunk) => { buf += chunk; });
        res.on("end", () => {
          if (res.statusCode !== 200) {
            reject(new Error(`Groq API error: ${res.statusCode} - ${buf}`));
            return;
          }
          try {
            resolve(JSON.parse(buf));
          } catch (e) {
            reject(new Error("Invalid Groq response: " + buf));
          }
        });
      }
    );
    req.on("error", reject);
    req.write(data);
    req.end();
  });
  const timeoutPromise = new Promise((_, reject) => {
    setTimeout(() => reject(new Error("Groq API request timed out")), GROQ_REQUEST_TIMEOUT_MS);
  });
  return Promise.race([completionPromise, timeoutPromise]);
}
const Stripe = require("stripe");

// Initialize Firebase Admin
initializeApp();

// Define secrets
const ASSEMBLYAI_API_KEY = defineSecret("ASSEMBLYAI_API_KEY");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const GROQ_API_KEY = defineSecret("GROQ_API_KEY");
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
const STRIPE_PRICE_ID_MONTHLY = defineSecret("STRIPE_PRICE_ID_MONTHLY");
const STRIPE_PRICE_ID_ANNUAL = defineSecret("STRIPE_PRICE_ID_ANNUAL");
const STRIPE_FOUNDER_PRICE_ID_UPFRONT = defineSecret("STRIPE_FOUNDER_PRICE_ID_UPFRONT");

/**
 * Get user subscription tier
 * Returns premium for founder emails, checks Firestore for others
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

  // Founder/admin emails always get premium access
  const founderEmails = [
    'marcyap@orbitalai.net',
    'marcyap@fastmail.com',
    'tester1@tester1.com', // Apple TestFlight tester account
    // Add more founder/admin emails here
  ];

  const isFounder = founderEmails.includes(email?.toLowerCase());

  let tier = 'free';
  
  if (isFounder) {
    // Founders always get premium
    tier = 'premium';
    console.log(`User ${email} is a founder - granting premium access`);
  } else {
    // Check user's subscription status from Firestore
    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();

    if (userDoc.exists) {
      const userData = userDoc.data();
      // Check if user has active Stripe subscription
      if (userData.stripeSubscriptionId &&
          userData.subscriptionStatus === 'active' &&
          userData.subscriptionTier === 'premium') {
        tier = 'premium';
      }
    }
  }

  console.log(`Returning subscription tier: ${tier} for ${email}`);

  return {
    tier: tier,
    uid: uid,
    email: email,
    isFounder: isFounder,
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
    'marcyap@fastmail.com',
    'tester1@tester1.com', // Apple TestFlight tester account
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

/** Free-tier daily LUMARA call limit (enforced server-side) */
const FREE_TIER_DAILY_LUMARA_LIMIT = 50;

/**
 * Proxy Gemini API calls - hides API key from client.
 * Rate limiting: free-tier users are limited to FREE_TIER_DAILY_LUMARA_LIMIT calls per day (enforced here).
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

    // Rate limiting for free-tier users (server-side enforcement)
    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.exists ? userDoc.data() : {};

    // Founder/admin emails are always exempt from rate limiting
    const exemptEmails = [
      'marcyap@orbitalai.net',
      'marcyap@fastmail.com',
      'tester1@tester1.com',
    ];
    const isExemptEmail = email && exemptEmails.includes(email.toLowerCase());

    // Check premium status: active Stripe subscription, or "pro" plan, or "PAID" tier
    const hasActivePremium = (
      (userData.subscriptionTier === "premium" && userData.subscriptionStatus === "active") ||
      userData.plan === "pro" ||
      userData.subscriptionTier === "PAID"
    );

    const tier = (isExemptEmail || hasActivePremium) ? "premium" : "free";
    if (tier === "free") {
      const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
      const usage = userData.lumaraDailyUsage || {};
      if (usage.date === today && (usage.count || 0) >= FREE_TIER_DAILY_LUMARA_LIMIT) {
        console.log(`proxyGemini: Free-tier daily limit reached for user ${uid}`);
        throw new HttpsError(
          "resource-exhausted",
          `Daily limit of ${FREE_TIER_DAILY_LUMARA_LIMIT} LUMARA requests reached. Upgrade to premium for unlimited use.`
        );
      }
      const newCount = usage.date === today ? (usage.count || 0) + 1 : 1;
      await userRef.set(
        { lumaraDailyUsage: { date: today, count: newCount } },
        { merge: true }
      );
    }

    // Debug logging for parameter validation
    console.log('proxyGemini: Received data:', {
      hasSystem: system != null,
      hasUser: user != null,
      systemType: typeof system,
      userType: typeof user,
      systemLength: typeof system === 'string' ? system.length : 'N/A',
      userLength: typeof user === 'string' ? user.length : 'N/A',
    });

    // Allow empty string for user (when all content is in system prompt)
    // But require that parameters are provided (not null/undefined)
    if (system == null || user == null) {
      console.error('proxyGemini: Missing parameters', { system: system == null, user: user == null });
      throw new HttpsError("invalid-argument", "system and user parameters are required");
    }
    
    // Convert to string if needed (handles correlation-resistant transformation objects)
    const systemStr = typeof system === 'string' ? system : JSON.stringify(system);
    const userStr = typeof user === 'string' ? user : JSON.stringify(user);
    
    // Ensure at least one has content (allow empty user if system has content)
    if (systemStr.trim().length === 0 && userStr.trim().length === 0) {
      throw new HttpsError("invalid-argument", "At least one of system or user must have content");
    }

    console.log(`proxyGemini called by user: ${uid} (${email})`);

    try {
      const apiKey = GEMINI_API_KEY.value();
      if (!apiKey) {
        throw new HttpsError("internal", "Cloud AI (Gemini fallback) API key not configured");
      }

      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: "gemini-3-flash-preview",
        tools: [{ googleSearch: {} }], // Enable Google Search for internet access
        generationConfig: jsonExpected
          ? { responseMimeType: "application/json" }
          : undefined,
      });

      // Use startChat for proper tool support (googleSearch)
      const chat = model.startChat({
        history: systemStr.trim().length > 0
          ? [
              { role: "user", parts: [{ text: systemStr }] },
              { role: "model", parts: [{ text: "Ok." }] },
            ]
          : [],
      });

      const result = await chat.sendMessage(userStr);
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
 * Proxy Groq API calls - hides API key from client (Llama 3.3 70B / Mixtral)
 */
exports.proxyGroq = onCall(
  {
    cors: true,
    secrets: [GROQ_API_KEY],
    timeoutSeconds: 90,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    // Fast warm-up path: client sends { _ping: true } at app startup to
    // establish the TCP connection (iOS GTMSessionFetcher). No Groq call.
    if (request.data?._ping) {
      return { ok: true, ts: Date.now() };
    }

    const { system, user, model, temperature, maxTokens, entryId, chatId } = request.data || {};
    const uid = request.auth.uid;
    const email = request.auth.token.email;

    if (user == null) {
      throw new HttpsError("invalid-argument", "user is required");
    }
    const systemStr = typeof system === "string" ? system : (system != null ? JSON.stringify(system) : "");
    const userStr = typeof user === "string" ? user : JSON.stringify(user);
    if (userStr.trim().length === 0) {
      throw new HttpsError("invalid-argument", "user must have content");
    }

    let apiKey = GROQ_API_KEY.value();
    if (!apiKey) {
      throw new HttpsError("internal", "Groq API key not configured");
    }
    const rawLen = apiKey.length;
    const hadNewlines = /\r|\n/.test(apiKey);
    apiKey = sanitizeApiKey(apiKey);
    const cleanLen = apiKey.length;
    // Safe debug: diagnose storage/format issues (never log actual key)
    console.log(`proxyGroq: key rawLen=${rawLen} cleanLen=${cleanLen} hadNewlines=${hadNewlines} startsWithGsk=${apiKey.startsWith("gsk_")}`);
    if (!apiKey) {
      throw new HttpsError("internal", "Groq API key not configured");
    }

    const allowedModels = ['openai/gpt-oss-20b', 'openai/gpt-oss-120b', 'llama-3.3-70b-versatile'];
    const modelId = (typeof model === 'string' && allowedModels.includes(model)) ? model : 'openai/gpt-oss-120b';
    const messages = [];
    if (systemStr.trim().length > 0) {
      messages.push({ role: "system", content: systemStr });
    }
    messages.push({ role: "user", content: userStr });

    const body = {
      model: modelId,
      messages,
      temperature: typeof temperature === "number" ? temperature : 0.7,
      stream: false,
    };
    if (typeof maxTokens === "number" && maxTokens > 0) {
      body.max_tokens = maxTokens;
    }

    try {
      const result = await groqChatCompletion(apiKey, body);
      const choices = result.choices;
      const content = choices?.[0]?.message?.content;
      if (content == null) {
        throw new HttpsError("internal", "Groq API returned no content");
      }
      console.log(`proxyGroq: Successfully generated response for ${email}`);
      return { response: content, usage: result.usage || null };
    } catch (error) {
      console.error("proxyGroq error:", error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", `Groq API error: ${error.message || "Unknown error"}`);
    }
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
    timeoutSeconds: 60, // Increase timeout to 60 seconds
    // invoker is set manually in Cloud Console to avoid IAM conflicts
  },
  async (request) => {
    // Debug logging for auth context
    console.log('createCheckoutSession: Received request');
    console.log('createCheckoutSession: request.auth =', request.auth ? 'present' : 'null');
    console.log('createCheckoutSession: request.rawRequest.headers.authorization =', 
      request.rawRequest?.headers?.authorization ? 'present' : 'missing');
    
    // Verify authentication
    if (!request.auth) {
      console.log('createCheckoutSession: AUTH FAILED - request.auth is null');
      console.log('createCheckoutSession: Full request keys:', Object.keys(request));
      throw new HttpsError("unauthenticated", "User must be logged in to subscribe");
    }

    const userId = request.auth.uid;
    const userEmail = request.auth.token.email;
    const { billingInterval, successUrl, cancelUrl } = request.data;

    console.log(`createCheckoutSession called by user: ${userId} (${userEmail})`);

    // Determine which price to use (monthly or annual)
    const interval = billingInterval || "monthly"; // "monthly", "annual", or "founders_upfront"
    const isFoundersUpfront = interval === "founders_upfront";

    // Get price IDs from Firebase Secret Manager with error handling
    let priceIdMonthly, priceIdAnnual, priceIdFounders, stripeSecretKey;
    try {
      priceIdMonthly = STRIPE_PRICE_ID_MONTHLY.value();
      priceIdAnnual = STRIPE_PRICE_ID_ANNUAL.value();
      priceIdFounders = STRIPE_FOUNDER_PRICE_ID_UPFRONT.value();
      stripeSecretKey = STRIPE_SECRET_KEY.value();
      
      console.log('createCheckoutSession: Secrets retrieved successfully');
      console.log('createCheckoutSession: priceIdMonthly length:', priceIdMonthly?.length || 0);
      console.log('createCheckoutSession: priceIdAnnual length:', priceIdAnnual?.length || 0);
      console.log('createCheckoutSession: stripeSecretKey length:', stripeSecretKey?.length || 0);
    } catch (secretError) {
      console.error('createCheckoutSession: Error accessing secrets:', secretError);
      throw new HttpsError(
        "failed-precondition",
        `Stripe configuration error: ${secretError.message || "Unable to access Stripe secrets"}`
      );
    }

    const priceId = isFoundersUpfront
      ? priceIdFounders
      : (interval === "annual" ? priceIdAnnual : priceIdMonthly);

    if (
      isFoundersUpfront &&
      (priceIdFounders === priceIdMonthly || priceIdFounders === priceIdAnnual)
    ) {
      console.error('createCheckoutSession: Founders price ID misconfigured (matches monthly/annual)');
      throw new HttpsError(
        "failed-precondition",
        "Founders pricing is misconfigured. Please contact support."
      );
    }

    if (!priceId || !priceId.trim()) {
      console.error(`createCheckoutSession: Price ID missing for ${interval} billing`);
      throw new HttpsError(
        "failed-precondition",
        `Price ID not configured for ${interval} billing`
      );
    }

    if (!stripeSecretKey || !stripeSecretKey.trim()) {
      console.error('createCheckoutSession: Stripe secret key missing');
      throw new HttpsError(
        "failed-precondition",
        "Stripe secret key not configured"
      );
    }

    try {
      // Initialize Stripe with secret key
      const stripe = new Stripe(stripeSecretKey, {
        apiVersion: "2023-10-16",
      });
      
      console.log('createCheckoutSession: Stripe client initialized');

      const db = getFirestore();

      // Check if user already has a Stripe customer ID
      const userDoc = await db.collection("users").doc(userId).get();
      let customerId = userDoc.data()?.stripeCustomerId;

      // Check if existing customer ID is from test mode - if so, ignore it
      if (customerId) {
        try {
          // Try to retrieve the customer to see if it exists in live mode
          await stripe.customers.retrieve(customerId);
          console.log(`createCheckoutSession: Using existing customer ${customerId}`);
        } catch (error) {
          if (error.type === 'StripeInvalidRequestError' && error.code === 'resource_missing') {
            console.log(`createCheckoutSession: Customer ${customerId} doesn't exist in live mode, creating new one`);
            customerId = null; // Force creation of new customer

            // Clean up the invalid customer ID from Firestore
            await userDoc.ref.update({
              stripeCustomerId: FieldValue.delete(),
            });
          } else {
            throw error; // Re-throw other Stripe errors
          }
        }
      }

      // Create Stripe customer if doesn't exist or invalid
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
        success_url: successUrl || "https://arc-app.com/subscription/success?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: cancelUrl || "https://arc-app.com/subscription/cancel",
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
      console.log('createCheckoutSession: session.url =', session.url ? 'present' : 'missing');

      if (!session.url) {
        throw new HttpsError(
          "internal",
          "Stripe checkout URL missing. Please contact support."
        );
      }

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
        checkoutUrl: session.url,
      };

    } catch (error) {
      console.error("Stripe checkout error:", error);
      console.error("Stripe checkout error details:", {
        message: error.message,
        type: error.type,
        code: error.code,
        statusCode: error.statusCode,
        stack: error.stack?.substring(0, 500),
      });
      
      // Provide more specific error messages
      if (error.type === 'StripeInvalidRequestError') {
        throw new HttpsError(
          "invalid-argument",
          `Stripe configuration error: ${error.message || "Invalid request"}`
        );
      } else if (error.type === 'StripeAPIError') {
        throw new HttpsError(
          "unavailable",
          `Stripe service error: ${error.message || "Stripe API unavailable"}`
        );
      } else if (error.message?.includes('secret')) {
        throw new HttpsError(
          "failed-precondition",
          `Configuration error: ${error.message}`
        );
      }
      
      throw new HttpsError(
        "internal",
        `Payment initialization failed: ${error.message || "Unknown error"}`
      );
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
 * Debug function to clean up test mode customer IDs
 * This can be called once to fix the test/live mode mismatch
 */
exports.cleanupTestCustomers = onCall(
  {
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const uid = request.auth.uid;
    const email = request.auth.token.email;

    console.log(`cleanupTestCustomers called by: ${uid} (${email})`);

    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();

    if (userDoc.exists) {
      const userData = userDoc.data();
      const currentCustomerId = userData.stripeCustomerId;

      if (currentCustomerId && currentCustomerId.includes('test')) {
        // Remove test mode customer ID
        await userRef.update({
          stripeCustomerId: FieldValue.delete(),
        });

        console.log(`Removed test customer ID ${currentCustomerId} for user ${uid}`);
        return {
          success: true,
          message: `Removed test customer ID: ${currentCustomerId}`,
          oldCustomerId: currentCustomerId
        };
      } else if (currentCustomerId && currentCustomerId.startsWith('cus_')) {
        // Check if this looks like a test customer that doesn't have 'test' in the ID
        // Test customer from logs: cus_TlbOUtqkQoy0Bo
        await userRef.update({
          stripeCustomerId: FieldValue.delete(),
        });

        console.log(`Removed potentially test customer ID ${currentCustomerId} for user ${uid}`);
        return {
          success: true,
          message: `Removed customer ID to allow fresh creation: ${currentCustomerId}`,
          oldCustomerId: currentCustomerId
        };
      } else {
        return {
          success: false,
          message: "No customer ID found to clean up",
          currentCustomerId: currentCustomerId
        };
      }
    } else {
      return {
        success: false,
        message: "User document not found"
      };
    }
  }
);

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
// invoker left default (private) so deploy works without roles/functions.admin.
// To allow public access: Cloud Console → Functions → healthCheck → Permissions → Add principal "allUsers" → Cloud Functions Invoker
exports.healthCheck = onRequest(
  { cors: true },
  async (req, res) => {
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      functions: ['getUserSubscription', 'getAssemblyAIToken', 'proxyGemini', 'proxyGroq', 'createCheckoutSession', 'createPortalSession', 'stripeWebhook']
    });
  }
);