"use strict";
// functions/sendChatMessage.ts - Chat message Cloud Function
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendChatMessage = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const admin_1 = require("../admin");
const modelRouter_1 = require("../modelRouter");
const quotaGuards_1 = require("../quotaGuards");
const rateLimiter_1 = require("../rateLimiter");
const llmClients_1 = require("../llmClients");
const config_1 = require("../config");
const db = admin_1.admin.firestore();
/**
 * Send a chat message
 *
 * Flow:
 * 1. Verify Firebase Auth token (automatic via onCall)
 * 2. Load user and thread from Firestore
 * 3. Check quota (free tier: max 200 messages per thread)
 * 4. Route to appropriate model (FREE: Gemini Flash, PAID: Gemini Pro)
 * 5. Generate response using LLM
 * 6. Append message to thread
 * 7. Increment message count
 * 8. Return updated thread
 *
 * API Shape (preserved for frontend compatibility):
 * httpsCallable('sendChatMessage')
 *
 * Request: { threadId: string, message: string }
 * Response: { threadId, message, messageCount }
 * Note: modelUsed is internal only, not exposed to users
 */
exports.sendChatMessage = (0, https_1.onCall)({
    secrets: [config_1.GEMINI_API_KEY, config_1.ANTHROPIC_API_KEY],
}, async (request) => {
    const { threadId, message } = request.data;
    // Validate request
    if (!threadId || !message) {
        throw new https_1.HttpsError("invalid-argument", "threadId and message are required");
    }
    const userId = request.auth?.uid;
    if (!userId) {
        throw new https_1.HttpsError("unauthenticated", "User must be authenticated");
    }
    firebase_functions_1.logger.info(`Sending chat message in thread ${threadId} for user ${userId}`);
    try {
        // Load user document
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) {
            throw new https_1.HttpsError("not-found", "User not found");
        }
        const user = userDoc.data();
        // Support both 'plan' and 'subscriptionTier' fields
        const plan = user.plan || user.subscriptionTier?.toLowerCase() || "free";
        const tier = (plan === "pro" ? "PAID" : "FREE");
        // Check rate limit (primary quota enforcement)
        const rateLimitCheck = await (0, rateLimiter_1.checkRateLimit)(userId);
        if (!rateLimitCheck.allowed) {
            throw new https_1.HttpsError("resource-exhausted", rateLimitCheck.error?.message || "Rate limit exceeded", rateLimitCheck.error);
        }
        // Check legacy per-thread quota (secondary, for backward compatibility)
        const quotaCheck = await (0, quotaGuards_1.checkCanSendMessage)(userId, threadId);
        if (!quotaCheck.allowed) {
            throw new https_1.HttpsError("resource-exhausted", quotaCheck.error?.message || "Quota limit reached", quotaCheck.error);
        }
        // Load or create thread
        const threadRef = db.collection("chatThreads").doc(threadId);
        const threadDoc = await threadRef.get();
        let thread;
        let conversationHistory = [];
        if (threadDoc.exists) {
            thread = threadDoc.data();
            // Build conversation history from existing messages
            conversationHistory = (thread.messages || []).map((msg) => ({
                role: msg.role,
                content: msg.content,
            }));
        }
        else {
            // Create new thread
            thread = {
                userId,
                messageCount: 0,
                messages: [],
                createdAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
            };
            await threadRef.set(thread);
        }
        // Select model (internal only - Gemini by default)
        const modelFamily = await modelRouter_1.ModelRouter.selectModelWithFailover(tier, "chat_message");
        const modelConfig = modelRouter_1.ModelRouter.getConfig(modelFamily);
        const client = (0, llmClients_1.createLLMClient)(modelConfig);
        firebase_functions_1.logger.info(`Using model: ${modelFamily} (${modelConfig.modelId}) - Internal only, not exposed to user`);
        // Build system prompt
        const systemPrompt = `You are LUMARA, a thoughtful and empathetic AI companion for journaling and reflection. 
You help users explore their thoughts, feelings, and experiences with curiosity and compassion.
Be concise, insightful, and supportive.`;
        // Generate response
        let assistantResponse;
        if (modelConfig.family === "GEMINI_FLASH" || modelConfig.family === "GEMINI_PRO") {
            // Use Gemini client
            const geminiClient = client;
            assistantResponse = await geminiClient.generateContent(message, systemPrompt, conversationHistory);
        }
        else {
            // Use Claude client
            const claudeClient = client;
            assistantResponse = await claudeClient.generateMessage(message, systemPrompt, conversationHistory);
        }
        // Create message objects
        const userMessage = {
            role: "user",
            content: message,
            timestamp: admin_1.admin.firestore.FieldValue.serverTimestamp(),
        };
        const assistantMessage = {
            role: "assistant",
            content: assistantResponse,
            timestamp: admin_1.admin.firestore.FieldValue.serverTimestamp(),
            // modelUsed removed - internal tracking only, not exposed to users
        };
        // Update thread with new messages
        const updatedMessages = [...(thread.messages || []), userMessage, assistantMessage];
        await threadRef.update({
            messages: updatedMessages,
            updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
        });
        // Increment message count (counts user messages)
        await (0, quotaGuards_1.incrementMessageCount)(threadId);
        // Get updated count
        const updatedThreadDoc = await threadRef.get();
        const updatedThread = updatedThreadDoc.data();
        const messageCount = updatedThread.messageCount || 0;
        // Build response (modelUsed removed - internal only)
        const response = {
            threadId,
            message: assistantMessage,
            messageCount,
            // modelUsed removed - not exposed to users
        };
        firebase_functions_1.logger.info(`Chat message sent in thread ${threadId}, total messages: ${messageCount}`);
        return response;
    }
    catch (error) {
        firebase_functions_1.logger.error("Error sending chat message:", error);
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        throw new https_1.HttpsError("internal", "Failed to send chat message", error);
    }
});
//# sourceMappingURL=sendChatMessage.js.map