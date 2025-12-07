// functions/proxyGemini.ts - Simple API key proxy for Gemini calls

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { GEMINI_API_KEY } from "../config";
import * as https from "https";

/**
 * Simple proxy to hide Gemini API key from client
 * 
 * This function just:
 * 1. Accepts prompt + conversation history from client
 * 2. Adds the secret API key
 * 3. Forwards to Gemini API
 * 4. Returns the response
 * 
 * All LUMARA logic runs on the client (has access to local journals)
 */
export const proxyGemini = onCall(
  {
    secrets: [GEMINI_API_KEY],
    invoker: "public", // Allow calls for MVP testing
  },
  async (request) => {
    const {
      model = "gemini-2.5-flash",
      systemInstruction,
      contents,
      generationConfig,
      tools,
    } = request.data;

    if (!contents || !Array.isArray(contents)) {
      throw new HttpsError(
        "invalid-argument",
        "contents array is required"
      );
    }

    const userId = request.auth?.uid || `mvp_test_${Date.now()}`;
    logger.info(`Proxying Gemini request for user ${userId}, model: ${model}`);

    try {
      const apiKey = GEMINI_API_KEY.value();
      
      // Build Gemini API request
      const requestBody: any = {
        contents,
        generationConfig: generationConfig || {
          temperature: 0.7,
          maxOutputTokens: 8192,
        },
      };

      if (systemInstruction) {
        requestBody.systemInstruction = {
          parts: [{ text: systemInstruction }],
        };
      }

      if (tools) {
        requestBody.tools = tools;
      }

      // Call Gemini API
      const geminiResponse = await callGeminiAPI(
        model,
        apiKey,
        requestBody
      );

      logger.info(`Gemini proxy successful for user ${userId}`);

      return {
        candidates: geminiResponse.candidates,
        usageMetadata: geminiResponse.usageMetadata,
      };
    } catch (error: any) {
      logger.error(`Gemini proxy error: ${error.message}`);
      
      if (error.status === 429) {
        throw new HttpsError(
          "resource-exhausted",
          "Rate limit exceeded. Please try again later."
        );
      }
      
      throw new HttpsError(
        "internal",
        `Gemini API error: ${error.message}`
      );
    }
  }
);

/**
 * Call Gemini API directly
 */
function callGeminiAPI(
  model: string,
  apiKey: string,
  requestBody: any
): Promise<any> {
  return new Promise((resolve, reject) => {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    const parsedUrl = new URL(url);

    const options = {
      hostname: parsedUrl.hostname,
      path: parsedUrl.pathname + parsedUrl.search,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
    };

    const req = https.request(options, (res) => {
      let data = "";

      res.on("data", (chunk) => {
        data += chunk;
      });

      res.on("end", () => {
        if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
          try {
            const parsed = JSON.parse(data);
            resolve(parsed);
          } catch (e) {
            reject(new Error(`Failed to parse Gemini response: ${e}`));
          }
        } else {
          reject({
            status: res.statusCode,
            message: data,
          });
        }
      });
    });

    req.on("error", (error) => {
      reject(error);
    });

    req.write(JSON.stringify(requestBody));
    req.end();
  });
}

