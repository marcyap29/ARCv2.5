// rateLimiter.ts - Rate limiting for FREE tier users

import { admin } from "./admin";
import { QuotaCheckResult, UserDocument, RateLimitDocument } from "./types";
import { FREE_MAX_REQUESTS_PER_MINUTE } from "./config";

const db = admin.firestore();

/** Unified daily request limit for free tier (all LUMARA modes: chat, reflection, voice, agents, etc.) */
export const FREE_TIER_DAILY_LUMARA_LIMIT = 20;

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

function addDaysIso(iso: string, deltaDays: number): string {
  const [y, m, d] = iso.split("-").map(Number);
  const t = Date.UTC(y, m - 1, d) + deltaDays * 86400000;
  const x = new Date(t);
  const yy = x.getUTCFullYear();
  const mm = String(x.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(x.getUTCDate()).padStart(2, "0");
  return `${yy}-${mm}-${dd}`;
}

/**
 * Bucket key for daily usage: prefer the client's local calendar date when it is
 * plausibly "today" somewhere on Earth (UTC date ± 1); otherwise UTC date.
 * Matches device local midnight when the app sends [localCalendarDate] from DateTime.now().
 */
export function resolveLumaraUsageDay(clientLocalCalendarDate?: string): string {
  const utcToday = new Date().toISOString().slice(0, 10);
  const plausible = new Set([
    addDaysIso(utcToday, -1),
    utcToday,
    addDaysIso(utcToday, 1),
  ]);
  if (
    typeof clientLocalCalendarDate === "string" &&
    ISO_DATE.test(clientLocalCalendarDate) &&
    plausible.has(clientLocalCalendarDate)
  ) {
    return clientLocalCalendarDate;
  }
  return utcToday;
}

function isPremiumUser(userData: Record<string, unknown>): boolean {
  const st = String(userData.subscriptionTier ?? "").toLowerCase();
  return (
    userData.plan === "pro" ||
    st === "paid" ||
    userData.throttleUnlocked === true ||
    (st === "premium" && userData.subscriptionStatus === "active")
  );
}

/** Emails that are always exempt from rate limiting */
const EXEMPT_EMAILS = [
  "marcyap@orbitalai.net",
  "marcyap@fastmail.com",
  "tester1@tester1.com",
];

/**
 * Check and enforce the unified daily LUMARA limit (20 requests/day for free tier).
 *
 * This single pool covers ALL free-tier LUMARA interactions:
 * chat, journal reflections, analyses, prompts, voice, agents, proxy paths, etc.
 * Uses the same `lumaraDailyUsage` Firestore field so all call paths share one counter.
 *
 * - Exempt emails: unlimited
 * - Premium: unlimited
 * - Free: max FREE_TIER_DAILY_LUMARA_LIMIT per calendar day (see resolveLumaraUsageDay)
 */
export async function checkUnifiedDailyLimit(
  userId: string,
  userEmail?: string,
  clientLocalCalendarDate?: string
): Promise<QuotaCheckResult> {
  try {
    // Exempt emails bypass all limits
    if (userEmail && EXEMPT_EMAILS.includes(userEmail.toLowerCase())) {
      return { allowed: true };
    }

    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();

    let userData: Record<string, any> = {};
    if (!userDoc.exists) {
      // Auto-create new user with free tier
      const newUser: UserDocument = {
        userId,
        plan: "free",
        subscriptionTier: "FREE",
        createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
        updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
      };
      await userRef.set(newUser);
    } else {
      userData = userDoc.data() as Record<string, any>;
    }

    if (isPremiumUser(userData)) {
      return { allowed: true };
    }

    // Check and increment daily usage (shared across proxies via lumaraDailyUsage)
    const today = resolveLumaraUsageDay(clientLocalCalendarDate);
    const usage = userData.lumaraDailyUsage || {};
    const currentCount = usage.date === today ? (usage.count || 0) : 0;

    if (currentCount >= FREE_TIER_DAILY_LUMARA_LIMIT) {
      return {
        allowed: false,
        error: {
          code: "DAILY_LIMIT_REACHED",
          message: `Daily limit of ${FREE_TIER_DAILY_LUMARA_LIMIT} LUMARA requests reached. Upgrade to premium for unlimited access.`,
          currentUsage: currentCount,
          limit: FREE_TIER_DAILY_LUMARA_LIMIT,
          upgradeRequired: true,
          tier: "FREE",
          retryAfter: 0,
        },
      };
    }

    await userRef.set(
      { lumaraDailyUsage: { date: today, count: currentCount + 1 } },
      { merge: true }
    );

    return { allowed: true };
  } catch (error) {
    console.error("Error checking unified daily limit:", error);
    // Fail open to avoid blocking users on infrastructure errors
    return { allowed: true };
  }
}

/**
 * Per-minute spam protection (applies to free users only).
 * Does NOT enforce the daily quota — use checkUnifiedDailyLimit for that.
 */
export async function checkRateLimit(
  userId: string,
  userEmail?: string
): Promise<QuotaCheckResult> {
  try {
    // Exempt emails bypass all limits
    if (userEmail && EXEMPT_EMAILS.includes(userEmail.toLowerCase())) {
      return { allowed: true };
    }

    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();

    let user: UserDocument;
    if (!userDoc.exists) {
      user = {
        userId,
        plan: "free",
        subscriptionTier: "FREE",
        createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
        updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
      };
      await userRef.set(user);
    } else {
      user = userDoc.data() as UserDocument;
    }

    if (isPremiumUser(user as unknown as Record<string, unknown>)) {
      return { allowed: true };
    }

    const now = admin.firestore.Timestamp.now();
    const rateLimitRef = db.collection("rateLimits").doc(`${userId}_global`);
    const rateLimitDoc = await rateLimitRef.get();

    let rateLimit: RateLimitDocument;

    if (!rateLimitDoc.exists) {
      rateLimit = {
        userId,
        requestsToday: 0,
        requestsLastMinute: 0,
        lastRequestTimestamp: now,
        lastMinuteWindowStart: now,
        lastDayWindowStart: now,
        updatedAt: now,
      };
      await rateLimitRef.set(rateLimit);
    } else {
      rateLimit = rateLimitDoc.data() as RateLimitDocument;
    }

    const oneMinuteAgo = new Date(now.toMillis() - 60 * 1000);
    if (rateLimit.lastMinuteWindowStart.toMillis() < oneMinuteAgo.getTime()) {
      rateLimit.requestsLastMinute = 0;
      rateLimit.lastMinuteWindowStart = now;
    }

    const maxPerMinute = parseInt(FREE_MAX_REQUESTS_PER_MINUTE.value(), 10);

    if (rateLimit.requestsLastMinute >= maxPerMinute) {
      const nextReset = new Date(rateLimit.lastMinuteWindowStart.toMillis() + 60 * 1000);
      const retryAfter = Math.ceil((nextReset.getTime() - Date.now()) / 1000);

      return {
        allowed: false,
        error: {
          code: "RATE_LIMIT_MINUTE_EXCEEDED",
          message: `Too many requests: please wait ${retryAfter} seconds before trying again.`,
          currentUsage: rateLimit.requestsLastMinute,
          limit: maxPerMinute,
          upgradeRequired: false,
          tier: "FREE",
          retryAfter: retryAfter > 0 ? retryAfter : 0,
        },
      };
    }

    rateLimit.requestsLastMinute += 1;
    rateLimit.lastRequestTimestamp = now;
    rateLimit.updatedAt = now;
    await rateLimitRef.set(rateLimit, { merge: true });

    return { allowed: true };
  } catch (error) {
    console.error("Error checking rate limit:", error);
    return { allowed: true };
  }
}
