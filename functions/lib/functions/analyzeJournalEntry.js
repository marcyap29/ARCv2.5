"use strict";
// functions/analyzeJournalEntry.ts - Journal entry analysis Cloud Function
Object.defineProperty(exports, "__esModule", { value: true });
exports.analyzeJournalEntry = void 0;
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
exports.analyzeJournalEntry = (0, https_1.onCall)({
    secrets: [config_1.GEMINI_API_KEY],
}, async (request) => {
    const { entryId, entryContent } = request.data;
    // Validate request
    if (!entryId || !entryContent) {
        throw new https_1.HttpsError("invalid-argument", "entryId and entryContent are required");
    }
    const userId = request.auth?.uid;
    if (!userId) {
        throw new https_1.HttpsError("unauthenticated", "User must be authenticated");
    }
    firebase_functions_1.logger.info(`Analyzing journal entry ${entryId} for user ${userId}`);
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
        // Check legacy per-entry quota (secondary, for backward compatibility)
        const quotaCheck = await (0, quotaGuards_1.checkCanAnalyzeEntry)(userId, entryId);
        if (!quotaCheck.allowed) {
            throw new https_1.HttpsError("resource-exhausted", quotaCheck.error?.message || "Quota limit reached", quotaCheck.error);
        }
        // Select model (internal only - Gemini by default)
        const modelFamily = await modelRouter_1.ModelRouter.selectModelWithFailover(tier, "journal_analysis");
        const modelConfig = modelRouter_1.ModelRouter.getConfig(modelFamily);
        const client = (0, llmClients_1.createLLMClient)(modelConfig);
        firebase_functions_1.logger.info(`Using model: ${modelFamily} (${modelConfig.modelId}) - Internal only, not exposed to user`);
        // Build analysis prompt (journal analysis doesn't need web access, but uses same LUMARA principles)
        const systemPrompt = `You are LUMARA, the Life-aware Unified Memory and Reflection Assistant built on the EPI stack.
You analyze journal entries to provide:
1. A concise summary (2-3 sentences)
2. Key themes (3-5 themes)
3. Actionable suggestions (2-3 suggestions)

Be empathetic, insightful, and supportive.
Focus on the user's lived experience and internal patterns.
Use neutral, grounded delivery without dramatization or embellishment.`;
        const analysisPrompt = `Please analyze this journal entry:

${entryContent}

Provide a structured analysis with:
- Summary: A brief overview of the entry
- Themes: Key themes or patterns you notice
- Suggestions: Actionable suggestions for reflection or growth`;
        // Generate analysis
        // Handle different client types (Gemini uses generateContent, Claude uses generateMessage)
        let analysisText;
        if (modelConfig.family === "GEMINI_FLASH" || modelConfig.family === "GEMINI_PRO") {
            const geminiClient = client;
            analysisText = await geminiClient.generateContent(analysisPrompt, systemPrompt);
        }
        else {
            // Claude or other clients
            const claudeClient = client;
            analysisText = await claudeClient.generateMessage(analysisPrompt, systemPrompt);
        }
        // Parse the analysis (in production, you might want more structured parsing)
        // For now, we'll extract summary, themes, and suggestions from the response
        const summary = extractSummary(analysisText);
        const themes = extractThemes(analysisText);
        const suggestions = extractSuggestions(analysisText);
        // Increment analysis count
        await (0, quotaGuards_1.incrementAnalysisCount)(entryId);
        // Build response (modelUsed removed - internal only)
        const response = {
            summary,
            themes,
            suggestions,
            tier,
            // modelUsed removed - not exposed to users
        };
        firebase_functions_1.logger.info(`Analysis complete for entry ${entryId}`);
        return response;
    }
    catch (error) {
        firebase_functions_1.logger.error("Error analyzing journal entry:", error);
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        throw new https_1.HttpsError("internal", "Failed to analyze journal entry", error);
    }
});
/**
 * Helper functions to parse LLM response
 * In production, you might want to use structured output or JSON mode
 */
function extractSummary(text) {
    // Look for "Summary:" or similar patterns
    const summaryMatch = text.match(/(?:Summary|Overview)[:\-]?\s*(.+?)(?:\n\n|Themes|Suggestions|$)/is);
    return summaryMatch ? summaryMatch[1].trim() : text.split("\n\n")[0] || text.substring(0, 200);
}
function extractThemes(text) {
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
function extractSuggestions(text) {
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
//# sourceMappingURL=analyzeJournalEntry.js.map