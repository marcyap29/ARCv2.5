"use strict";
/**
 * RESOLVE - Crisis Recovery Trajectory Detection
 *
 * Part of RIVET subsystem
 * Tracks recovery momentum from crisis states
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculateRESOLVE = calculateRESOLVE;
const admin_1 = require("../../admin");
const firebase_functions_1 = require("firebase-functions");
const db = admin_1.admin.firestore();
async function calculateRESOLVE(userId) {
    // Get last 7 days of SENTINEL history
    const sentinelHistory = await getLast7DaysSentinel(userId);
    // 1. Check for crisis origin
    const hadRecentCrisis = sentinelHistory.some(s => s.crisis_score >= 70);
    if (!hadRecentCrisis) {
        return {
            resolve_score: 0,
            cooldown_active: false,
            days_stable: 0,
            recovery_phase: 'resolved',
            trajectory: 'flat',
            confidence: 100,
            evidence: {
                had_recent_crisis: false,
                emotional_trend: 0,
                positive_signals: 0,
                entry_consistency: sentinelHistory.length
            }
        };
    }
    // 2. Count consecutive stable days (crisis_score < 70)
    const daysStable = countConsecutiveStableDays(sentinelHistory);
    // 3. Calculate trend (improving/flat/declining)
    const emotionalTrend = calculateEmotionalTrend(sentinelHistory);
    // 4. Check for positive recovery indicators
    const positiveSignals = detectPositiveIndicators(sentinelHistory);
    // 5. Calculate RESOLVE score
    let resolveScore = 0;
    // Base score from stable days (0-40 points)
    resolveScore += Math.min(daysStable * 10, 40);
    // Trend bonus (0-30 points)
    if (emotionalTrend === 'improving') {
        resolveScore += 30;
    }
    else if (emotionalTrend === 'flat') {
        resolveScore += 15;
    }
    // Positive indicators bonus (0-30 points)
    resolveScore += Math.min(positiveSignals.count * 6, 30);
    // 6. Determine recovery phase
    const recoveryPhase = determineRecoveryPhase(resolveScore, daysStable);
    // 7. Calculate confidence
    const confidence = Math.min(sentinelHistory.length * 15, 100);
    return {
        resolve_score: resolveScore,
        cooldown_active: resolveScore >= 40,
        days_stable: daysStable,
        recovery_phase: recoveryPhase,
        trajectory: emotionalTrend,
        confidence: confidence,
        evidence: {
            had_recent_crisis: true,
            emotional_trend: calculateTrendScore(sentinelHistory),
            positive_signals: positiveSignals.count,
            entry_consistency: sentinelHistory.length
        }
    };
}
function determineRecoveryPhase(resolveScore, daysStable) {
    if (daysStable === 0)
        return 'acute';
    if (resolveScore < 40)
        return 'stabilizing';
    if (resolveScore < 70)
        return 'recovering';
    return 'resolved';
}
function countConsecutiveStableDays(history) {
    let count = 0;
    // Count from most recent backwards
    for (let i = history.length - 1; i >= 0; i--) {
        if (history[i].crisis_score < 70) {
            count++;
        }
        else {
            break; // Stop at first crisis day
        }
    }
    return count;
}
function calculateEmotionalTrend(history) {
    if (history.length < 3)
        return 'flat';
    const recent = history.slice(-3);
    const scores = recent.map(h => h.crisis_score);
    // Simple linear trend
    const firstAvg = (scores[0] + scores[1]) / 2;
    const lastAvg = (scores[1] + scores[2]) / 2;
    const change = firstAvg - lastAvg;
    if (change > 10)
        return 'improving'; // Scores decreasing
    if (change < -10)
        return 'declining'; // Scores increasing
    return 'flat';
}
function calculateTrendScore(history) {
    if (history.length < 2)
        return 0;
    const recent = history.slice(-3);
    const scores = recent.map(h => h.crisis_score);
    if (scores.length < 2)
        return 0;
    const firstAvg = scores.slice(0, Math.floor(scores.length / 2))
        .reduce((a, b) => a + b, 0) / Math.floor(scores.length / 2);
    const lastAvg = scores.slice(Math.floor(scores.length / 2))
        .reduce((a, b) => a + b, 0) / Math.ceil(scores.length / 2);
    return firstAvg - lastAvg; // Positive = improving
}
function detectPositiveIndicators(history) {
    const positivePatterns = [
        /feeling better/i,
        /talked to/i,
        /reached out/i,
        /went for a walk/i,
        /getting help/i,
        /making progress/i,
        /small steps/i,
        /one day at a time/i,
        /thank you/i,
        /grateful/i
    ];
    let count = 0;
    for (const entry of history) {
        const text = entry.entry_text || '';
        for (const pattern of positivePatterns) {
            if (pattern.test(text)) {
                count++;
                break; // Count once per entry
            }
        }
    }
    return { count };
}
// Helper to get SENTINEL history
async function getLast7DaysSentinel(userId) {
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    try {
        const entries = await db
            .collection('users')
            .doc(userId)
            .collection('journal_entries')
            .where('timestamp', '>=', admin_1.admin.firestore.Timestamp.fromDate(sevenDaysAgo))
            .orderBy('timestamp', 'asc')
            .get();
        const results = [];
        for (const doc of entries.docs) {
            const data = doc.data();
            const sentinelResult = data.sentinel_result;
            if (sentinelResult) {
                results.push({
                    crisis_score: sentinelResult.crisis_score || 0,
                    crisis_level: sentinelResult.crisis_level || 'NONE',
                    entry_text: data.content || data.entryText || '',
                    timestamp: data.timestamp
                });
            }
        }
        return results;
    }
    catch (error) {
        firebase_functions_1.logger.error('Error fetching SENTINEL history', { userId, error });
        return [];
    }
}
//# sourceMappingURL=resolve.js.map