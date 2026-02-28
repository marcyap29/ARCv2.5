// functions/sendChatMessage.ts - Chat message Cloud Function
// Supports per-user LLM (Groq, OpenAI, Anthropic, Gemini) via updateUserModelConfig

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { admin } from "../admin";
import { incrementMessageCount } from "../quotaGuards";
import { checkUnifiedDailyLimit, checkRateLimit } from "../rateLimiter";
import { enforceAuth } from "../authGuard";
import {
  ChatResponse,
  ChatMessage,
  ChatThreadDocument,
  ModelChangeFlowState,
} from "../types";
import { GROQ_API_KEY, GEMINI_API_KEY, LLM_SETTINGS_ENCRYPTION_KEY } from "../config";
import { groqChatCompletion } from "../groqClient";
import { llmChatCompletion } from "../llmRouter";
import { loadUserLlmSettings } from "../userLlmSettings";
import { saveUserModelConfig, saveUserModelConfigWithProjectKey } from "../saveUserModelConfig";
import { LUMARA_CHAT_SYSTEM_PROMPT } from "../prompts";
import { resolveProvider, getProvider, canUseProjectKey } from "../config/providers";
import type { ProviderId } from "../config/providers";
import {
  selectClosingStatement,
  classifyConversationCategory,
  detectEnergyLevel,
} from "../closingTracker.js";

const db = admin.firestore();

/** Keywords that trigger model-change flow */
const MODEL_CHANGE_INTENT = /change\s*(my\s*)?model|switch\s*model|use\s*(a\s*)?different\s*model|set\s*(my\s*)?model/i;

/**
 * Send a chat message
 * 
 * Flow:
 * 1. Verify Firebase Auth token (automatic via onCall)
 * 2. Load user and thread from Firestore
 * 3. Check quota (free tier: max 200 messages per thread)
 * 4. Uses Groq (GPT-OSS 120B) for chat responses
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
    secrets: [GROQ_API_KEY, GEMINI_API_KEY, LLM_SETTINGS_ENCRYPTION_KEY],
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
    const { userId, isAnonymous } = authResult;
    const userEmail = request.auth?.token?.email as string | undefined;

    logger.info(`Sending chat message in thread ${threadId} for user ${userId} (anonymous: ${isAnonymous})`);

    try {
      // Unified daily limit: 50 total LUMARA requests/day (chat + reflections + voice)
      const dailyCheck = await checkUnifiedDailyLimit(userId, userEmail);
      if (!dailyCheck.allowed) {
        throw new HttpsError(
          "resource-exhausted",
          dailyCheck.error?.message || "Daily limit reached",
          dailyCheck.error
        );
      }

      // Per-minute spam protection
      const rateLimitCheck = await checkRateLimit(userId, userEmail);
      if (!rateLimitCheck.allowed) {
        throw new HttpsError(
          "resource-exhausted",
          rateLimitCheck.error?.message || "Rate limit exceeded",
          rateLimitCheck.error
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

      // ── Model-change flow (in-chat) ───────────────────────────────────────
      const flowState = thread.metadata?.activeFlow;
      if (flowState?.flow === "model_change") {
        const encKey = LLM_SETTINGS_ENCRYPTION_KEY.value();
        const result = await handleModelChangeFlow(
          flowState,
          message.trim(),
          userId,
          threadRef,
          thread,
          conversationHistory,
          encKey || ""
        );
        if (result) return result;
      }

      // Start model-change flow if user asked to change model
      if (!flowState && MODEL_CHANGE_INTENT.test(message)) {
        const result = await startModelChangeFlow(threadRef, thread, message, conversationHistory);
        if (result) return result;
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

      // Load per-user LLM config or use default (Groq)
      const encKey = LLM_SETTINGS_ENCRYPTION_KEY.value();
      const userLlm = encKey ? await loadUserLlmSettings(userId, encKey) : null;

      let apiKey: string;
      let llmProvider: ProviderId | null = null;
      let llmModelId: string | null = null;

      if (userLlm) {
        if (userLlm.useProjectKey) {
          apiKey = userLlm.provider === "groq" ? (GROQ_API_KEY.value() ?? "") : (GEMINI_API_KEY.value() ?? "");
          if (!apiKey) {
            throw new HttpsError("failed-precondition", `${userLlm.provider} API key not configured for this project`);
          }
          logger.info(`Using user LLM (project default): ${userLlm.provider}/${userLlm.modelId}`);
        } else {
          apiKey = userLlm.apiKey ?? "";
          if (!apiKey) {
            logger.warn("User LLM config missing apiKey, falling back to default");
            apiKey = GROQ_API_KEY.value() ?? "";
            llmProvider = "groq";
            llmModelId = getProvider("groq").defaultModelId;
          } else {
            logger.info(`Using user LLM: ${userLlm.provider}/${userLlm.modelId}`);
          }
        }
        if (llmProvider === null) {
          llmProvider = userLlm.provider;
          llmModelId = userLlm.modelId;
        }
      } else {
        apiKey = GROQ_API_KEY.value() ?? "";
        if (!apiKey) {
          throw new HttpsError("internal", "Groq API key not configured");
        }
        llmProvider = "groq";
        llmModelId = getProvider("groq").defaultModelId;
        logger.info(`Using default Groq for chat`);
      }

      const systemPrompt = LUMARA_CHAT_SYSTEM_PROMPT;

      // Generate response
      let assistantResponse: string;

      // Append journal context to the user's message
      const messageWithContext = journalContext 
        ? `${message}${journalContext}` 
        : message;

      if (userLlm && llmProvider && llmModelId) {
        assistantResponse = await llmChatCompletion({
          provider: llmProvider,
          modelId: llmModelId,
          apiKey,
          accountId: userLlm?.accountId,
          system: systemPrompt,
          user: messageWithContext,
          conversationHistory,
          temperature: 0.7,
          maxTokens: 4096,
        });
      } else {
        assistantResponse = await groqChatCompletion(apiKey, {
          system: systemPrompt,
          user: messageWithContext,
          conversationHistory,
          temperature: 0.7,
          maxTokens: 4096,
        });
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

/** Build ChatResponse from thread and assistant message */
function buildChatResponse(
  threadId: string,
  thread: ChatThreadDocument,
  assistantMessage: ChatMessage
): ChatResponse {
  const messageCount = (thread.messageCount || 0) + 1; // +1 for the user message we're adding
  return { threadId, message: assistantMessage, messageCount };
}

