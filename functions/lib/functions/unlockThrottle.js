"use strict";
// functions/unlockThrottle.ts - Throttle unlock with password verification
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkThrottleStatus = exports.lockThrottle = exports.unlockThrottle = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const admin_1 = require("../admin");
const config_1 = require("../config");
const crypto = __importStar(require("crypto"));
const db = admin_1.admin.firestore();
/**
 * Unlock throttle with password verification
 *
 * This is a developer/admin feature that allows bypassing rate limits
 * with a password-protected unlock.
 *
 * Request: { password: string }
 * Response: { success: boolean, message: string }
 */
exports.unlockThrottle = (0, https_1.onCall)({
    secrets: [config_1.THROTTLE_UNLOCK_PASSWORD],
}, async (request) => {
    const { password } = request.data;
    // Validate request
    if (!password || typeof password !== "string") {
        throw new https_1.HttpsError("invalid-argument", "Password is required");
    }
    const userId = request.auth?.uid;
    if (!userId) {
        throw new https_1.HttpsError("unauthenticated", "User must be authenticated");
    }
    firebase_functions_1.logger.info(`Throttle unlock attempt for user ${userId}`);
    try {
        // Get the correct password from secrets
        const correctPassword = config_1.THROTTLE_UNLOCK_PASSWORD.value();
        // Compare passwords securely (constant-time comparison)
        // Use timing-safe comparison to prevent timing attacks
        const providedBuffer = Buffer.from(password, 'utf8');
        const correctBuffer = Buffer.from(correctPassword, 'utf8');
        // Ensure buffers are same length to prevent timing attacks
        if (providedBuffer.length !== correctBuffer.length) {
            firebase_functions_1.logger.warn(`Invalid throttle unlock password attempt for user ${userId}`);
            throw new https_1.HttpsError("permission-denied", "Invalid password");
        }
        // Constant-time comparison to prevent timing attacks
        if (!crypto.timingSafeEqual(providedBuffer, correctBuffer)) {
            firebase_functions_1.logger.warn(`Invalid throttle unlock password attempt for user ${userId}`);
            throw new https_1.HttpsError("permission-denied", "Invalid password");
        }
        // Password is correct - unlock throttle for this user
        await db.collection("users").doc(userId).update({
            throttleUnlocked: true,
            throttleUnlockedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
        });
        firebase_functions_1.logger.info(`Throttle unlocked for user ${userId}`);
        return {
            success: true,
            message: "Throttle unlocked successfully",
        };
    }
    catch (error) {
        firebase_functions_1.logger.error("Error unlocking throttle:", error);
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        throw new https_1.HttpsError("internal", "Failed to unlock throttle", error);
    }
});
/**
 * Lock throttle (remove unlock)
 *
 * Request: (no parameters)
 * Response: { success: boolean, message: string }
 */
exports.lockThrottle = (0, https_1.onCall)(async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
        throw new https_1.HttpsError("unauthenticated", "User must be authenticated");
    }
    firebase_functions_1.logger.info(`Throttle lock request for user ${userId}`);
    try {
        // Remove throttle unlock
        await db.collection("users").doc(userId).update({
            throttleUnlocked: admin_1.admin.firestore.FieldValue.delete(),
            throttleUnlockedAt: admin_1.admin.firestore.FieldValue.delete(),
            updatedAt: admin_1.admin.firestore.FieldValue.serverTimestamp(),
        });
        firebase_functions_1.logger.info(`Throttle locked for user ${userId}`);
        return {
            success: true,
            message: "Throttle locked successfully",
        };
    }
    catch (error) {
        firebase_functions_1.logger.error("Error locking throttle:", error);
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        throw new https_1.HttpsError("internal", "Failed to lock throttle", error);
    }
});
/**
 * Check throttle unlock status
 *
 * Request: (no parameters)
 * Response: { unlocked: boolean }
 */
exports.checkThrottleStatus = (0, https_1.onCall)(async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
        throw new https_1.HttpsError("unauthenticated", "User must be authenticated");
    }
    try {
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) {
            return { unlocked: false };
        }
        const user = userDoc.data();
        return {
            unlocked: user?.throttleUnlocked === true,
        };
    }
    catch (error) {
        firebase_functions_1.logger.error("Error checking throttle status:", error);
        return { unlocked: false };
    }
});
//# sourceMappingURL=unlockThrottle.js.map