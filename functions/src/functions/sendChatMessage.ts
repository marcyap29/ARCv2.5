// functions/sendChatMessage.ts - Chat message Cloud Function

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { admin } from "../admin";
import { ModelRouter } from "../modelRouter";
import { checkCanSendMessage, incrementMessageCount } from "../quotaGuards";
import { createLLMClient } from "../llmClients";
import {
  SubscriptionTier,
  ChatResponse,
  ChatMessage,
  UserDocument,
  ChatThreadDocument,
} from "../types";
import {
  GEMINI_API_KEY,
  ANTHROPIC_API_KEY,
} from "../config";

const db = admin.firestore();

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
 * Response: { threadId, message, messageCount, modelUsed }
 */
export const sendChatMessage = onCall(
  {
    secrets: [GEMINI_API_KEY, ANTHROPIC_API_KEY],
  },
  async (request) => {
    const { threadId, message } = request.data;

    // Validate request
    if (!threadId || !message) {
      throw new HttpsError(
        "invalid-argument",
        "threadId and message are required"
      );
    }

    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    logger.info(`Sending chat message in thread ${threadId} for user ${userId}`);

    try {
      // Load user document
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists) {
        throw new HttpsError("not-found", "User not found");
      }

      const user = userDoc.data() as UserDocument;
      const tier = user.subscriptionTier as SubscriptionTier;

      // Check quota
      const quotaCheck = await checkCanSendMessage(userId, threadId);
      if (!quotaCheck.allowed) {
        throw new HttpsError(
          "resource-exhausted",
          quotaCheck.error?.message || "Quota limit reached",
          quotaCheck.error
        );
      }

      // Load or create thread
      const threadRef = db.collection("chatThreads").doc(threadId);
      const threadDoc = await threadRef.get();

      let thread: ChatThreadDocument;
      let conversationHistory: Array<{ role: "user" | "assistant"; content: string }> = [];

      if (threadDoc.exists) {
        thread = threadDoc.data() as ChatThreadDocument;
        // Build conversation history from existing messages
        conversationHistory = (thread.messages || []).map((msg) => ({
          role: msg.role,
          content: msg.content,
        }));
      } else {
        // Create new thread
        thread = {
          userId,
          messageCount: 0,
          messages: [],
          createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
          updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
        };
        await threadRef.set(thread);
      }

      // Select model based on tier
      const modelFamily = ModelRouter.selectModel(tier, "chat_message");
      const modelConfig = ModelRouter.getConfig(modelFamily);
      const client = createLLMClient(modelConfig);

      logger.info(`Using model: ${modelFamily} (${modelConfig.modelId})`);

      // Build system prompt
      const systemPrompt = `You are LUMARA, a thoughtful and empathetic AI companion for journaling and reflection. 
You help users explore their thoughts, feelings, and experiences with curiosity and compassion.
Be concise, insightful, and supportive.`;

      // Generate response
      let assistantResponse: string;
      
      if (modelConfig.family === "GEMINI_FLASH" || modelConfig.family === "GEMINI_PRO") {
        // Use Gemini client
        const geminiClient = client as any;
        assistantResponse = await geminiClient.generateContent(
          message,
          systemPrompt,
          conversationHistory
        );
      } else {
        // Use Claude client
        const claudeClient = client as any;
        assistantResponse = await claudeClient.generateMessage(
          message,
          systemPrompt,
          conversationHistory
        );
      }

      // Create message objects
      const userMessage: ChatMessage = {
        role: "user",
        content: message,
        timestamp: admin.firestore.FieldValue.serverTimestamp() as any,
      };

      const assistantMessage: ChatMessage = {
        role: "assistant",
        content: assistantResponse,
        timestamp: admin.firestore.FieldValue.serverTimestamp() as any,
        modelUsed: modelFamily,
      };

      // Update thread with new messages
      const updatedMessages = [...(thread.messages || []), userMessage, assistantMessage];
      await threadRef.update({
        messages: updatedMessages,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Increment message count (counts user messages)
      await incrementMessageCount(threadId);

      // Get updated count
      const updatedThreadDoc = await threadRef.get();
      const updatedThread = updatedThreadDoc.data() as ChatThreadDocument;
      const messageCount = updatedThread.messageCount || 0;

      // Build response
      const response: ChatResponse = {
        threadId,
        message: assistantMessage,
        messageCount,
        modelUsed: modelFamily,
      };

      logger.info(`Chat message sent in thread ${threadId}, total messages: ${messageCount}`);

      return response;
    } catch (error) {
      logger.error("Error sending chat message:", error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        "internal",
        "Failed to send chat message",
        error
      );
    }
  }
);