/** Start model-change flow when user asks to change model */
async function startModelChangeFlow(
  threadRef: admin.firestore.DocumentReference,
  thread: ChatThreadDocument,
  message: string,
  conversationHistory: Array<{ role: "user" | "assistant"; content: string }>
): Promise<ChatResponse | null> {
  const flowState: ModelChangeFlowState = {
    flow: "model_change",
    step: "await_provider",
  };
  const assistantContent =
    "I can help you switch to a different model. Which provider would you like? Choose one: **groq**, **openai**, **anthropic**, **gemini**, **cloudflare**, or **swarmspace**.";
  const now = admin.firestore.Timestamp.now() as any;
  const userMsg: ChatMessage = { role: "user", content: message, timestamp: now };
  const assistantMsg: ChatMessage = { role: "assistant", content: assistantContent, timestamp: now };
  const updatedMessages = [...(thread.messages || []), userMsg, assistantMsg];
  await threadRef.update({
    messages: updatedMessages,
    metadata: { activeFlow: flowState },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await incrementMessageCount(threadRef.id);
  return buildChatResponse(threadRef.id, { ...thread, messageCount: (thread.messageCount || 0) + 1 }, assistantMsg);
}

/** Handle model-change flow steps. Returns ChatResponse if handled, null to continue to normal LLM. */
async function handleModelChangeFlow(
  flowState: ModelChangeFlowState,
  message: string,
  userId: string,
  threadRef: admin.firestore.DocumentReference,
  thread: ChatThreadDocument,
  _conversationHistory: Array<{ role: "user" | "assistant"; content: string }>,
  encKey: string
): Promise<ChatResponse | null> {
  const now = admin.firestore.Timestamp.now() as any;
  const userMsg: ChatMessage = { role: "user", content: message, timestamp: now };
  let assistantContent: string;
  let nextFlow: ModelChangeFlowState | null = null;

  if (flowState.step === "await_provider") {
    const provider = resolveProvider(message);
    if (!provider) {
      assistantContent =
        "I didn't recognize that provider. Please choose one: **groq**, **openai**, **anthropic**, **gemini**, **cloudflare**, or **swarmspace**.";
      nextFlow = flowState;
    } else {
      const cfg = getProvider(provider);
      if (cfg.requiresAccountId) {
        assistantContent = `Got it — ${cfg.displayName}. First, what's your Cloudflare account ID? (Find it in the Cloudflare dashboard URL: dash.cloudflare.com → Workers & Pages → your account ID)`;
        nextFlow = { flow: "model_change", step: "await_account_id", provider };
      } else if (canUseProjectKey(provider)) {
        assistantContent = `Got it — ${cfg.displayName}. Use **default** (no API key needed) or provide your **own** key? Reply \`default\` or \`own\`.`;
        nextFlow = { flow: "model_change", step: "await_use_default", provider };
      } else {
        assistantContent = `Got it — ${cfg.displayName}. What's the model ID? (e.g. \`${cfg.defaultModelId}\` or any model from that provider)`;
        nextFlow = { flow: "model_change", step: "await_model_id", provider };
      }
    }
  } else if (flowState.step === "await_use_default") {
    const choice = message.toLowerCase().trim();
    if (choice === "default" || choice === "d" || choice === "use default") {
      const cfg = getProvider(flowState.provider as ProviderId);
      assistantContent = `Using project default. What's the model ID? (e.g. \`${cfg.defaultModelId}\`)`;
      nextFlow = { ...flowState, step: "await_model_id", useProjectKey: true };
    } else if (choice === "own" || choice === "o" || choice === "my key" || choice === "my own") {
      const cfg = getProvider(flowState.provider as ProviderId);
      assistantContent = `Got it. What's the model ID? (e.g. \`${cfg.defaultModelId}\`)`;
      nextFlow = { ...flowState, step: "await_model_id", useProjectKey: false };
    } else {
      assistantContent = "Reply **default** (no API key) or **own** (provide your key).";
      nextFlow = flowState;
    }
  } else if (flowState.step === "await_account_id") {
    const accountId = message.trim();
    if (!accountId || accountId.length < 3) {
      assistantContent = "Please enter a valid Cloudflare account ID (at least 3 characters).";
      nextFlow = flowState;
    } else {
      const cfg = getProvider(flowState.provider as ProviderId);
      assistantContent = `Thanks. What's the model ID? (e.g. \`${cfg.defaultModelId}\`)`;
      nextFlow = { ...flowState, step: "await_model_id", accountId };
    }
  } else if (flowState.step === "await_model_id") {
    const modelId = message.trim();
    if (modelId.length < 2 || modelId.length > 128) {
      assistantContent = "Please enter a valid model ID (2–128 characters).";
      nextFlow = { ...flowState, modelId: undefined };
    } else if (flowState.useProjectKey) {
      try {
        await saveUserModelConfigWithProjectKey(userId, flowState.provider as ProviderId, modelId);
        const providerCfg = getProvider(flowState.provider as ProviderId);
        assistantContent = `Done. Your chat is now using **${providerCfg.displayName}** (project default) with model \`${modelId}\`.`;
        nextFlow = null;
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : "Failed to save";
        assistantContent = `Couldn't save: ${msg}. Please try again.`;
        nextFlow = flowState;
      }
    } else {
      assistantContent = "Please provide your API key for this provider. It will be stored securely and never shared.";
      nextFlow = { ...flowState, step: "await_api_key", modelId };
    }
  } else if (flowState.step === "await_api_key") {
    const provider = flowState.provider as ProviderId;
    const modelId = (flowState.modelId || "").trim();
    const accountId = flowState.accountId?.trim();
    if (!provider || !modelId || !encKey) {
      assistantContent = "Something went wrong. Please try again or use Settings to configure your model.";
      nextFlow = null;
    } else {
      try {
        const providerCfg = getProvider(provider);
        const accountIdToUse = providerCfg.requiresAccountId ? accountId : undefined;
        await saveUserModelConfig(userId, provider, modelId, message.trim(), encKey, accountIdToUse);
        assistantContent = `Done. Your chat is now using **${providerCfg.displayName}** with model \`${modelId}\`.`;
        nextFlow = null; // Clear flow
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : "Validation failed";
        assistantContent = `I couldn't save that API key: ${msg}. Please check it and try again.`;
        nextFlow = flowState;
      }
    }
  } else {
    return null;
  }

  const assistantMsg: ChatMessage = { role: "assistant", content: assistantContent, timestamp: now };
  const updatedMessages = [...(thread.messages || []), userMsg, assistantMsg];
  const updateData: Record<string, unknown> = {
    messages: updatedMessages,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (nextFlow) {
    updateData.metadata = { activeFlow: nextFlow };
  } else {
    updateData["metadata"] = admin.firestore.FieldValue.delete();
  }
  await threadRef.update(updateData);
  await incrementMessageCount(threadRef.id);

  const updatedThread = { ...thread, messages: updatedMessages, messageCount: (thread.messageCount || 0) + 1 };
  return buildChatResponse(threadRef.id, updatedThread, assistantMsg);
}

/**
 * Enforce closing statement rotation using programmatic tracking
 *
 * This function:
 * 1. Detects if the response has a closing question/statement
 * 2. Classifies the conversation context
 * 3. Selects a non-repetitive closing using the tracking system
 * 4. Replaces the existing closing with the selected one
 */
// @ts-ignore - Function kept for future use
async function _enforceClosingRotation(
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
