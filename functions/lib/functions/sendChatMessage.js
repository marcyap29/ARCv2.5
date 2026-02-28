"use strict";
// functions/sendChatMessage.ts - Chat message Cloud Function
// Supports per-user LLM (Groq, OpenAI, Anthropic, Gemini) via updateUserModelConfig
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendChatMessage = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const admin_1 = require("../admin");
const quotaGuards_1 = require("../quotaGuards");
const rateLimiter_1 = require("../rateLimiter");
const authGuard_1 = require("../authGuard");
const config_1 = require("../config");
const groqClient_1 = require("../groqClient");
const llmRouter_1 = require("../llmRouter");
const userLlmSettings_1 = require("../userLlmSettings");
const saveUserModelConfig_1 = require("../saveUserModelConfig");
const prompts_1 = require("../prompts");
const providers_1 = require("../config/providers");
const closingTracker_js_1 = require("../closingTracker.js");
const db = admin_1.admin.firestore();
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
exports.sendChatMessage = (0, https_1.onCall)({
    secrets: [config_1.GROQ_API_KEY, config_1.GEMINI_API_KEY, config_1.LLM_SETTINGS_ENCRYPTION_KEY],
}, async (request) => {
    const { threadId, message } = request.data;
    // Validate request
    if (!threadId || !message) {
        throw new https_1.HttpsError("invalid-argument", "threadId and message are required");
    }
    // Enforce authentication (supports anonymous trial)
    const authResult = await (0, authGuard_1.enforceAuth)(request);
    const { userId, isAnonymous } = authResult;
    const userEmail = request.auth?.token?.email;
    firebase_functions_1.logger.info(`Sending chat message in thread ${threadId} for user ${userId} (anonymous: ${isAnonymous})`);
    try {
        // Unified daily limit: 50 total LUMARA requests/day (chat + reflections + voice)
        const dailyCheck = await (0, rateLimiter_1.checkUnifiedDailyLimit)(userId, userEmail);
        if (!dailyCheck.allowed) {
            throw new https_1.HttpsError("resource-exhausted", dailyCheck.error?.message || "Daily limit reached", dailyCheck.error);
        }
        // Per-minute spam protection
        const rateLimitCheck = await (0, rateLimiter_1.checkRateLimit)(userId, userEmail);
        if (!rateLimitCheck.allowed) {
            throw new https_1.HttpsError("resource-exhausted", rateLimitCheck.error?.message || "Rate limit exceeded", rateLimitCheck.error);
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
        // ── Model-change flow (in-chat) ───────────────────────────────────────
        const flowState = thread.metadata?.activeFlow;
        if (flowState?.flow === "model_change") {
            const encKey = config_1.LLM_SETTINGS_ENCRYPTION_KEY.value();
            const result = await handleModelChangeFlow(flowState, message.trim(), userId, threadRef, thread, conversationHistory, encKey || "");
            if (result)
                return result;
        }
        // Start model-change flow if user asked to change model
        if (!flowState && MODEL_CHANGE_INTENT.test(message)) {
            const result = await startModelChangeFlow(threadRef, thread, message, conversationHistory);
            if (result)
                return result;
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
                firebase_functions_1.logger.info(`Loaded ${entries.length} journal entries for context`);
            }
        }
        catch (error) {
            firebase_functions_1.logger.warn(`Failed to load journal entries: ${error}`);
        }
        // Load per-user LLM config or use default (Groq)
        const encKey = config_1.LLM_SETTINGS_ENCRYPTION_KEY.value();
        const userLlm = encKey ? await (0, userLlmSettings_1.loadUserLlmSettings)(userId, encKey) : null;
        let apiKey;
        let llmProvider = null;
        let llmModelId = null;
        if (userLlm) {
            if (userLlm.useProjectKey) {
                apiKey = userLlm.provider === "groq" ? (config_1.GROQ_API_KEY.value() ?? "") : (config_1.GEMINI_API_KEY.value() ?? "");
                if (!apiKey) {
                    throw new https_1.HttpsError("failed-precondition", `${userLlm.provider} API key not configured for this project`);
                }
                firebase_functions_1.logger.info(`Using user LLM (project default): ${userLlm.provider}/${userLlm.modelId}`);
            }
            else {
                apiKey = userLlm.apiKey ?? "";
                if (!apiKey) {
                    firebase_functions_1.logger.warn("User LLM config missing apiKey, falling back to default");
                    apiKey = config_1.GROQ_API_KEY.value() ?? "";
                    llmProvider = "groq";
                    llmModelId = (0, providers_1.getProvider)("groq").defaultModelId;
                }
                else {
                    firebase_functions_1.logger.info(`Using user LLM: ${userLlm.provider}/${userLlm.modelId}`);
                }
            }
            if (llmProvider === null) {
                llmProvider = userLlm.provider;
                llmModelId = userLlm.modelId;
            }
        }
        else {
            apiKey = config_1.GROQ_API_KEY.value() ?? "";
            if (!apiKey) {
                throw new https_1.HttpsError("internal", "Groq API key not configured");
            }
            llmProvider = "groq";
            llmModelId = (0, providers_1.getProvider)("groq").defaultModelId;
            firebase_functions_1.logger.info(`Using default Groq for chat`);
        }
        const systemPrompt = prompts_1.LUMARA_CHAT_SYSTEM_PROMPT;
        // Generate response
        let assistantResponse;
        // Append journal context to the user's message
        const messageWithContext = journalContext
            ? `${message}${journalContext}`
            : message;
        if (userLlm && llmProvider && llmModelId) {
            assistantResponse = await (0, llmRouter_1.llmChatCompletion)({
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
        }
        else {
            assistantResponse = await (0, groqClient_1.groqChatCompletion)(apiKey, {
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
        const now = admin_1.admin.firestore.Timestamp.now();
        const userMessage = {
            role: "user",
            content: message,
            timestamp: now,
        };
        const assistantMessage = {
            role: "assistant",
            content: assistantResponse,
            timestamp: now,
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
/** Build ChatResponse from thread and assistant message */
function buildChatResponse(threadId, thread, assistantMessage) {
    const messageCount = (thread.messageCount || 0) + 1; // +1 for the user message we're adding
    return { threadId, message: assistantMessage, messageCount };
}
/** Start model-change flow when user asks to change model */
async function startModelChangeFlow(threadRef, thread, message, conversationHistory) {
    const flowState = {
        flow: "model_change",
        step: "await_provider",
    };
    const assistantContent = "I can help you switch to a different model. Which provider would you like? Choose one: **groq**, **openai**, **anthropic**, **gemini**, **cloudflare**, or **swarmspace**.";
    const now = admin_1.admin.firestore.Timestamp.now();
    const userMsg = { role: "user", content: message, timestamp: now };
    const assistantMsg = { role: "assistant", content: assistantContent, timestamp: now };
    const updatedMessages = [...(thread.messages || []), userMsg, assistantMsg];
    await threadRef.update({
        messages: updatedMessages,
        metadata: { activeFlow: flowState },
        updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
    });
    await (0, quotaGuards_1.incrementMessageCount)(threadRef.id);
    return buildChatResponse(threadRef.id, { ...thread, messageCount: (thread.messageCount || 0) + 1 }, assistantMsg);
}
/** Handle model-change flow steps. Returns ChatResponse if handled, null to continue to normal LLM. */
async function handleModelChangeFlow(flowState, message, userId, threadRef, thread, _conversationHistory, encKey) {
    const now = admin_1.admin.firestore.Timestamp.now();
    const userMsg = { role: "user", content: message, timestamp: now };
    let assistantContent;
    let nextFlow = null;
    if (flowState.step === "await_provider") {
        const provider = (0, providers_1.resolveProvider)(message);
        if (!provider) {
            assistantContent =
                "I didn't recognize that provider. Please choose one: **groq**, **openai**, **anthropic**, **gemini**, **cloudflare**, or **swarmspace**.";
            nextFlow = flowState;
        }
        else {
            const cfg = (0, providers_1.getProvider)(provider);
            if (cfg.requiresAccountId) {
                assistantContent = `Got it — ${cfg.displayName}. First, what's your Cloudflare account ID? (Find it in the Cloudflare dashboard URL: dash.cloudflare.com → Workers & Pages → your account ID)`;
                nextFlow = { flow: "model_change", step: "await_account_id", provider };
            }
            else if ((0, providers_1.canUseProjectKey)(provider)) {
                assistantContent = `Got it — ${cfg.displayName}. Use **default** (no API key needed) or provide your **own** key? Reply \`default\` or \`own\`.`;
                nextFlow = { flow: "model_change", step: "await_use_default", provider };
            }
            else {
                assistantContent = `Got it — ${cfg.displayName}. What's the model ID? (e.g. \`${cfg.defaultModelId}\` or any model from that provider)`;
                nextFlow = { flow: "model_change", step: "await_model_id", provider };
            }
        }
    }
    else if (flowState.step === "await_use_default") {
        const choice = message.toLowerCase().trim();
        if (choice === "default" || choice === "d" || choice === "use default") {
            const cfg = (0, providers_1.getProvider)(flowState.provider);
            assistantContent = `Using project default. What's the model ID? (e.g. \`${cfg.defaultModelId}\`)`;
            nextFlow = { ...flowState, step: "await_model_id", useProjectKey: true };
        }
        else if (choice === "own" || choice === "o" || choice === "my key" || choice === "my own") {
            const cfg = (0, providers_1.getProvider)(flowState.provider);
            assistantContent = `Got it. What's the model ID? (e.g. \`${cfg.defaultModelId}\`)`;
            nextFlow = { ...flowState, step: "await_model_id", useProjectKey: false };
        }
        else {
            assistantContent = "Reply **default** (no API key) or **own** (provide your key).";
            nextFlow = flowState;
        }
    }
    else if (flowState.step === "await_account_id") {
        const accountId = message.trim();
        if (!accountId || accountId.length < 3) {
            assistantContent = "Please enter a valid Cloudflare account ID (at least 3 characters).";
            nextFlow = flowState;
        }
        else {
            const cfg = (0, providers_1.getProvider)(flowState.provider);
            assistantContent = `Thanks. What's the model ID? (e.g. \`${cfg.defaultModelId}\`)`;
            nextFlow = { ...flowState, step: "await_model_id", accountId };
        }
    }
    else if (flowState.step === "await_model_id") {
        const modelId = message.trim();
        if (modelId.length < 2 || modelId.length > 128) {
            assistantContent = "Please enter a valid model ID (2–128 characters).";
            nextFlow = { ...flowState, modelId: undefined };
        }
        else if (flowState.useProjectKey) {
            try {
                await (0, saveUserModelConfig_1.saveUserModelConfigWithProjectKey)(userId, flowState.provider, modelId);
                const providerCfg = (0, providers_1.getProvider)(flowState.provider);
                assistantContent = `Done. Your chat is now using **${providerCfg.displayName}** (project default) with model \`${modelId}\`.`;
                nextFlow = null;
            }
            catch (err) {
                const msg = err instanceof Error ? err.message : "Failed to save";
                assistantContent = `Couldn't save: ${msg}. Please try again.`;
                nextFlow = flowState;
            }
        }
        else {
            assistantContent = "Please provide your API key for this provider. It will be stored securely and never shared.";
            nextFlow = { ...flowState, step: "await_api_key", modelId };
        }
    }
    else if (flowState.step === "await_api_key") {
        const provider = flowState.provider;
        const modelId = (flowState.modelId || "").trim();
        const accountId = flowState.accountId?.trim();
        if (!provider || !modelId || !encKey) {
            assistantContent = "Something went wrong. Please try again or use Settings to configure your model.";
            nextFlow = null;
        }
        else {
            try {
                const providerCfg = (0, providers_1.getProvider)(provider);
                const accountIdToUse = providerCfg.requiresAccountId ? accountId : undefined;
                await (0, saveUserModelConfig_1.saveUserModelConfig)(userId, provider, modelId, message.trim(), encKey, accountIdToUse);
                assistantContent = `Done. Your chat is now using **${providerCfg.displayName}** with model \`${modelId}\`.`;
                nextFlow = null; // Clear flow
            }
            catch (err) {
                const msg = err instanceof Error ? err.message : "Validation failed";
                assistantContent = `I couldn't save that API key: ${msg}. Please check it and try again.`;
                nextFlow = flowState;
            }
        }
    }
    else {
        return null;
    }
    const assistantMsg = { role: "assistant", content: assistantContent, timestamp: now };
    const updatedMessages = [...(thread.messages || []), userMsg, assistantMsg];
    const updateData = {
        messages: updatedMessages,
        updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
    };
    if (nextFlow) {
        updateData.metadata = { activeFlow: nextFlow };
    }
    else {
        updateData["metadata"] = admin_1.admin.firestore.FieldValue.delete();
    }
    await threadRef.update(updateData);
    await (0, quotaGuards_1.incrementMessageCount)(threadRef.id);
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
async function _enforceClosingRotation(response, userId, conversationId, userMessage, atlasPhase) {
    try {
        // Check if response has a closing statement (ends with a question)
        const hasClosingQuestion = response.trim().endsWith('?');
        if (!hasClosingQuestion) {
            // No closing detected, return as-is
            return response;
        }
        // Classify conversation category
        const category = (0, closingTracker_js_1.classifyConversationCategory)(userMessage, atlasPhase);
        // Detect energy level
        const energyLevel = (0, closingTracker_js_1.detectEnergyLevel)(userMessage);
        // Select appropriate closing statement
        const selectedClosing = (0, closingTracker_js_1.selectClosingStatement)(userId, conversationId, category, atlasPhase, energyLevel);
        if (!selectedClosing) {
            // No closing available, return original
            firebase_functions_1.logger.warn(`No closing statement available for category ${category}`);
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
    }
    catch (error) {
        firebase_functions_1.logger.error('Error in enforceClosingRotation:', error);
        // Return original response on error
        return response;
    }
}
//# sourceMappingURL=sendChatMessage.js.map