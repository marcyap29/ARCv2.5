"use strict";
// functions/generateJournalReflection.ts - In-journal LUMARA reflection Cloud Function
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateJournalReflection = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const modelRouter_1 = require("../modelRouter");
const rateLimiter_1 = require("../rateLimiter");
const llmClients_1 = require("../llmClients");
const authGuard_1 = require("../authGuard");
const config_1 = require("../config");
// Note: db removed as user document is now loaded via enforceAuth()
/**
 * Generate a journal reflection (in-journal LUMARA)
 *
 * Flow:
 * 1. Verify Firebase Auth token (automatic via onCall)
 * 2. Load user from Firestore
 * 3. Check rate limit (free tier: 20 requests/day, 3 requests/minute)
 * 4. Route to appropriate model (FREE: Gemini Flash, PAID: Gemini Pro)
 * 5. Generate reflection using LLM with LUMARA Master Prompt
 * 6. Return reflection text
 *
 * API Shape:
 * httpsCallable('generateJournalReflection')
 *
 * Request: {
 *   entryText: string,
 *   phase?: string,
 *   mood?: string,
 *   chronoContext?: object,
 *   chatContext?: string,
 *   mediaContext?: string,
 *   options?: {
 *     preferQuestionExpansion?: boolean,
 *     toneMode?: string,
 *     regenerate?: boolean,
 *     conversationMode?: string
 *   }
 * }
 * Response: { reflection: string }
 */
