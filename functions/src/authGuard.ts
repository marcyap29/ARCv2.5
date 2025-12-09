// authGuard.ts - Authentication and usage limits for free users

import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { admin } from "./admin";
import { UserDocument } from "./types";

const db = admin.firestore();

/**
 * Admin emails with full privileges (unlimited access, bypasses all limits)
 */
export const ADMIN_EMAILS = [
  "marcyap@orbitalai.net",
];

/**
 * Check if an email has admin privileges
 */
export function isAdminEmail(email: string | undefined): boolean {
  if (!email) return false;
  return ADMIN_EMAILS.includes(email.toLowerCase());
}

/**
 * Usage limits for free tier (applies to ALL free users, anonymous or not)
 */
export const FREE_TIER_LIMITS = {
  JOURNAL_COMMENTS_PER_ENTRY: 5,  // Max in-journal LUMARA comments per entry
  CHAT_MESSAGES_PER_CHAT: 20,     // Max in-chat LUMARA messages per chat
};

/**
 * Request context types
 */
export type RequestContext = "journal" | "chat";

/**
 * Auth guard result
 */
export interface AuthGuardResult {
  userId: string;
  isAnonymous: boolean;
  isPremium: boolean;
  user: UserDocument;
}

/**
 * Custom error codes for auth-related issues
 */
export const AuthErrorCodes = {
  UNAUTHENTICATED: "UNAUTHENTICATED",
  JOURNAL_LIMIT_REACHED: "JOURNAL_LIMIT_REACHED",
  CHAT_LIMIT_REACHED: "CHAT_LIMIT_REACHED",
} as const;

/**
 * Enforce authentication (no usage limit checking)
 * 
 * This function:
 * 1. Requires Firebase Auth (rejects unauthenticated requests)
 * 2. Returns user info and subscription status
 * 
 * @throws HttpsError if unauthenticated
 */
