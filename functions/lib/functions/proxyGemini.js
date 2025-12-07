"use strict";
// functions/proxyGemini.ts - Simple API key proxy for Gemini calls
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.proxyGemini = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const config_1 = require("../config");
const https = __importStar(require("https"));
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
exports.proxyGemini = (0, https_1.onCall)({
    secrets: [config_1.GEMINI_API_KEY],
    invoker: "public", // Allow calls for MVP testing
}, async (request) => {
    const { model = "gemini-2.5-flash", systemInstruction, contents, generationConfig, tools, } = request.data;
    if (!contents || !Array.isArray(contents)) {
        throw new https_1.HttpsError("invalid-argument", "contents array is required");
    }
    const userId = request.auth?.uid || `mvp_test_${Date.now()}`;
    firebase_functions_1.logger.info(`Proxying Gemini request for user ${userId}, model: ${model}`);
    try {
        const apiKey = config_1.GEMINI_API_KEY.value();
        // Build Gemini API request
        const requestBody = {
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
        const geminiResponse = await callGeminiAPI(model, apiKey, requestBody);
        firebase_functions_1.logger.info(`Gemini proxy successful for user ${userId}`);
        return {
            candidates: geminiResponse.candidates,
            usageMetadata: geminiResponse.usageMetadata,
        };
    }
    catch (error) {
        firebase_functions_1.logger.error(`Gemini proxy error: ${error.message}`);
        if (error.status === 429) {
            throw new https_1.HttpsError("resource-exhausted", "Rate limit exceeded. Please try again later.");
        }
        throw new https_1.HttpsError("internal", `Gemini API error: ${error.message}`);
    }
});
/**
 * Call Gemini API directly
 */
function callGeminiAPI(model, apiKey, requestBody) {
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
                    }
                    catch (e) {
                        reject(new Error(`Failed to parse Gemini response: ${e}`));
                    }
                }
                else {
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
//# sourceMappingURL=proxyGemini.js.map