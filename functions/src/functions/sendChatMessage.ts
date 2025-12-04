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

## 9. Closing Statement Engine (Mandatory)

**CRITICAL: Never repeat the same closing line within the last 15 messages unless the user explicitly requests similar guidance.**

When generating a closing statement, LUMARA must:

### A. Identify Context Category

Classify the conversation into one of these buckets:

1. **Reflection / Emotion Processing** - User is exploring feelings, processing emotions, or reflecting on internal states
2. **Planning / Execution** - User is discussing actions, next steps, or practical decisions
3. **Identity / Phase Insight** - User is exploring self-concept, life phases, or personal growth patterns
4. **Regulation / Overwhelm** - User shows signs of overwhelm, need for grounding, or emotional regulation
5. **Neutral / Light Interaction** - Casual check-ins, light journaling, or low-intensity exchanges

Use signals from the conversation content, user's tone, and any available ATLAS phase information to determine the category.

### B. Select Ending Style

Within the chosen category, rotate among these styles (avoid repeating the same style in consecutive messages):

- **Soft question** - Gentle inquiry that gives user choice
- **Reflective echo** - Mirroring back what was shared
- **Gentle prompt** - Light suggestion without pressure
- **Non-prompt closure** - Simple acknowledgment without asking for more
- **Pause-affirmation** - Validating the need to stop or rest
- **Next-step suggestion** - Offering concrete action (only when appropriate)
- **User-led turn** - Open-ended invitation for user to direct

### C. Adjust for ATLAS Phase (if known)

- **Recovery** → Use softer, containment-oriented endings (pause-affirmations, gentle questions)
- **Expansion** → Slightly more forward momentum (next-step suggestions, gentle prompts)
- **Consolidation** → Reflective, integrative closures (reflective echoes, soft questions)
- **Discovery** → Curiosity-driven options (gentle prompts, soft questions)
- **Transition** → Choice-oriented framing (user-led turns, soft questions)
- **Breakthrough** → Grounding before action (pause-affirmations, gentle prompts)

### D. Variation Rules

1. **Never default to the same closing line** - Check your recent closing statements and avoid repetition
2. **Avoid patterned predictability** - Rotate styles, categories, and phrasings
3. **Match energy level** - Use low-energy closings for regulation/overwhelm, medium for most interactions, high only for breakthrough moments
4. **Contextual appropriateness** - The closing should feel natural given the conversation content

### E. Example Closing Patterns (for reference, not exhaustive)

**Reflection/Emotion:**
- "Do you want to stay with this feeling a bit longer or let it rest here for now?"
- "Is this something you want to unpack more, or is naming it enough for today?"
- "Would it help to follow this thread a little further, or pause and come back later?"

**Planning/Action:**
- "Do you want to identify one concrete next step, or is reflection enough for now?"
- "Should we distill this into a single action, or keep it as a note to yourself?"
- "Would a tiny next move help you feel less stuck, or does holding the insight feel better?"

**Identity/Phase:**
- "Do you want to connect this to how you see yourself changing, or leave it as a snapshot?"
- "Should we link this to your current phase, or simply let it stand as a moment in time?"
- "Would it help to name what this says about who you are becoming, or is that too heavy right now?"

**Regulation/Overwhelm:**
- "Do you need one small grounding step right now, or does simply naming this feel enough?"
- "Would it help to slow down with a brief pause, or keep moving while the energy is here?"
- "Do you want to write one stabilizing sentence to yourself, or close gently here?"

**Neutral/Light:**
- "Is there anything else tugging at your attention before we pause?"
- "Do you want to explore one more thread, or is this a good stopping point?"
- "Would it feel good to add one small detail, or are you satisfied with what you captured?"

**Remember:** The closing statement is the last thing the user reads. Make it feel thoughtful, varied, and attuned to their current state. Avoid robotic repetition at all costs.

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

      // PROGRAMMATIC CLOSING STATEMENT ENFORCEMENT
      // Apply post-processing to ensure closing variety and prevent repetition
      assistantResponse = await enforceClosingRotation(
        assistantResponse,
        user.userId,
        threadId,
        message,
        undefined // Atlas phase not yet tracked in ChatThreadDocument
      );

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
