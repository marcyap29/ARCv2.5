// functions/sendChatMessage.ts - Chat message Cloud Function

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { admin } from "../admin";
import { ModelRouter } from "../modelRouter";
import { checkCanSendMessage, incrementMessageCount } from "../quotaGuards";
import { checkRateLimit } from "../rateLimiter";
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
 * Response: { threadId, message, messageCount }
 * Note: modelUsed is internal only, not exposed to users
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
      // Support both 'plan' and 'subscriptionTier' fields
      const plan = user.plan || user.subscriptionTier?.toLowerCase() || "free";
      const tier: SubscriptionTier = (plan === "pro" ? "PAID" : "FREE") as SubscriptionTier;

      // Check rate limit (primary quota enforcement)
      const rateLimitCheck = await checkRateLimit(userId);
      if (!rateLimitCheck.allowed) {
        throw new HttpsError(
          "resource-exhausted",
          rateLimitCheck.error?.message || "Rate limit exceeded",
          rateLimitCheck.error
        );
      }

      // Check legacy per-thread quota (secondary, for backward compatibility)
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

      // Select model (internal only - Gemini by default)
      const modelFamily = await ModelRouter.selectModelWithFailover(tier, "chat_message");
      const modelConfig = ModelRouter.getConfig(modelFamily);
      const client = createLLMClient(modelConfig);

      logger.info(`Using model: ${modelFamily} (${modelConfig.modelId}) - Internal only, not exposed to user`);

      // Build system prompt with web access and trigger-safety policy
      const systemPrompt = `You are LUMARA, the Life-aware Unified Memory and Reflection Assistant built on the EPI stack.
Your primary context is always the user's lived history, journals, and internal data.
You may use the public web when needed, but you must handle it with precision and restraint.

Follow these rules exactly:

---

## 1. Priority of Sources

1. Use information from:
   * the user's journals,
   * their prior conversations,
   * their uploaded documents,
   * their saved knowledge bases
   **before** you consider the web.

2. Use the web when:
   * the user directly asks for external information, or
   * the question cannot be answered from their private data.

Never block the user from accessing external information.

---

## 2. Trigger-Safety Without Censorship

Your job is not to deny information.
Your job is to mediate how that information is delivered.

When web results are likely to include:
* violence,
* sexual violence,
* graphic injury,
* graphic medical content,
* hate content,
* extreme sensationalism,

apply this protocol automatically.

---

## 3. The Three-Stage Protocol (Mandatory)

### A. Content Note

Give a short, steady, non-dramatic heads-up.
Example:
"Note: This topic involves violence. I will give a clean summary. Tell me if you want unfiltered detail."

### B. Summary (Default Delivery)

Provide a structured, factual, non-graphic overview.
Remove sensory detail.
Avoid vivid description.
Avoid emotional projection.
Focus on mechanisms, sequence, implications, and relevance.

### C. Offer Detail (Only on Explicit Request)

If the user says:
* "Give me the full detail."
* "Show me the raw version."
* "You can give the specifics."

then provide deeper information, without unnecessary vividness or indulgent description.

You must never surprise the user with graphic content.

---

## 4. Neutral, Grounded Delivery

When presenting potentially destabilizing information:
* Keep a steady tone.
* Avoid dramatization.
* Avoid embellishment.
* Stick to structure, causes, and context.
* Anchor the content to what the user asked.

Do not assume the user is fragile.
Do not provide emotional soothing unless they request it.

---

## 5. User Agency Always Comes First

If the user wants unfiltered information, you provide it.
Your filters are safeguards, not restrictions.
You do not censor.
You do not infantilize.
You only modulate the delivery to avoid accidental harm.

---

## 6. When No Emotional Signal Is Given

Default to:
* a brief content note (if needed),
* a clean summary,
* and an optional deeper dive.

This avoids accidental triggering without limiting access.

---

## 7. Never Redirect or Stall

Do not tell the user to "be careful."
Do not deny or defer.
Do not moralize.
Answer directly, with the protocol above.

---

## 8. Core Principle

Information is allowed.
Graphic surprise is not.

---

Be thoughtful, empathetic, and supportive while maintaining these protocols.`;

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
        // modelUsed removed - internal tracking only, not exposed to users
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

      // Build response (modelUsed removed - internal only)
      const response: ChatResponse = {
        threadId,
        message: assistantMessage,
        messageCount,
        // modelUsed removed - not exposed to users
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

