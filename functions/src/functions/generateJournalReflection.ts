// functions/generateJournalReflection.ts - In-journal LUMARA reflection Cloud Function

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { admin } from "../admin";
import { ModelRouter } from "../modelRouter";
import { checkRateLimit } from "../rateLimiter";
import { createLLMClient } from "../llmClients";
import { enforceAuth } from "../authGuard";
import {
  SubscriptionTier,
} from "../types";
import {
  GEMINI_API_KEY,
} from "../config";

const db = admin.firestore();

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
export const generateJournalReflection = onCall(
  {
    secrets: [GEMINI_API_KEY],
    // Auth enforced via enforceAuth() - no invoker: "public"
  },
  async (request) => {
    const {
      entryText,
      phase,
      mood,
      chronoContext,
      chatContext,
      mediaContext,
      options = {},
    } = request.data;

    // Validate request
    if (!entryText) {
      throw new HttpsError(
        "invalid-argument",
        "entryText is required"
      );
    }

    // Enforce authentication (supports anonymous trial)
    const authResult = await enforceAuth(request);
    const { userId, isAnonymous, trialRemaining, user } = authResult;

    logger.info(`Generating journal reflection for user ${userId} (anonymous: ${isAnonymous}, trial remaining: ${trialRemaining ?? 'N/A'})`);

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

      // Select model (internal only - Gemini by default)
      const modelFamily = await ModelRouter.selectModelWithFailover(tier, "chat_message");
      const modelConfig = ModelRouter.getConfig(modelFamily);
      const client = createLLMClient(modelConfig);

      logger.info(`Using model: ${modelFamily} (${modelConfig.modelId}) for journal reflection`);

      // Build system prompt with LUMARA Master Prompt
      // Note: For journal reflections, we use a simplified version without web access
      // since journal analysis doesn't need web access
      const systemPrompt = `You are LUMARA, the Life-aware Unified Memory and Reflection Assistant built on the EPI stack.
You analyze journal entries to provide:
1. A concise summary (2-3 sentences)
2. Key themes (3-5 themes)
3. Actionable suggestions (2-3 suggestions)

Be empathetic, insightful, and supportive.
Focus on the user's lived experience and internal patterns.
Use neutral, grounded delivery without dramatization or embellishment.

Follow the ECHO structure (Empathize → Clarify → Highlight → Open) when generating reflections.
Return the full reflection as 2-3 complete sentences for standard reflections, or 3-5 sentences for deeper reflections.
Avoid bullet points.`;

      // Build user prompt based on options and context
      const contextParts: string[] = [];
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
        contextParts.push(
          `Circadian context: Time window: ${window}, Chronotype: ${chronotype}, Rhythm coherence: ${(rhythmScore * 100).toFixed(0)}%${isFragmented ? " (fragmented)" : ""}`
        );
      }

      if (chatContext && typeof chatContext === "string" && chatContext.trim().length > 0) {
        contextParts.push(`\n${chatContext}`);
      }

      if (mediaContext && typeof mediaContext === "string" && mediaContext.trim().length > 0) {
        contextParts.push(`\n${mediaContext}`);
      }

      const baseContext = contextParts.join("\n\n");

      // Build prompt based on options
      let userPrompt: string;
      const preferQuestionExpansion = options.preferQuestionExpansion || false;
      const toneMode = options.toneMode || "normal";
      const regenerate = options.regenerate || false;
      const conversationMode = options.conversationMode;

      if (conversationMode) {
        // Continuation dialogue mode
        let modeInstruction = "";
        let lengthInstruction = "Return the full reflection as 2-3 complete sentences so it stays concise inside the journal entry. Avoid bullet points.";
        
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
            lengthInstruction = "Return the full reflection as 3-5 complete sentences to provide noticeably more depth while still avoiding bullet points.";
            break;
          case "continueThought":
            modeInstruction = "Resume the exact reflection that was interrupted. Continue the final idea without restarting context or repeating earlier lines. Pick up mid-sentence if needed.";
            break;
        }
        userPrompt = `${baseContext}\n\n${modeInstruction} Follow the ECHO structure (Empathize → Clarify → Highlight → Open). ${lengthInstruction}`;
      } else if (regenerate) {
        // Regenerate: different rhetorical focus
        userPrompt = `${baseContext}\n\nRebuild reflection from same input with different rhetorical focus. Randomly vary Highlight and Open. Keep empathy level constant. Follow ECHO structure. Return the full reflection as 2-3 complete sentences so it stays concise inside the journal entry. Avoid bullet points.`;
      } else if (toneMode === "soft") {
        // Soften tone
        userPrompt = `${baseContext}\n\nRewrite in gentler, slower rhythm. Reduce question count to 1. Add permission language ("It's okay if this takes time."). Apply tone-softening rule for Recovery/Consolidation even if phase is unknown. Follow ECHO structure. Return the full reflection as 2-3 complete sentences so it stays concise inside the journal entry. Avoid bullet points.`;
      } else if (preferQuestionExpansion) {
        // More depth
        userPrompt = `${baseContext}\n\nExpand Clarify and Highlight steps for richer introspection. Add 1 additional reflective link. Follow ECHO structure with deeper exploration. Return the full reflection as 3-5 complete sentences to provide noticeably more depth while still avoiding bullet points.`;
      } else {
        // Default: first activation with rich context
        userPrompt = `${baseContext}\n\nFollow the ECHO structure (Empathize → Clarify → Highlight → Open) and include 1-2 clarifying expansion questions that help deepen the reflection. Consider the mood, phase, circadian context, recent chats, and any media when crafting questions that feel personally relevant and timely. Be thoughtful and allow for meaningful engagement. Return the full reflection as 2-3 complete sentences so it stays concise inside the journal entry. Avoid bullet points.`;
      }

      logger.info(`Generating reflection with prompt length: ${userPrompt.length}`);

      // Generate reflection using LLM
      // Gemini-only path
      const geminiClient = client as any;
      const reflection: string = await geminiClient.generateContent(userPrompt, systemPrompt, []);

      logger.info(`Generated reflection (length: ${reflection.length})`);

      return { reflection };
    } catch (error: any) {
      logger.error("Error generating journal reflection:", error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", `Failed to generate reflection: ${error.message}`);
    }
  }
);
