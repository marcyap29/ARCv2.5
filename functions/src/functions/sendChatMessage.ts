// functions/sendChatMessage.ts - Chat message Cloud Function

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { admin } from "../admin";
import { ModelRouter } from "../modelRouter";
import { checkCanSendMessage, incrementMessageCount } from "../quotaGuards";
import { checkRateLimit } from "../rateLimiter";
import { createLLMClient } from "../llmClients";
import { enforceAuth } from "../authGuard";
import {
  SubscriptionTier,
  ChatResponse,
  ChatMessage,
  ChatThreadDocument,
} from "../types";
import { GEMINI_API_KEY } from "../config";
import {
  selectClosingStatement,
  classifyConversationCategory,
  detectEnergyLevel
} from "../closingTracker.js";

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
    secrets: [GEMINI_API_KEY],
    // Auth enforced via enforceAuth() - no invoker: "public"
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

    // Enforce authentication (supports anonymous trial)
    const authResult = await enforceAuth(request);
    const { userId, isAnonymous, user } = authResult;
    
    logger.info(`Sending chat message in thread ${threadId} for user ${userId} (anonymous: ${isAnonymous})`);

    try {
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

      // Fetch recent journal entries for context
      let journalContext = "";
      try {
        const journalEntriesSnapshot = await db
          .collection("users")
          .doc(userId)
          .collection("journal")
          .orderBy("timestamp", "desc")
          .limit(10)
          .get();
        
        if (!journalEntriesSnapshot.empty) {
          const entries = journalEntriesSnapshot.docs.map((doc) => {
            const data = doc.data();
            return `[${data.timestamp?.toDate?.()?.toISOString() || "Unknown date"}] ${data.text || data.content || ""}`;
          });
          journalContext = `\n\n## Recent Journal Entries:\n${entries.join("\n\n")}`;
          logger.info(`Loaded ${entries.length} journal entries for context`);
        }
      } catch (error) {
        logger.warn(`Failed to load journal entries: ${error}`);
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

      // Append journal context to the user's message
      const messageWithContext = journalContext 
        ? `${message}${journalContext}` 
        : message;

      if (modelConfig.family === "GEMINI_FLASH" || modelConfig.family === "GEMINI_PRO") {
        // Use Gemini client
        const geminiClient = client as any;
        assistantResponse = await geminiClient.generateContent(
          messageWithContext,
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

      // PROGRAMMATIC CLOSING STATEMENT ENFORCEMENT - DISABLED
      // This was causing responses to be truncated and replaced with generic endings
      // Let LUMARA generate natural responses without post-processing
      // assistantResponse = await enforceClosingRotation(
      //   assistantResponse,
      //   user.userId,
      //   threadId,
      //   message,
      //   undefined // Atlas phase not yet tracked in ChatThreadDocument
      // );

      // Create message objects with actual timestamp (serverTimestamp can't be used in arrays)
      const now = admin.firestore.Timestamp.now();
      const userMessage: ChatMessage = {
        role: "user",
        content: message,
        timestamp: now as any,
      };

      const assistantMessage: ChatMessage = {
        role: "assistant",
        content: assistantResponse,
        timestamp: now as any,
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

/**
 * Enforce closing statement rotation using programmatic tracking
 *
 * This function:
 * 1. Detects if the response has a closing question/statement
 * 2. Classifies the conversation context
 * 3. Selects a non-repetitive closing using the tracking system
 * 4. Replaces the existing closing with the selected one
 */
async function enforceClosingRotation(
  response: string,
  userId: string,
  conversationId: string,
  userMessage: string,
  atlasPhase?: string
): Promise<string> {
  try {
    // Check if response has a closing statement (ends with a question)
    const hasClosingQuestion = response.trim().endsWith('?');

    if (!hasClosingQuestion) {
      // No closing detected, return as-is
      return response;
    }

    // Classify conversation category
    const category = classifyConversationCategory(userMessage, atlasPhase as any);

    // Detect energy level
    const energyLevel = detectEnergyLevel(userMessage);

    // Select appropriate closing statement
    const selectedClosing = selectClosingStatement(
      userId,
      conversationId,
      category,
      atlasPhase as any,
      energyLevel
    );

    if (!selectedClosing) {
      // No closing available, return original
      logger.warn(`No closing statement available for category ${category}`);
      return response;
    }

    // Replace the last sentence (closing) with our selected one
    const sentences = response.trim().split(/[.!?]+/);
    if (sentences.length > 1) {
      // Remove empty last element and the last sentence
      const filteredSentences = sentences.filter(s => s.trim().length > 0);
      if (filteredSentences.length > 1) {
        // Remove the last sentence and add our selected closing
        filteredSentences.pop();
        const baseResponse = filteredSentences.join('. ').trim() + '. ';

        // Add our programmatically selected closing
        return baseResponse + selectedClosing.text;
      }
    }

    // Fallback: append our closing if we can't parse properly
    const baseResponse = response.replace(/[.!?]+\s*$/, '. ');
    return baseResponse + selectedClosing.text;

  } catch (error) {
    logger.error('Error in enforceClosingRotation:', error);
    // Return original response on error
    return response;
  }
}