exports.generateJournalReflection = (0, https_1.onCall)({
    secrets: [config_1.GEMINI_API_KEY],
    // Auth enforced via enforceAuth() - no invoker: "public"
}, async (request) => {
    const { entryText, entryId: _entryId, // For per-entry usage limit tracking (reserved)
    phase, mood, chronoContext, chatContext, mediaContext, options = {}, } = request.data;
    // Validate request
    if (!entryText) {
        throw new https_1.HttpsError("invalid-argument", "entryText is required");
    }
    // Enforce authentication (supports anonymous trial)
    const authResult = await (0, authGuard_1.enforceAuth)(request);
    const { userId, isAnonymous, isPremium, user } = authResult;
    const userEmail = request.auth?.token?.email;
    firebase_functions_1.logger.info(`Generating journal reflection for user ${userId} (anonymous: ${isAnonymous}, premium: ${isPremium})`);
    try {
        // Support both 'plan' and 'subscriptionTier' fields
        const plan = user.plan || user.subscriptionTier?.toLowerCase() || "free";
        const tier = (plan === "pro" ? "PAID" : "FREE");
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
        // Select model (internal only - Gemini by default)
        const modelFamily = await modelRouter_1.ModelRouter.selectModelWithFailover(tier, "chat_message");
        const modelConfig = modelRouter_1.ModelRouter.getConfig(modelFamily);
        const client = (0, llmClients_1.createLLMClient)(modelConfig);
        firebase_functions_1.logger.info(`Using model: ${modelFamily} (${modelConfig.modelId}) for journal reflection`);
        // Build system prompt with LUMARA Master Prompt
        // Note: For journal reflections, we use a simplified version without web access
        // since journal analysis doesn't need web access
        const systemPrompt = `You are LUMARA, the Life-aware Unified Memory and Reflection Assistant built on the EPI stack.

**RESPONSE LENGTH**: Provide comprehensive, detailed reflections. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. Do not end with generic extension questions - let your persona naturally ask questions only when genuinely relevant, not as a default ending.

**HISTORICAL CONTEXT**: When past journal entries are provided, actively reference and draw connections to them. Show patterns, themes, and evolution across the user's journal history. Use historical entries to provide deeper context and meaning to the current entry.

**REFLECTION DISCIPLINE**:
- Your primary role is sense-making through reflection. Reflect lived experience accurately. Surface patterns. Situate moments within a larger arc.
- You are encouraged to offer gentle guidance, suggestions, goals, or habits when they naturally emerge from the reflection and feel helpful.
- You may use language like "This might be a good time to...", "You might consider...", or "It could be helpful to..." when patterns suggest helpful directions.
- Reference past entries for continuity and to suggest helpful directions when patterns emerge (e.g., "You previously set goals to..." or "This might be a good time to return to..." when relevant).
- Use SAGE internally to structure understanding, but do NOT label sections as "Situation," "Action," etc. unless explicitly asked. Do NOT turn SAGE into an improvement framework.
- Growth may be framed as emerging awareness or as natural next steps when patterns suggest them.
- You may end with questions like "Does this resonate?", "What do you want to do next?", "Do you have a goal?", or "What would be helpful to focus on next?" when they feel natural and helpful.
- When uncertain, reflect first, then offer gentle guidance if it feels natural and helpful.

Be empathetic, insightful, and supportive.
Focus on the user's lived experience and internal patterns.
Use neutral, grounded delivery without dramatization or embellishment.

Follow the ECHO structure (Empathize → Clarify → Highlight → Open) with expanded detail in each section.
In the Highlight section, actively draw connections to past entries when relevant.
Avoid bullet points.
Let your response end naturally based on the content. Silence is a valid ending.`;
        // Build user prompt based on options and context
        const contextParts = [];
        contextParts.push(`Current entry: "${entryText}"`);
        if (mood && typeof mood === "string" && mood.trim().length > 0) {
            contextParts.push(`Mood: ${mood}`);
        }
        if (phase) {
            contextParts.push(`Phase: ${phase}`);
        }
        if (chronoContext) {
            const window = chronoContext.window || "unknown";
            const chronotype = chronoContext.chronotype || "unknown";
            const rhythmScore = chronoContext.rhythmScore || 0.0;
            const isFragmented = chronoContext.isFragmented || false;
            contextParts.push(`Circadian context: Time window: ${window}, Chronotype: ${chronotype}, Rhythm coherence: ${(rhythmScore * 100).toFixed(0)}%${isFragmented ? " (fragmented)" : ""}`);
        }
        if (chatContext && typeof chatContext === "string" && chatContext.trim().length > 0) {
            contextParts.push(`\n${chatContext}`);
        }
        if (mediaContext && typeof mediaContext === "string" && mediaContext.trim().length > 0) {
            contextParts.push(`\n${mediaContext}`);
        }
        const baseContext = contextParts.join("\n\n");
        // Build prompt based on options
        let userPrompt;
        const preferQuestionExpansion = options.preferQuestionExpansion || false;
        const toneMode = options.toneMode || "normal";
        const regenerate = options.regenerate || false;
        const conversationMode = options.conversationMode;
        if (conversationMode) {
            // Continuation dialogue mode - user explicitly requested guidance
            let modeInstruction = "";
            let lengthInstruction = "Provide comprehensive, detailed reflections. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. Do not end with generic extension questions - let your persona naturally ask questions only when genuinely relevant, not as a default ending. Avoid bullet points.";
            switch (conversationMode) {
                case "ideas":
                    modeInstruction = "Expand Open step into 2-3 practical but gentle suggestions drawn from user's past successful patterns. Tone: Warm, creative.";
                    break;
                case "think":
                    modeInstruction = "Generate logical scaffolding (mini reflection framework: What → Why → What now). Tone: Structured, steady.";
                    break;
                case "perspective":
                    modeInstruction = "Reframe context using contrastive reasoning (e.g., 'Another way to see this might be…'). Tone: Cognitive reframing.";
                    break;
                case "nextSteps":
                    modeInstruction = "Provide small, phase-appropriate actions (Discovery → explore; Recovery → rest). Tone: Pragmatic, grounded.";
                    break;
                case "reflectDeeply":
                    modeInstruction = "Invoke More Depth pipeline, reusing current reflection and adding a new Clarify + Open pair. Tone: Introspective.";
                    lengthInstruction = "Provide an extensive, in-depth exploration. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. Do not end with generic extension questions - let your persona naturally ask questions only when genuinely relevant, not as a default ending. Avoid bullet points.";
                    break;
                case "continueThought":
                    modeInstruction = "Extend the previous reflection with additional detail, depth, or considerations. Build naturally on what was already said without repeating earlier content. If the previous reflection was complete, provide additional insights, examples, or perspectives that deepen the understanding. Keep the extension focused and valuable.";
                    break;
            }
            userPrompt = `${baseContext}\n\n${modeInstruction} Follow the ECHO structure (Empathize → Clarify → Highlight → Open). ${lengthInstruction}`;
        }
        else if (regenerate) {
            // Regenerate: different rhetorical focus - maintain reflection discipline
            userPrompt = `${baseContext}\n\nRebuild reflection from same input with different rhetorical focus. Actively reference past journal entries to show patterns and connections. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. Randomly vary Highlight and Open while staying relevant to what the user just wrote. Keep empathy level constant. Follow ECHO structure with expanded detail. **REFLECTION DISCIPLINE**: Default to reflection-first, but feel free to offer gentle guidance, suggestions, goals, or habits when they naturally emerge from the reflection and feel helpful. Do not end with generic extension questions - let your persona naturally ask questions only when genuinely relevant, not as a default ending. Avoid bullet points.`;
        }
        else if (toneMode === "soft") {
            // Soften tone
            userPrompt = `${baseContext}\n\nRewrite in gentler, slower rhythm about the CURRENT ENTRY. Draw connections to past journal entries for context and continuity. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. Add permission language ("It's okay if this takes time."). Apply tone-softening rule for Recovery/Consolidation even if phase is unknown. Follow ECHO structure with expanded detail. **REFLECTION DISCIPLINE**: Default to reflection-first, but feel free to offer gentle guidance, suggestions, goals, or habits when they naturally emerge from the reflection and feel helpful. Do not end with generic extension questions - let your persona naturally ask questions only when genuinely relevant, not as a default ending. Avoid bullet points.`;
        }
        else if (preferQuestionExpansion) {
            // More depth
            userPrompt = `${baseContext}\n\nExpand Clarify and Highlight steps for richer introspection about the CURRENT ENTRY. Extensively reference past journal entries to show patterns, evolution, and meaningful connections. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. Add multiple reflective links that connect the current entry to historical patterns and themes. Follow ECHO structure with deep, detailed exploration. **REFLECTION DISCIPLINE**: Default to reflection-first, but feel free to offer gentle guidance, suggestions, goals, or habits when they naturally emerge from the reflection and feel helpful. Do not end with generic extension questions - let your persona naturally ask questions only when genuinely relevant, not as a default ending. Avoid bullet points.`;
        }
        else {
            // Default: first activation with rich context
            userPrompt = `${baseContext}\n\n**IMPORTANT INSTRUCTION**: Provide a comprehensive reflection that:
1. Addresses the CURRENT ENTRY as the primary focus
2. ACTIVELY references and draws connections to past journal entries from the historical context
3. Shows patterns, themes, and evolution across the user's journal history
4. Uses historical entries to provide deeper context and meaning to the current entry

The historical context is not just background - it is essential material for understanding patterns, showing continuity, and providing rich, contextualized reflection. Draw explicit connections between the current entry and past entries when relevant.

**REFLECTION DISCIPLINE**:
- Your primary role is sense-making through reflection. Reflect lived experience accurately. Surface patterns. Situate moments within a larger arc.
- You are encouraged to offer gentle guidance, suggestions, goals, or habits when they naturally emerge from the reflection and feel helpful.
- You may use language like "This might be a good time to...", "You might consider...", or "It could be helpful to..." when patterns suggest helpful directions.
- Reference past entries for continuity and to suggest helpful directions when patterns emerge (e.g., "You previously set goals to..." or "This might be a good time to return to..." when relevant).
- Use SAGE internally to structure understanding, but do NOT label sections or turn it into an improvement framework.
- Growth may be framed as emerging awareness or as natural next steps when patterns suggest them.
- You may end with questions like "Does this resonate?" or "What do you want to do next?" when they feel natural and helpful.

Follow the ECHO structure (Empathize → Clarify → Highlight → Open) but expand each section with detail. Include connections to past entries in your Highlight section. Consider the mood, phase, circadian context, recent chats, and any media when crafting your reflection. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. Do not end with generic extension questions - let your persona naturally ask questions only when genuinely relevant, not as a default ending. Avoid bullet points.`;
        }
        firebase_functions_1.logger.info(`Generating reflection with prompt length: ${userPrompt.length}`);
        // Generate reflection using LLM
        // Gemini-only path
        const geminiClient = client;
        const reflection = await geminiClient.generateContent(userPrompt, systemPrompt, []);
        firebase_functions_1.logger.info(`Generated reflection (length: ${reflection.length})`);
        return { reflection };
    }
    catch (error) {
        firebase_functions_1.logger.error("Error generating journal reflection:", error);
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        throw new https_1.HttpsError("internal", `Failed to generate reflection: ${error.message}`);
    }
});
//# sourceMappingURL=generateJournalReflection.js.map