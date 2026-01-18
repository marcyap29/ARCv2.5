"use strict";
/**
 * Graduated Crisis Intervention System
 *
 * Escalating response based on crisis frequency
 * NEVER fully deactivates accounts - journaling is protective, not harmful
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.determineInterventionLevel = determineInterventionLevel;
exports.isInLimitedMode = isInLimitedMode;
exports.activateLimitedMode = activateLimitedMode;
const admin_1 = require("../admin");
const firebase_functions_1 = require("firebase-functions");
const db = admin_1.admin.firestore();
async function determineInterventionLevel(userId, currentCrisis) {
    // No crisis detected
    if (!currentCrisis.crisis_detected) {
        return {
            level: 0,
            action: 'none',
            allow_ai_reflection: true,
            message: null
        };
    }
    // Count CRITICAL/HIGH crises in last 24 hours (including current)
    const criticalCrisesLast24hrs = await getCriticalCrisesInWindow(userId, 24);
    const crisisCount = criticalCrisesLast24hrs.length;
    // LEVEL 1: First crisis in 24hrs
    if (crisisCount === 1) {
        return {
            level: 1,
            action: 'alert_and_resources',
            allow_ai_reflection: true,
            message: null // Use standard crisis template
        };
    }
    // LEVEL 2: Second crisis in 24hrs
    if (crisisCount === 2) {
        return {
            level: 2,
            action: 'require_acknowledgment',
            allow_ai_reflection: true,
            requires_acknowledgment: true,
            message: `I notice this is your second crisis entry in the past 24 hours. Before continuing, please acknowledge the support resources available to you.

These resources are here specifically for moments like this:
• National Suicide Prevention Lifeline: 988 (call or text, 24/7)
• Crisis Text Line: Text HOME to 741741
• Emergency Services: 911

Please confirm you've seen these resources before continuing.`
        };
    }
    // LEVEL 3: Third or more crises in 24hrs
    // Pause AI reflections but ALLOW journaling
    return {
        level: 3,
        action: 'limited_mode',
        allow_ai_reflection: false,
        limited_mode_duration_hours: 24,
        message: `I've noticed you're in severe distress - this is your ${ordinalSuffix(crisisCount)} crisis entry in the past 24 hours.

I care deeply about your wellbeing, but I'm not equipped to provide the immediate support you need right now. Please reach out to professional crisis support:

• National Suicide Prevention Lifeline: 988 (24/7)
  - Call or text anytime, day or night
  - Trained counselors who understand crisis
  
• Crisis Text Line: Text HOME to 741741
  - Text-based support if calling feels hard
  - Immediate response from crisis counselors

• Emergency Services: 911
  - For immediate danger

**You can continue journaling here** - writing can be helpful for processing your thoughts. However, AI reflections are paused for 24 hours to encourage you to connect with trained crisis counselors who can provide real-time support.

I'll be here when you're ready. Please reach out for help right now.`
    };
}
// Helper function to get crisis count in time window
async function getCriticalCrisesInWindow(userId, hours) {
    const windowStart = new Date(Date.now() - hours * 60 * 60 * 1000);
    try {
        const entries = await db
            .collection('users')
            .doc(userId)
            .collection('journal_entries')
            .where('timestamp', '>=', admin_1.admin.firestore.Timestamp.fromDate(windowStart))
            .orderBy('timestamp', 'desc')
            .get();
        const crises = [];
        for (const doc of entries.docs) {
            const data = doc.data();
            const sentinelResult = data.sentinel_result;
            if (sentinelResult &&
                (sentinelResult.crisis_level === 'CRITICAL' ||
                    sentinelResult.crisis_level === 'HIGH') &&
                sentinelResult.crisis_detected) {
                crises.push({
                    crisis_detected: true,
                    crisis_score: sentinelResult.crisis_score || 0,
                    crisis_level: sentinelResult.crisis_level || 'HIGH',
                    detected_patterns: sentinelResult.detected_patterns || [],
                    intensity_factors: sentinelResult.intensity_factors || [],
                    confidence: sentinelResult.confidence || 0,
                    timestamp: sentinelResult.timestamp?.toDate() || new Date()
                });
            }
        }
        return crises;
    }
    catch (error) {
        firebase_functions_1.logger.error('Error fetching crisis history', { userId, hours, error });
        return [];
    }
}
// Helper for ordinal numbers
function ordinalSuffix(num) {
    const j = num % 10;
    const k = num % 100;
    if (j === 1 && k !== 11)
        return num + 'st';
    if (j === 2 && k !== 12)
        return num + 'nd';
    if (j === 3 && k !== 13)
        return num + 'rd';
    return num + 'th';
}
// Check if user is currently in limited mode
async function isInLimitedMode(userId) {
    try {
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            return false;
        }
        const limitedModeData = userDoc.data()?.limited_mode;
        if (!limitedModeData || !limitedModeData.active) {
            return false;
        }
        // Check if limited mode has expired
        const expiresAt = limitedModeData.expires_at?.toDate();
        const now = new Date();
        if (!expiresAt || now > expiresAt) {
            // Expired - clear it
            await db.collection('users').doc(userId).update({
                'limited_mode.active': false
            });
            return false;
        }
        return true;
    }
    catch (error) {
        firebase_functions_1.logger.error('Error checking limited mode', { userId, error });
        return false;
    }
}
// Activate limited mode
async function activateLimitedMode(userId, durationHours) {
    const expiresAt = new Date(Date.now() + durationHours * 60 * 60 * 1000);
    try {
        await db.collection('users').doc(userId).update({
            'limited_mode': {
                active: true,
                activated_at: admin_1.admin.firestore.FieldValue.serverTimestamp(),
                expires_at: admin_1.admin.firestore.Timestamp.fromDate(expiresAt),
                reason: 'repeated_crisis_detection',
                duration_hours: durationHours
            }
        });
        firebase_functions_1.logger.info('Limited mode activated', {
            userId,
            duration_hours: durationHours,
            expires_at: expiresAt
        });
    }
    catch (error) {
        firebase_functions_1.logger.error('Error activating limited mode', { userId, durationHours, error });
        throw error;
    }
}
//# sourceMappingURL=crisisIntervention.js.map