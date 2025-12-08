// authGuard.ts - Authentication enforcement with anonymous trial support

import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { admin } from "./admin";
import { UserDocument } from "./types";

const db = admin.firestore();

/**
 * Anonymous trial configuration
 */
export const ANONYMOUS_TRIAL_LIMIT = 5; // Max requests before requiring sign-in

/**
 * Auth guard result
 */
export interface AuthGuardResult {
  userId: string;
  isAnonymous: boolean;
  trialRemaining?: number; // Only for anonymous users
  user: UserDocument;
}

/**
 * Custom error codes for auth-related issues
 */
export const AuthErrorCodes = {
  UNAUTHENTICATED: "UNAUTHENTICATED",
  ANONYMOUS_TRIAL_EXPIRED: "ANONYMOUS_TRIAL_EXPIRED",
} as const;

/**
 * Enforce authentication with anonymous trial support
 * 
 * This function:
 * 1. Requires Firebase Auth (rejects unauthenticated requests)
 * 2. Allows anonymous users a limited trial (5 requests)
 * 3. Returns user info and trial status
 * 
 * After trial expires, anonymous users must sign in with Google/Email
 * to continue using the app.
 * 
 * @throws HttpsError if unauthenticated or trial expired
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
  
  // Check if user is anonymous (Firebase Auth provides this in the token)
  // Anonymous users have no email and provider_id is "anonymous"
  const isAnonymous = !firebaseUser.email && 
    (firebaseUser.firebase?.sign_in_provider === "anonymous" || 
     firebaseUser.provider_id === "anonymous");

  logger.info(`Auth enforced for user ${userId} (anonymous: ${isAnonymous})`);

  // Step 2: Load or create user document
  const userRef = db.collection("users").doc(userId);
  const userDoc = await userRef.get();

  let user: UserDocument;

  if (!userDoc.exists) {
    // Create new user document
    logger.info(`Creating new user document for ${userId}`);
    user = {
      userId: userId,
      plan: "free",
      subscriptionTier: "FREE",
      isAnonymous: isAnonymous,
      anonymousRequestCount: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
      updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
    };
    await userRef.set(user);
  } else {
    user = userDoc.data() as UserDocument;
    
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

  // Step 3: For anonymous users, check and enforce trial limit
  if (isAnonymous) {
    const currentCount = user.anonymousRequestCount || 0;
    
    if (currentCount >= ANONYMOUS_TRIAL_LIMIT) {
      logger.warn(`Anonymous trial expired for user ${userId} (${currentCount}/${ANONYMOUS_TRIAL_LIMIT})`);
      throw new HttpsError(
        "permission-denied",
        `Your free trial of ${ANONYMOUS_TRIAL_LIMIT} requests has ended. Please sign in with Google or Email to continue using the app.`,
        { 
          code: AuthErrorCodes.ANONYMOUS_TRIAL_EXPIRED,
          trialLimit: ANONYMOUS_TRIAL_LIMIT,
          requestCount: currentCount,
        }
      );
    }

    // Increment anonymous request count
    await userRef.update({
      anonymousRequestCount: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const trialRemaining = ANONYMOUS_TRIAL_LIMIT - currentCount - 1;
    logger.info(`Anonymous user ${userId} trial: ${trialRemaining} requests remaining`);

    return {
      userId,
      isAnonymous: true,
      trialRemaining,
      user,
    };
  }

  // Real (non-anonymous) user - full access
  return {
    userId,
    isAnonymous: false,
    user,
  };
}

/**
 * Check if a user can link their anonymous account to a real account
 * 
 * This is called from the Flutter side when user decides to sign in
 * after using anonymous auth.
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
 * 
 * Called after Firebase Auth linkWithCredential succeeds on client.
 * Transfers subscription data and clears anonymous flags.
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
      anonymousRequestCount: 0, // Reset trial counter
      linkedFromAnonymous: oldAnonymousUid,
      linkedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Optionally: Delete or mark old anonymous user document
    batch.update(oldUserRef, {
      linkedToAccount: newRealUid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  logger.info(`Linked anonymous account ${oldAnonymousUid} to real account ${newRealUid}`);
}

