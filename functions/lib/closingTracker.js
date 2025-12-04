"use strict";
/**
 * LUMARA Closing Statement Tracker
 *
 * Programmatic enforcement of closing statement rotation and preference learning.
 * Prevents repetition and learns user preferences over time.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.trackClosingUsage = trackClosingUsage;
exports.getRecentlyUsedClosings = getRecentlyUsedClosings;
exports.selectClosingStatement = selectClosingStatement;
exports.classifyConversationCategory = classifyConversationCategory;
exports.detectEnergyLevel = detectEnergyLevel;
exports.getUserPreferences = getUserPreferences;
exports.resetUserPreferences = resetUserPreferences;
const closingPatterns_js_1 = require("./closingPatterns.js");
/**
 * In-memory store for closing usage tracking
 * In production, this would be backed by Firestore
 */
const closingUsageStore = new Map();
const userPreferencesStore = new Map();
/**
 * Track usage of a closing statement
 */
function trackClosingUsage(userId, conversationId, closingId, atlasPhase, userResponse) {
    const closing = closingPatterns_js_1.CLOSING_PATTERNS.find(p => p.id === closingId);
    if (!closing) {
        console.warn(`Unknown closing pattern ID: ${closingId}`);
        return;
    }
    const usage = {
        closingId,
        timestamp: new Date(),
        atlasPhase,
        category: closing.category,
        style: closing.style,
        userResponse,
        conversationId
    };
    // Store usage
    const userUsages = closingUsageStore.get(userId) || [];
    userUsages.push(usage);
    closingUsageStore.set(userId, userUsages);
    // Update user preferences
    updateUserPreferences(userId, usage);
}
/**
 * Update user preferences based on closing usage
 */
function updateUserPreferences(userId, usage) {
    let prefs = userPreferencesStore.get(userId);
    if (!prefs) {
        prefs = {
            userId,
            mutedClosingIds: [],
            favoriteClosingIds: [],
            categoryWeights: {
                reflection_emotion: 0,
                planning_action: 0,
                identity_phase: 0,
                regulation_overwhelm: 0,
                neutral_light: 0
            },
            styleWeights: {
                soft_question: 0,
                reflective_echo: 0,
                gentle_prompt: 0,
                non_prompt_closure: 0,
                pause_affirmation: 0,
                next_step_suggestion: 0,
                user_led_turn: 0
            },
            phaseWeights: {},
            recentHistory: [],
            lastUpdated: new Date()
        };
    }
    // Update recent history (sliding window of 20 items)
    prefs.recentHistory.unshift({
        closingId: usage.closingId,
        usedAt: usage.timestamp
    });
    prefs.recentHistory = prefs.recentHistory.slice(0, 20);
    // Update weights based on user response
    if (usage.userResponse) {
        const scoreChange = getScoreChange(usage.userResponse);
        prefs.categoryWeights[usage.category] += scoreChange;
        prefs.styleWeights[usage.style] += scoreChange;
        // Phase-specific weights
        if (usage.atlasPhase) {
            if (!prefs.phaseWeights[usage.atlasPhase]) {
                prefs.phaseWeights[usage.atlasPhase] = {};
            }
            const phaseWeight = prefs.phaseWeights[usage.atlasPhase];
            if (phaseWeight) {
                phaseWeight[usage.closingId] = (phaseWeight[usage.closingId] || 0) + scoreChange;
            }
        }
        // Handle muting/favoriting
        if (usage.userResponse === 'rejected') {
            if (!prefs.mutedClosingIds.includes(usage.closingId)) {
                prefs.mutedClosingIds.push(usage.closingId);
            }
        }
        else if (usage.userResponse === 'accepted') {
            if (!prefs.favoriteClosingIds.includes(usage.closingId)) {
                prefs.favoriteClosingIds.push(usage.closingId);
            }
        }
    }
    prefs.lastUpdated = new Date();
    userPreferencesStore.set(userId, prefs);
}
/**
 * Get score change based on user response
 */
function getScoreChange(response) {
    switch (response) {
        case 'accepted': return 2;
        case 'continued': return 1;
        case 'silence': return -1;
        case 'rejected': return -3;
        default: return 0;
    }
}
/**
 * Get recently used closing IDs for a user
 */
function getRecentlyUsedClosings(userId, lookbackCount = 15) {
    const prefs = userPreferencesStore.get(userId);
    if (!prefs)
        return [];
    return prefs.recentHistory
        .slice(0, lookbackCount)
        .map(h => h.closingId);
}
/**
 * Select an appropriate closing statement with programmatic rotation enforcement
 */
