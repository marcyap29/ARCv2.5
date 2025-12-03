// functions/analyzeJournalEntry.ts - Journal entry analysis Cloud Function

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { admin } from "../admin";
import { ModelRouter } from "../modelRouter";
import { checkCanAnalyzeEntry, incrementAnalysisCount } from "../quotaGuards";
import { checkRateLimit } from "../rateLimiter";
import { createLLMClient } from "../llmClients";
import {
  SubscriptionTier,
  AnalysisResponse,
  UserDocument,
} from "../types";
import {
  GEMINI_API_KEY,
  ANTHROPIC_API_KEY,
} from "../config";

const db = admin.firestore();

/**
 * Analyze a journal entry
 * 
 * Flow:
 * 1. Verify Firebase Auth token (automatic via onCall)
 * 2. Load user and entry from Firestore
 * 3. Check quota (free tier: max 4 analyses per entry)
 * 4. Route to appropriate model (FREE: Gemini Flash, PAID: Gemini Pro)
 * 5. Generate analysis using LLM
 * 6. Increment analysis count
 * 7. Return structured analysis
 * 
 * API Shape (preserved for frontend compatibility):
 * httpsCallable('analyzeJournalEntry')
 * 
 * Request: { entryId: string, entryContent: string }
 * Response: { summary, themes, suggestions, tier, modelUsed }
 */
export const analyzeJournalEntry = onCall(
  {
    secrets: [GEMINI_API_KEY, ANTHROPIC_API_KEY],
  },
  async (request) => {
    const { entryId, entryContent } = request.data;

    // Validate request
    if (!entryId || !entryContent) {
      throw new HttpsError(
        "invalid-argument",
        "entryId and entryContent are required"
      );
    }

    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    logger.info(`Analyzing journal entry ${entryId} for user ${userId}`);

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

      // Check legacy per-entry quota (secondary, for backward compatibility)
      const quotaCheck = await checkCanAnalyzeEntry(userId, entryId);
      if (!quotaCheck.allowed) {
        throw new HttpsError(
          "resource-exhausted",
          quotaCheck.error?.message || "Quota limit reached",
          quotaCheck.error
        );
      }

      // Select model (internal only - Gemini by default)
      const modelFamily = await ModelRouter.selectModelWithFailover(tier, "journal_analysis");
      const modelConfig = ModelRouter.getConfig(modelFamily);
      const client = createLLMClient(modelConfig);

      logger.info(`Using model: ${modelFamily} (${modelConfig.modelId}) - Internal only, not exposed to user`);

      // Build analysis prompt
      const systemPrompt = `You are a thoughtful journaling assistant. Analyze journal entries to provide:
1. A concise summary (2-3 sentences)
2. Key themes (3-5 themes)
3. Actionable suggestions (2-3 suggestions)

Be empathetic, insightful, and supportive.`;

      const analysisPrompt = `Please analyze this journal entry:

${entryContent}

Provide a structured analysis with:
- Summary: A brief overview of the entry
- Themes: Key themes or patterns you notice
- Suggestions: Actionable suggestions for reflection or growth`;

      // Generate analysis
      // Handle different client types (Gemini uses generateContent, Claude uses generateMessage)
      let analysisText: string;
      if (modelConfig.family === "GEMINI_FLASH" || modelConfig.family === "GEMINI_PRO") {
        const geminiClient = client as any;
        analysisText = await geminiClient.generateContent(
          analysisPrompt,
          systemPrompt
        );
      } else {
        // Claude or other clients
        const claudeClient = client as any;
        analysisText = await claudeClient.generateMessage(
          analysisPrompt,
          systemPrompt
        );
      }

      // Parse the analysis (in production, you might want more structured parsing)
      // For now, we'll extract summary, themes, and suggestions from the response
      const summary = extractSummary(analysisText);
      const themes = extractThemes(analysisText);
      const suggestions = extractSuggestions(analysisText);

      // Increment analysis count
      await incrementAnalysisCount(entryId);

      // Build response (modelUsed removed - internal only)
      const response: AnalysisResponse = {
        summary,
        themes,
        suggestions,
        tier,
        // modelUsed removed - not exposed to users
      };

      logger.info(`Analysis complete for entry ${entryId}`);

      return response;
    } catch (error) {
      logger.error("Error analyzing journal entry:", error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        "internal",
        "Failed to analyze journal entry",
        error
      );
    }
  }
);

/**
 * Helper functions to parse LLM response
 * In production, you might want to use structured output or JSON mode
 */
function extractSummary(text: string): string {
  // Look for "Summary:" or similar patterns
  const summaryMatch = text.match(/(?:Summary|Overview)[:\-]?\s*(.+?)(?:\n\n|Themes|Suggestions|$)/is);
  return summaryMatch ? summaryMatch[1].trim() : text.split("\n\n")[0] || text.substring(0, 200);
}

function extractThemes(text: string): string[] {
  // Look for "Themes:" section
  const themesMatch = text.match(/(?:Themes|Key Themes|Patterns)[:\-]?\s*(.+?)(?:\n\n|Suggestions|$)/is);
  if (!themesMatch) {
    return [];
  }
  
  // Extract bullet points or numbered items
  const themesText = themesMatch[1];
  const themeLines = themesText
    .split(/\n/)
    .map(line => line.replace(/^[\-\*•\d+\.]\s*/, "").trim())
    .filter(line => line.length > 0);
  
  return themeLines.slice(0, 5); // Max 5 themes
}

function extractSuggestions(text: string): string[] {
  // Look for "Suggestions:" section
  const suggestionsMatch = text.match(/(?:Suggestions|Recommendations|Actions)[:\-]?\s*(.+?)$/is);
  if (!suggestionsMatch) {
    return [];
  }
  
  const suggestionsText = suggestionsMatch[1];
  const suggestionLines = suggestionsText
    .split(/\n/)
    .map(line => line.replace(/^[\-\*•\d+\.]\s*/, "").trim())
    .filter(line => line.length > 0);
  
  return suggestionLines.slice(0, 3); // Max 3 suggestions
}

