// functions/index.js

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { defineSecret } = require("firebase-functions/params");
const cors = require("cors")({ origin: true });
const { GoogleGenerativeAI } = require("@google/generative-ai");

// Define secrets
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

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
        model: "gemini-2.5-flash",
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