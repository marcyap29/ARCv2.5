// functions/index.js

const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { defineSecret } = require("firebase-functions/params");
const cors = require("cors")({ origin: true });

// Export new Gemini proxy function
exports.proxyGemini = require("./lib/functions/proxyGemini").proxyGemini;

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