function selectClosingStatement(userId, conversationId, category, atlasPhase, energyLevel) {
    // Get user preferences
    const prefs = userPreferencesStore.get(userId);
    const recentlyUsed = getRecentlyUsedClosings(userId, 15);
    const mutedIds = prefs?.mutedClosingIds || [];
    // Filter available closings
    let candidates = closingPatterns_js_1.CLOSING_PATTERNS.filter(pattern => {
        // Must match category
        if (pattern.category !== category)
            return false;
        // Must not be recently used
        if (recentlyUsed.includes(pattern.id))
            return false;
        // Must not be muted
        if (mutedIds.includes(pattern.id))
            return false;
        // Must match phase bias (if specified)
        if (atlasPhase && !pattern.phase_bias.includes(atlasPhase) && !pattern.phase_bias.includes("Any")) {
            return false;
        }
        // Must match energy level (if specified)
        if (energyLevel && pattern.energy_level !== energyLevel && pattern.energy_level !== 'medium') {
            return false;
        }
        return true;
    });
    if (candidates.length === 0) {
        // Fallback: allow recently used if we have no other options
        console.warn(`No available closings for category ${category}, using fallback`);
        candidates = closingPatterns_js_1.CLOSING_PATTERNS.filter(p => p.category === category && !mutedIds.includes(p.id));
    }
    if (candidates.length === 0) {
        console.error(`No closings available for category ${category}`);
        return null;
    }
    // Weight candidates based on preferences
    const weightedCandidates = candidates.map(pattern => {
        let weight = 1.0;
        if (prefs) {
            // Category preference
            weight += (prefs.categoryWeights[pattern.category] || 0) * 0.1;
            // Style preference
            weight += (prefs.styleWeights[pattern.style] || 0) * 0.1;
            // Phase-specific preference
            if (atlasPhase && prefs.phaseWeights[atlasPhase]) {
                weight += (prefs.phaseWeights[atlasPhase][pattern.id] || 0) * 0.2;
            }
            // Boost favorites
            if (prefs.favoriteClosingIds.includes(pattern.id)) {
                weight += 1.0;
            }
        }
        return { pattern, weight: Math.max(0.1, weight) }; // Minimum weight of 0.1
    });
    // Select using weighted random
    const totalWeight = weightedCandidates.reduce((sum, c) => sum + c.weight, 0);
    const random = Math.random() * totalWeight;
    let accumulator = 0;
    for (const candidate of weightedCandidates) {
        accumulator += candidate.weight;
        if (random <= accumulator) {
            // Track this selection
            trackClosingUsage(userId, conversationId, candidate.pattern.id, atlasPhase);
            return candidate.pattern;
        }
    }
    // Fallback to first candidate
    const selected = weightedCandidates[0].pattern;
    trackClosingUsage(userId, conversationId, selected.id, atlasPhase);
    return selected;
}
/**
 * Classify conversation category based on content analysis
 */
function classifyConversationCategory(messageContent, atlasPhase) {
    const content = messageContent.toLowerCase();
    // Keywords for each category (improved with better specificity)
    const emotionKeywords = ['feel', 'feeling', 'emotion', 'sad', 'happy', 'angry', 'anxious', 'upset', 'processing', 'reflecting', 'emotional'];
    const planningKeywords = ['next steps', 'next step', 'action', 'do', 'plan', 'should', 'could', 'might', 'need to', 'going to', 'will', 'figure out'];
    const identityKeywords = ['changing', 'becoming', 'growth', 'phase', 'transition', 'who i am', 'identity', 'self', 'person i am', 'changing as'];
    const overwhelmKeywords = ['overwhelmed', 'too much', 'stressed', 'exhausted', 'tired', 'heavy', 'difficult', 'hard', 'struggling'];
    // Specific identity phrases get bonus points
    const identityPhrases = ['changing as a person', 'who i am', 'becoming', 'feel like i\'m changing'];
    const hasIdentityPhrase = identityPhrases.some(phrase => content.includes(phrase));
    // Processing vs overwhelm distinction - processing emotions is reflection, not regulation
    const isProcessingEmotion = content.includes('processing') && content.includes('emotion');
    // Count keyword matches
    const emotionCount = emotionKeywords.filter(kw => content.includes(kw)).length;
    const planningCount = planningKeywords.filter(kw => content.includes(kw)).length;
    const identityCount = identityKeywords.filter(kw => content.includes(kw)).length + (hasIdentityPhrase ? 3 : 0);
    const overwhelmCount = overwhelmKeywords.filter(kw => content.includes(kw)).length;
    // Check for overwhelm first (highest priority) - but not if it's clearly processing
    if (overwhelmCount > 0 && !isProcessingEmotion) {
        return 'regulation_overwhelm';
    }
    if (content.includes('can\'t') || content.includes('don\'t know')) {
        return 'regulation_overwhelm';
    }
    // Phase-based heuristics
    if (atlasPhase === 'Recovery') {
        return emotionCount > 0 ? 'regulation_overwhelm' : 'reflection_emotion';
    }
    if (atlasPhase === 'Breakthrough' || atlasPhase === 'Transition') {
        return identityCount > planningCount ? 'identity_phase' : 'planning_action';
    }
    // Content-based classification with better identity detection
    const maxCount = Math.max(emotionCount, planningCount, identityCount);
    if (maxCount === 0)
        return 'neutral_light';
    if (identityCount === maxCount && identityCount > 0)
        return 'identity_phase';
    if (planningCount === maxCount && planningCount > 0)
        return 'planning_action';
    if (emotionCount === maxCount)
        return isProcessingEmotion ? 'reflection_emotion' : 'reflection_emotion';
    return 'neutral_light';
}
/**
 * Detect energy level from message content
 */
function detectEnergyLevel(messageContent) {
    const content = messageContent.toLowerCase();
    const lowEnergyIndicators = ['tired', 'exhausted', 'drained', 'heavy', 'slow', 'quiet', 'rest'];
    const highEnergyIndicators = ['excited', 'energized', 'motivated', 'breakthrough', 'amazing', 'incredible', 'powerful'];
    const lowCount = lowEnergyIndicators.filter(indicator => content.includes(indicator)).length;
    const highCount = highEnergyIndicators.filter(indicator => content.includes(indicator)).length;
    if (lowCount > highCount)
        return 'low';
    if (highCount > lowCount)
        return 'high';
    return 'medium';
}
/**
 * Get user preferences (for debugging/analytics)
 */
function getUserPreferences(userId) {
    return userPreferencesStore.get(userId) || null;
}
/**
 * Reset user preferences (for testing)
 */
function resetUserPreferences(userId) {
    userPreferencesStore.delete(userId);
    closingUsageStore.delete(userId);
}
//# sourceMappingURL=closingTracker.js.map