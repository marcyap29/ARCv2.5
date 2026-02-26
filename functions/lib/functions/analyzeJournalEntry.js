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
const crisis_detector_1 = require("../sentinel/crisis_detector");
const resolve_1 = require("../prism/rivet/resolve");
const crisisTemplates_1 = require("../services/crisisTemplates");
const crisisIntervention_1 = require("../services/crisisIntervention");
const db = admin_1.admin.firestore();
/**
 * Analyze a journal entry
 *
 * Flow:
 * 1. Verify Firebase Auth token (automatic via onCall)
 * 2. LOCAL ANALYSIS FIRST: SENTINEL crisis detection
 * 3. Check intervention level and limited mode
 * 4. RESOLVE recovery tracking
 * 5. If safe: Route to appropriate model (FREE: Gemini Flash, PAID: Gemini Pro)
 * 6. Generate analysis using LLM OR crisis template
 * 7. Increment analysis count
 * 8. Return structured analysis
 *
 * API Shape (preserved for frontend compatibility):
 * httpsCallable('analyzeJournalEntry')
 *
 * Request: { entryId: string, entryContent: string }
 * Response: { summary, themes, suggestions, tier, ...crisis data }
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
        const userEmail = request.auth?.token?.email;
        // Check if testing account
        const isTestingAccount = user.isTestingAccount || false;
        // ============================================
        // PHASE 1: LOCAL ANALYSIS (ALWAYS RUNS FIRST)
        // ============================================
        firebase_functions_1.logger.info('Starting local analysis pipeline', { userId });
        // Step 1: SENTINEL - Internal crisis detection
        const startTime = Date.now();
        const sentinelResult = (0, crisis_detector_1.detectCrisisEnhanced)(entryContent);
        const detectionTime = Date.now() - startTime;
        firebase_functions_1.logger.info('Internal crisis detection complete', {
            userId,
            detectionTimeMs: detectionTime,
            crisis_detected: sentinelResult.crisis_detected,
            crisis_score: sentinelResult.crisis_score,
            crisis_level: sentinelResult.crisis_level
        });
        // Step 2: Determine intervention level if crisis detected
        let interventionLevel = null;
        if (sentinelResult.crisis_detected) {
            interventionLevel = await (0, crisisIntervention_1.determineInterventionLevel)(userId, sentinelResult);
            firebase_functions_1.logger.warn('🚨 CRISIS DETECTED', {
                userId,
                level: sentinelResult.crisis_level,
                score: sentinelResult.crisis_score,
                intervention_level: interventionLevel.level,
                intervention_action: interventionLevel.action
            });
            // Save crisis state to entry document
            await db.collection('users').doc(userId)
                .collection('journal_entries').doc(entryId)
                .set({
                sentinel_result: {
                    crisis_detected: sentinelResult.crisis_detected,
                    crisis_score: sentinelResult.crisis_score,
                    crisis_level: sentinelResult.crisis_level,
                    detected_patterns: sentinelResult.detected_patterns,
                    intensity_factors: sentinelResult.intensity_factors,
                    confidence: sentinelResult.confidence,
                    timestamp: admin_1.admin.firestore.FieldValue.serverTimestamp()
                }
            }, { merge: true });
            // Activate limited mode if level 3
            if (interventionLevel.level === 3) {
                await (0, crisisIntervention_1.activateLimitedMode)(userId, interventionLevel.limited_mode_duration_hours);
            }
            // Return crisis response based on intervention level
            if (interventionLevel.level === 2) {
                // Level 2: Require acknowledgment
                return {
                    success: true,
                    crisis_detected: true,
                    crisis_level: sentinelResult.crisis_level,
                    crisis_score: sentinelResult.crisis_score,
                    intervention_level: interventionLevel.level,
                    requires_acknowledgment: true,
                    acknowledgment_message: interventionLevel.message,
                    reflection: (0, crisisTemplates_1.generateCrisisTemplate)(sentinelResult),
                    used_gemini: false,
                    processing_path: 'crisis_template_level_2',
                    detection_time_ms: detectionTime,
                    summary: (0, crisisTemplates_1.generateCrisisTemplate)(sentinelResult),
                    themes: ['Crisis support', 'Professional help', 'Safety'],
                    suggestions: [
                        'Reach out to National Suicide Prevention Lifeline: 988',
                        'Text Crisis Text Line: HOME to 741741',
                        'Call Emergency Services: 911 if in immediate danger'
                    ],
                    tier
                };
            }
            if (interventionLevel.level === 3) {
                // Level 3: Limited mode (no AI reflection)
                return {
                    success: true,
                    crisis_detected: true,
                    crisis_level: sentinelResult.crisis_level,
                    crisis_score: sentinelResult.crisis_score,
                    intervention_level: interventionLevel.level,
                    limited_mode: true,
                    limited_mode_message: interventionLevel.message,
                    reflection: null, // No AI reflection in limited mode
                    used_gemini: false,
                    processing_path: 'limited_mode',
                    detection_time_ms: detectionTime,
                    summary: interventionLevel.message || '',
                    themes: [],
                    suggestions: [],
                    tier
                };
            }
            // Level 1: Standard crisis response
            const crisisReflection = (0, crisisTemplates_1.generateCrisisTemplate)(sentinelResult);
            return {
                success: true,
                crisis_detected: true,
                crisis_level: sentinelResult.crisis_level,
                crisis_score: sentinelResult.crisis_score,
                intervention_level: interventionLevel.level,
                reflection: crisisReflection,
                used_gemini: false,
                processing_path: 'crisis_template_level_1',
                detection_time_ms: detectionTime,
                summary: crisisReflection,
                themes: ['Crisis support', 'Professional help', 'Safety'],
                suggestions: [
                    'Reach out to National Suicide Prevention Lifeline: 988',
                    'Text Crisis Text Line: HOME to 741741',
                    'Call Emergency Services: 911 if in immediate danger'
                ],
                tier
            };
        }
        // Step 3: Check if user is in limited mode (from previous crisis)
        const inLimitedMode = await (0, crisisIntervention_1.isInLimitedMode)(userId);
        if (inLimitedMode) {
            firebase_functions_1.logger.info('User in limited mode - no AI reflection', { userId });
            return {
                success: true,
                crisis_detected: false,
                limited_mode: true,
                limited_mode_message: `You're still in limited mode from a recent crisis. You can continue journaling, but AI reflections are paused to encourage professional support.

This will expire automatically. In the meantime, please reach out:
• Lifeline: 988
• Crisis Text: HOME to 741741`,
                reflection: null,
                used_gemini: false,
                processing_path: 'limited_mode_active',
                summary: 'Entry saved. Limited mode active.',
                themes: [],
                suggestions: [],
                tier
            };
        }
        // Step 4: RESOLVE - Recovery tracking
        const resolveResult = await (0, resolve_1.calculateRESOLVE)(userId);
        firebase_functions_1.logger.info('Local analysis complete', {
            userId,
            resolve_active: resolveResult.cooldown_active,
            recovery_phase: resolveResult.recovery_phase
        });
        // ============================================
        // PHASE 2: DECIDE IF EXTERNAL API NEEDED
        // ============================================
        let analysisText;
        let usedGemini = false;
        // Testing accounts NEVER use Gemini
        if (isTestingAccount) {
            firebase_functions_1.logger.info('🧪 Testing account - using mock response');
            analysisText = generateTestModeReflection({
                sentinel: sentinelResult,
                resolve: resolveResult,
                entryContent
            });
            usedGemini = false;
        }
        // Safe to use Gemini
        else {
            firebase_functions_1.logger.info('✓ Safe for Gemini - proceeding to API');
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
            const modelFamily = await modelRouter_1.ModelRouter.selectModelWithFailover(tier, "journal_analysis");
            const modelConfig = modelRouter_1.ModelRouter.getConfig(modelFamily);
            const client = (0, llmClients_1.createLLMClient)(modelConfig);
            firebase_functions_1.logger.info(`Using model: ${modelFamily} (${modelConfig.modelId}) - Internal only, not exposed to user`);
            // Build analysis prompt
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
            if (modelConfig.family === "GEMINI_FLASH" || modelConfig.family === "GEMINI_PRO") {
                const geminiClient = client;
                analysisText = await geminiClient.generateContent(analysisPrompt, systemPrompt);
            }
            else {
                // Claude or other clients
                const claudeClient = client;
                analysisText = await claudeClient.generateMessage(analysisPrompt, systemPrompt);
            }
            usedGemini = true;
        }
        // ============================================
        // PHASE 3: PARSE AND RETURN RESULTS
        // ============================================
        // Parse the analysis
        const summary = extractSummary(analysisText);
        const themes = extractThemes(analysisText);
        const suggestions = extractSuggestions(analysisText);
        // Increment analysis count
        await (0, quotaGuards_1.incrementAnalysisCount)(entryId);
        // Build response
        const response = {
            summary,
            themes,
            suggestions,
            tier,
            success: true,
            crisis_detected: sentinelResult.crisis_detected,
            crisis_level: sentinelResult.crisis_level,
            crisis_score: sentinelResult.crisis_score,
            intervention_level: interventionLevel ? interventionLevel.level : 0,
            used_gemini: usedGemini,
            processing_path: isTestingAccount ? 'mock' :
                sentinelResult.crisis_detected ? 'crisis_template' :
                    'gemini_api',
            detection_time_ms: detectionTime,
            resolve: resolveResult
        };
        firebase_functions_1.logger.info(`Analysis complete for entry ${entryId}`, {
            processing_path: response.processing_path,
            used_gemini: response.used_gemini
        });
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
// ============================================
// HELPER: Test Mode Reflection
// ============================================
function generateTestModeReflection(data) {
    const { sentinel, resolve } = data;
    if (sentinel.crisis_detected) {
        return `[TESTING MODE - Crisis Detected]
Score: ${sentinel.crisis_score}
Level: ${sentinel.crisis_level}

${(0, crisisTemplates_1.generateCrisisTemplate)(sentinel)}`;
    }
    if (resolve.cooldown_active) {
        return `[TESTING MODE - Recovery Active]
Phase: ${resolve.recovery_phase}
Days Stable: ${resolve.days_stable}
RESOLVE Score: ${resolve.resolve_score}/100

You're in active recovery. I see progress in your journey.`;
    }
    return `[TESTING MODE - Normal Processing]
This is a simulated reflection for testing purposes.
Entry length: ${data.entryContent.length} characters`;
}
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