export async function enforceAuth(
  request: CallableRequest
): Promise<AuthGuardResult> {
  // Step 1: Require authentication (no more public access)
  if (!request.auth) {
    logger.warn("Unauthenticated request rejected");
    throw new HttpsError(
      "unauthenticated",
      "Authentication required. Please sign in to continue.",
      { code: AuthErrorCodes.UNAUTHENTICATED }
    );
  }

  const userId = request.auth.uid;
  const firebaseUser = request.auth.token;
  const userEmail = firebaseUser.email;
  
  // Check if user is anonymous
  const signInProvider = firebaseUser.firebase?.sign_in_provider;
  const isAnonymous = signInProvider === "anonymous";

  // Check if user is an admin
  const isAdmin = isAdminEmail(userEmail);
  if (isAdmin) {
    logger.info(`🔑 Admin user detected: ${userEmail}`);
  }

  logger.info(`Auth enforced for user ${userId} (anonymous: ${isAnonymous}, provider: ${signInProvider}, email: ${userEmail || 'none'})`);

  // Step 2: Load or create user document
  const userRef = db.collection("users").doc(userId);
  const userDoc = await userRef.get();

  let user: UserDocument;

  if (!userDoc.exists) {
    // Create new user document
    // Admin users automatically get "pro" plan
    const plan = isAdmin ? "pro" : "free";
    const subscriptionTier = isAdmin ? "PAID" : "FREE";
    
    logger.info(`Creating new user document for ${userId} (plan: ${plan})`);
    user = {
      userId: userId,
      plan: plan,
      subscriptionTier: subscriptionTier,
      isAnonymous: isAnonymous,
      createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
      updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
    };
    await userRef.set(user);
  } else {
    user = userDoc.data() as UserDocument;
    
    // Auto-upgrade admin users to pro if they aren't already
    if (isAdmin && user.plan !== "pro") {
      logger.info(`🔑 Auto-upgrading admin user ${userEmail} to pro`);
      await userRef.update({
        plan: "pro",
        subscriptionTier: "PAID",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      user.plan = "pro";
      user.subscriptionTier = "PAID";
    }
    
    // Update isAnonymous flag if user upgraded from anonymous to real account
    if (user.isAnonymous && !isAnonymous) {
      logger.info(`User ${userId} upgraded from anonymous to real account`);
      await userRef.update({
        isAnonymous: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      user.isAnonymous = false;
    }
  }

  // Check if user is premium (admin users are always premium)
  const isPremium = isAdmin || user.plan === "pro" || user.subscriptionTier === "PAID";

  return {
    userId,
    isAnonymous,
    isPremium,
    user,
  };
}

/**
 * Check and enforce per-entry limit for in-journal LUMARA comments
 * 
 * @param userId - The user's ID
 * @param entryId - The journal entry ID
 * @param isPremium - Whether user has premium subscription
 * @throws HttpsError if limit reached
 */
export async function checkJournalEntryLimit(
  userId: string,
  entryId: string,
  isPremium: boolean
): Promise<{ remaining: number }> {
  // Premium users have unlimited access
  if (isPremium) {
    logger.info(`Premium user ${userId} - no journal entry limit`);
    return { remaining: -1 }; // -1 indicates unlimited
  }

  // Get or create entry usage document
  const usageRef = db.collection("usageLimits").doc(`${userId}_entry_${entryId}`);
  const usageDoc = await usageRef.get();

  let currentCount = 0;

  if (usageDoc.exists) {
    currentCount = usageDoc.data()?.count || 0;
  }

  const limit = FREE_TIER_LIMITS.JOURNAL_COMMENTS_PER_ENTRY;

  if (currentCount >= limit) {
    logger.warn(`Journal entry limit reached for user ${userId}, entry ${entryId} (${currentCount}/${limit})`);
    throw new HttpsError(
      "resource-exhausted",
      `The free version of Arc is limited to ${limit} LUMARA in-journal comments per entry.`,
      { 
        code: AuthErrorCodes.JOURNAL_LIMIT_REACHED,
        limit: limit,
        currentCount: currentCount,
        entryId: entryId,
      }
    );
  }

  // Increment usage counter
  await usageRef.set({
    userId,
    entryId,
    count: admin.firestore.FieldValue.increment(1),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  const remaining = limit - currentCount - 1;
  logger.info(`Journal entry usage for user ${userId}, entry ${entryId}: ${currentCount + 1}/${limit} (${remaining} remaining)`);

  return { remaining };
}

/**
 * Check and enforce per-chat limit for in-chat LUMARA messages
 * 
 * @param userId - The user's ID
 * @param chatId - The chat/thread ID
 * @param isPremium - Whether user has premium subscription
 * @throws HttpsError if limit reached
 */
export async function checkChatLimit(
  userId: string,
  chatId: string,
  isPremium: boolean
): Promise<{ remaining: number }> {
  // Premium users have unlimited access
  if (isPremium) {
    logger.info(`Premium user ${userId} - no chat limit`);
    return { remaining: -1 }; // -1 indicates unlimited
  }

  // Get or create chat usage document
  const usageRef = db.collection("usageLimits").doc(`${userId}_chat_${chatId}`);
  const usageDoc = await usageRef.get();

  let currentCount = 0;

  if (usageDoc.exists) {
    currentCount = usageDoc.data()?.count || 0;
  }

  const limit = FREE_TIER_LIMITS.CHAT_MESSAGES_PER_CHAT;

  if (currentCount >= limit) {
    logger.warn(`Chat limit reached for user ${userId}, chat ${chatId} (${currentCount}/${limit})`);
    throw new HttpsError(
      "resource-exhausted",
      `The free version of Arc is limited to ${limit} LUMARA messages per chat.`,
      { 
        code: AuthErrorCodes.CHAT_LIMIT_REACHED,
        limit: limit,
        currentCount: currentCount,
        chatId: chatId,
      }
    );
  }

  // Increment usage counter
  await usageRef.set({
    userId,
    chatId,
    count: admin.firestore.FieldValue.increment(1),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  const remaining = limit - currentCount - 1;
  logger.info(`Chat usage for user ${userId}, chat ${chatId}: ${currentCount + 1}/${limit} (${remaining} remaining)`);

  return { remaining };
}

/**
 * Check if a user can link their anonymous account to a real account
 */
export async function canLinkAccount(userId: string): Promise<boolean> {
  const userDoc = await db.collection("users").doc(userId).get();
  
  if (!userDoc.exists) {
    return false;
  }

  const user = userDoc.data() as UserDocument;
  return user.isAnonymous === true;
}

/**
 * Link anonymous user data to a new real account
 */
export async function linkAccountData(
  oldAnonymousUid: string,
  newRealUid: string
): Promise<void> {
  const batch = db.batch();

  // Get old user document
  const oldUserRef = db.collection("users").doc(oldAnonymousUid);
  const oldUserDoc = await oldUserRef.get();

  if (oldUserDoc.exists) {
    const oldUser = oldUserDoc.data() as UserDocument;

    // Create/update new user document with transferred data
    const newUserRef = db.collection("users").doc(newRealUid);
    batch.set(newUserRef, {
      ...oldUser,
      userId: newRealUid,
      isAnonymous: false,
      linkedFromAnonymous: oldAnonymousUid,
      linkedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Mark old anonymous user document as linked
    batch.update(oldUserRef, {
      linkedToAccount: newRealUid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  logger.info(`Linked anonymous account ${oldAnonymousUid} to real account ${newRealUid}`);
}
