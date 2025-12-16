const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const https = require("https");
const { GoogleGenerativeAI } = require("@google/generative-ai");

// Initialize Firebase Admin
initializeApp();

// Define secrets
const ASSEMBLYAI_API_KEY = defineSecret("ASSEMBLYAI_API_KEY");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

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
 * Health check function
 */
exports.healthCheck = onRequest(async (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    functions: ['getUserSubscription', 'getAssemblyAIToken', 'proxyGemini']
  });
});