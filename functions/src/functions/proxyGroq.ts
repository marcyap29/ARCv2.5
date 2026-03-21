// functions/proxyGroq.ts - Groq API proxy for LUMARA (primary cloud inference path from Flutter groq_send.dart)

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { GROQ_API_KEY } from "../config";
import { enforceAuth, checkJournalEntryLimit, checkChatLimit } from "../authGuard";
import { checkUnifiedDailyLimit, checkRateLimit } from "../rateLimiter";
import { groqChatCompletion } from "../groqClient";

const ALLOWED_MODELS = new Set([
  "openai/gpt-oss-120b",
  "openai/gpt-oss-20b",
  "llama-3.3-70b-versatile",
]);

/**
 * Proxies chat completions to Groq; enforces the same unified daily limit as other LUMARA entry points.
 */
export const proxyGroq = onCall(
  {
    secrets: [GROQ_API_KEY],
  },
  async (request) => {
    if (request.data?._ping === true) {
      return { ok: true, ts: Date.now() };
    }

    const {
      system,
      user,
      model = "openai/gpt-oss-120b",
      temperature = 0.7,
      maxTokens,
      entryId,
      chatId,
      localCalendarDate,
    } = request.data ?? {};

    if (user == null || typeof user !== "string") {
      throw new HttpsError("invalid-argument", "user prompt is required");
    }

    if (!ALLOWED_MODELS.has(model)) {
      throw new HttpsError(
        "invalid-argument",
        `Unsupported model. Allowed: ${[...ALLOWED_MODELS].join(", ")}`
      );
    }

    const authResult = await enforceAuth(request);
    const { userId, isPremium } = authResult;
    const userEmail = request.auth?.token?.email as string | undefined;

    logger.info(`Proxying Groq request for user ${userId} (premium: ${isPremium})`);

    const dailyCheck = await checkUnifiedDailyLimit(userId, userEmail, localCalendarDate);
    if (!dailyCheck.allowed) {
      throw new HttpsError(
        "resource-exhausted",
        dailyCheck.error?.message || "Daily limit reached",
        dailyCheck.error
      );
    }

    const rateLimitCheck = await checkRateLimit(userId, userEmail);
    if (!rateLimitCheck.allowed) {
      throw new HttpsError(
        "resource-exhausted",
        rateLimitCheck.error?.message || "Rate limit exceeded",
        rateLimitCheck.error
      );
    }

    if (entryId && typeof entryId === "string") {
      await checkJournalEntryLimit(userId, entryId, isPremium);
    }
    if (chatId && typeof chatId === "string") {
      await checkChatLimit(userId, chatId, isPremium);
    }

    const apiKey = GROQ_API_KEY.value();
    if (!apiKey) {
      throw new HttpsError("internal", "Groq API key not configured");
    }

    try {
      const text = await groqChatCompletion(apiKey, {
        system: typeof system === "string" ? system : "",
        user,
        model,
        temperature: typeof temperature === "number" ? temperature : 0.7,
        maxTokens: typeof maxTokens === "number" ? maxTokens : undefined,
      });
      logger.info(`Groq proxy successful for user ${userId}`);
      return { response: text };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      logger.error("Groq proxy error:", msg);
      if (msg.includes("429")) {
        throw new HttpsError("resource-exhausted", "Groq rate limit. Try again later.");
      }
      throw new HttpsError(
        "internal",
        msg.length > 0 && msg.length < 200 ? msg : "AI service error. Try again."
      );
    }
  }
);
