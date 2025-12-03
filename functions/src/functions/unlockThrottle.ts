// functions/unlockThrottle.ts - Throttle unlock with password verification

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { admin } from "../admin";
import { THROTTLE_UNLOCK_PASSWORD } from "../config";
import * as crypto from "crypto";

const db = admin.firestore();

/**
 * Unlock throttle with password verification
 * 
 * This is a developer/admin feature that allows bypassing rate limits
 * with a password-protected unlock.
 * 
 * Request: { password: string }
 * Response: { success: boolean, message: string }
 */
export const unlockThrottle = onCall(
  {
    secrets: [THROTTLE_UNLOCK_PASSWORD],
  },
  async (request) => {
    const { password } = request.data;

    // Validate request
    if (!password || typeof password !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Password is required"
      );
    }

    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    logger.info(`Throttle unlock attempt for user ${userId}`);

    try {
      // Get the correct password from secrets
      const correctPassword = THROTTLE_UNLOCK_PASSWORD.value();

      // Compare passwords securely (constant-time comparison)
      // Use timing-safe comparison to prevent timing attacks
      const providedBuffer = Buffer.from(password, 'utf8');
      const correctBuffer = Buffer.from(correctPassword, 'utf8');
      
      // Ensure buffers are same length to prevent timing attacks
      if (providedBuffer.length !== correctBuffer.length) {
        logger.warn(`Invalid throttle unlock password attempt for user ${userId}`);
        throw new HttpsError(
          "permission-denied",
          "Invalid password"
        );
      }

      // Constant-time comparison to prevent timing attacks
      if (!crypto.timingSafeEqual(providedBuffer, correctBuffer)) {
        logger.warn(`Invalid throttle unlock password attempt for user ${userId}`);
        throw new HttpsError(
          "permission-denied",
          "Invalid password"
        );
      }

      // Password is correct - unlock throttle for this user
      await db.collection("users").doc(userId).update({
        throttleUnlocked: true,
        throttleUnlockedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info(`Throttle unlocked for user ${userId}`);

      return {
        success: true,
        message: "Throttle unlocked successfully",
      };
    } catch (error) {
      logger.error("Error unlocking throttle:", error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        "internal",
        "Failed to unlock throttle",
        error
      );
    }
  }
);

/**
 * Lock throttle (remove unlock)
 * 
 * Request: (no parameters)
 * Response: { success: boolean, message: string }
 */
export const lockThrottle = onCall(
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    logger.info(`Throttle lock request for user ${userId}`);

    try {
      // Remove throttle unlock
      await db.collection("users").doc(userId).update({
        throttleUnlocked: admin.firestore.FieldValue.delete(),
        throttleUnlockedAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info(`Throttle locked for user ${userId}`);

      return {
        success: true,
        message: "Throttle locked successfully",
      };
    } catch (error) {
      logger.error("Error locking throttle:", error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        "internal",
        "Failed to lock throttle",
        error
      );
    }
  }
);

/**
 * Check throttle unlock status
 * 
 * Request: (no parameters)
 * Response: { unlocked: boolean }
 */
export const checkThrottleStatus = onCall(
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
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
    } catch (error) {
      logger.error("Error checking throttle status:", error);
      return { unlocked: false };
    }
  }
);
