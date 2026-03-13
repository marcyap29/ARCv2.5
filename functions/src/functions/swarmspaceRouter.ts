// functions/src/functions/swarmspaceRouter.ts
//
// SwarmSpace API Router — Firebase Cloud Function
//
// This is the "front door" to SwarmSpace. LUMARA calls this function,
// which checks who the user is, what plan they're on, then forwards
// the request to the right Cloudflare plugin worker.
//
// Flow:
//   LUMARA app
//     → Firebase Auth token (proves user identity)
//     → This function (swarmspaceRouter)
//         → Validate token (Firebase does this automatically)
//         → Load user from Firestore, check their plan
//         → Look up which worker URL handles the requested plugin
//         → Forward request to that worker, stamping it with:
//             - X-SwarmSpace-User-Id   (user's Firebase UID)
//             - X-SwarmSpace-User-Tier (free / standard / premium)
//             - Authorization: Bearer <SWARMSPACE_INTERNAL_TOKEN>
//         → Return the worker's response to LUMARA

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { getFirestore } from "firebase-admin/firestore";
import { enforceAuth } from "../authGuard";
import { loadUserLlmSettings } from "../userLlmSettings";
import { LLM_SETTINGS_ENCRYPTION_KEY } from "../config";

const PLUGIN_ACTIVITY_COLLECTION = "plugin_activity_log";

// ── Secrets ────────────────────────────────────────────────────────────────────
// Set these once via Firebase CLI:
//   firebase functions:secrets:set SWARMSPACE_INTERNAL_TOKEN
//
// This is the shared secret between the router and the Cloudflare workers.
// Workers reject any request that doesn't have it — this prevents people
// from calling your workers directly and bypassing the auth/quota system.
const SWARMSPACE_INTERNAL_TOKEN = defineSecret("SWARMSPACE_INTERNAL_TOKEN");

// ── Plugin registry ────────────────────────────────────────────────────────────
// Maps plugin_id → { workerUrl, requiredTier, capabilities, description, exampleQuery }
// Add new plugins here as you deploy them.
//
// 'free'     = available to all signed-in users
// 'standard' = requires paid plan ($30/mo)
// 'premium'  = requires premium plan (future)
//
// capabilities: used by orchestrator to route "what can I answer with this plugin?"

type Tier = "free" | "standard" | "premium";

interface PluginConfig {
  workerUrl: string;
  requiredTier: Tier;
  capabilities: string[];
  description: string;
  exampleQuery: string;
  /** Optional: for future cost-aware routing */
  costTier?: Tier;
  /** PRISM: when true, intercept expects consent or sensitive-payload handling */
  privacy_data_required?: boolean;
}

const PLUGIN_REGISTRY: Record<string, PluginConfig> = {
  // ── Free tier ──────────────────────────────────────────────────────────────
  // IMPORTANT: The gemini-flash worker must use model gemini-3-flash-preview so it
  // matches proxyGemini and visionOcrInvoke. See DOCS/SWARMSPACE_GEMINI_MODEL_ALIGNMENT.md.
  "gemini-flash": {
    workerUrl: "https://swarmspace-plugin-gemini-flash.orbitalai.workers.dev",
    requiredTier: "free",
    capabilities: ["llm", "synthesis", "writing"],
    description: "Fast AI synthesis for writing and drafting",
    exampleQuery: "Draft a LinkedIn post about my latest project",
  },
  "brave-search": {
    workerUrl: "https://swarmspace-plugin-brave-search.orbitalai.workers.dev",
    requiredTier: "free",
    capabilities: ["web_search", "general"],
    description: "Privacy-focused web search",
    exampleQuery: "What are the latest developments in AI?",
  },
  "semantic-scholar": {
    workerUrl: "https://swarmspace-plugin-semantic-scholar.orbitalai.workers.dev",
    requiredTier: "free",
    capabilities: ["academic_search", "research", "papers"],
    description: "Academic paper and citation search",
    exampleQuery: "Find papers on transformer architectures",
  },
  "weather": {
    workerUrl: "https://swarmspace-plugin-weather.orbitalai.workers.dev",
    requiredTier: "free",
    capabilities: ["weather", "real_time"],
    description: "Current weather and forecasts",
    exampleQuery: "What's the weather in San Francisco?",
  },
  "wikipedia": {
    workerUrl: "https://swarmspace-plugin-wikipedia.orbitalai.workers.dev",
    requiredTier: "free",
    capabilities: ["knowledge", "encyclopedia", "general"],
    description: "Wikipedia knowledge base",
    exampleQuery: "Who invented the transistor?",
  },
  "currency": {
    workerUrl: "https://swarmspace-plugin-currency.orbitalai.workers.dev",
    requiredTier: "free",
    capabilities: ["currency", "exchange_rates", "real_time"],
    description: "Currency exchange rates",
    exampleQuery: "What is EUR to USD right now?",
  },
  "news": {
    workerUrl: "https://us-central1-arc-epi.cloudfunctions.net/newsDataInvoke",
    requiredTier: "free",
    capabilities: ["news", "real_time", "headlines"],
    description: "Latest news and headlines (NewsData.io)",
    exampleQuery: "Top tech news today",
  },
  // ── Standard tier ($30/mo) ─────────────────────────────────────────────────
  "vision-ocr": {
    workerUrl: "https://us-central1-arc-epi.cloudfunctions.net/visionOcrInvoke",
    requiredTier: "standard",
    capabilities: ["vision", "ocr", "image_understanding"],
    description: "Extract text (OCR) or understand images with Vision API + Gemini",
    exampleQuery: "Extract text from this screenshot / Describe this image",
    privacy_data_required: true,
  },
  "url-reader": {
    workerUrl: "https://swarmspace-plugin-url-reader.orbitalai.workers.dev",
    requiredTier: "standard",
    capabilities: ["url_fetch", "content_extraction", "reading"],
    description: "Fetch and extract content from URLs",
    exampleQuery: "Read and summarize this article: https://...",
    privacy_data_required: true,
  },
  "media-upload": {
    workerUrl: "https://swarmspace-media-upload.orbitalai.workers.dev",
    requiredTier: "standard",
    capabilities: ["media_host", "image_upload"],
    description: "Upload image and get a public URL (24h TTL)",
    exampleQuery: "Upload image for sharing",
    privacy_data_required: true,
  },
  "tavily-search": {
    workerUrl: "https://swarmspace-plugin-tavily-search.orbitalai.workers.dev",
    requiredTier: "standard",
    capabilities: ["web_search", "ai_optimized", "research"],
    description: "AI-optimized search for research",
    exampleQuery: "Deep research on quantum computing applications",
  },
  // ── Premium tier ──────────────────────────────────────────────────────────
  "exa-search": {
    workerUrl: "https://swarmspace-plugin-exa-search.orbitalai.workers.dev",
    requiredTier: "premium",
    capabilities: ["neural_search", "semantic", "research"],
    description: "Neural semantic search",
    exampleQuery: "Find content similar to this concept",
  },
  "perplexity-sonar": {
    workerUrl: "https://swarmspace-plugin-perplexity-sonar.orbitalai.workers.dev",
    requiredTier: "premium",
    capabilities: ["web_search", "answer_synthesis", "research"],
    description: "Real-time answer synthesis from the web",
    exampleQuery: "Explain the current state of fusion energy",
  },
};

// ── Tier resolution ────────────────────────────────────────────────────────────
// Maps your existing plan names to SwarmSpace tier names.
// Your Firestore users have plan: "free" | "pro"
// SwarmSpace workers understand: "free" | "standard" | "premium"
function resolveSwarmSpaceTier(plan: string, isPremium: boolean): Tier {
  if (!isPremium) return "free";
  // Right now "pro" maps to "standard". When you add a higher tier, map it to "premium".
  return "standard";
}

// ── Tier access check ──────────────────────────────────────────────────────────
// Returns true if the user's tier meets the plugin's requirement.
const TIER_RANK: Record<Tier, number> = { free: 0, standard: 1, premium: 2 };

function canAccessPlugin(userTier: Tier, requiredTier: Tier): boolean {
  return TIER_RANK[userTier] >= TIER_RANK[requiredTier];
}

// ── Activity log (PRISM Phase 1) ───────────────────────────────────────────────
// Fire-and-forget write to Firestore so every plugin call is recorded for Activity tab.
function writePluginActivityLog(entry: {
  user_id: string;
  plugin_id: string;
  plugin_name: string;
  user_tier: string;
  privacy_required: boolean;
  consent_given: boolean;
  data_fields_sent: string[];
  result: "success" | "error";
  error_message?: string;
}): void {
  const db = getFirestore();
  db.collection(PLUGIN_ACTIVITY_COLLECTION)
    .add({
      ...entry,
      called_at: new Date(),
    })
    .catch((err) => logger.warn("plugin_activity_log write failed", err));
}

// ── The router function ────────────────────────────────────────────────────────
/** Plugin IDs that accept per-user API key override (LLM plugins) */
const LLM_PLUGINS = new Set(["gemini-flash"]);

export const swarmspaceRouter = onCall(
  {
    secrets: [SWARMSPACE_INTERNAL_TOKEN, LLM_SETTINGS_ENCRYPTION_KEY],
  },
  async (request) => {
    // Step 1: Verify the user is logged in (Firebase handles token validation automatically).
    // This is exactly the same pattern as your existing proxyGemini function.
    const { userId, isPremium, user } = await enforceAuth(request);

    // Step 2: Parse the request — LUMARA sends { plugin_id, params }
    const { plugin_id, params } = request.data ?? {};

    if (!plugin_id || typeof plugin_id !== "string") {
      throw new HttpsError("invalid-argument", "plugin_id is required");
    }

    // Step 3: Look up the plugin in the registry.
    // If it's not registered, we reject it — no unknown plugins allowed.
    const plugin = PLUGIN_REGISTRY[plugin_id];
    if (!plugin) {
      throw new HttpsError("not-found", `Unknown plugin: ${plugin_id}`);
    }

    // Step 4: Check if the user's plan allows this plugin.
    // e.g. a free user asking for "tavily-search" (standard) gets a clean error.
    const userTier = resolveSwarmSpaceTier(user.plan ?? "free", isPremium);
    if (!canAccessPlugin(userTier, plugin.requiredTier)) {
      throw new HttpsError(
        "permission-denied",
        `Plugin "${plugin_id}" requires the ${plugin.requiredTier} plan. ` +
          `You are on the ${userTier} plan.`,
        {
          plugin_id,
          required_tier: plugin.requiredTier,
          user_tier: userTier,
          upgrade_url: "https://swarmspace.ai/upgrade",
        }
      );
    }

    logger.info(
      `SwarmSpace router: user=${userId} tier=${userTier} plugin=${plugin_id}`
    );

    // Step 4b: For LLM plugins, pass user's API key if they have custom config
    let paramsToSend = params ?? {};
    if (LLM_PLUGINS.has(plugin_id)) {
      const encKey = LLM_SETTINGS_ENCRYPTION_KEY.value();
      if (encKey) {
        const userLlm = await loadUserLlmSettings(userId, encKey);
        if (userLlm && (userLlm.provider === "gemini" || userLlm.provider === "swarmspace")) {
          paramsToSend = { ...paramsToSend, _apiKeyOverride: userLlm.apiKey };
        }
      }
    }

    // Step 4c: PRISM middleware — intercept before worker
    const privacyRequired = plugin.privacy_data_required === true;
    const hasSensitivePayload =
      typeof paramsToSend === "object" &&
      (paramsToSend.image_b64 != null || paramsToSend.image_url != null || paramsToSend.url != null);
    const consentGiven = paramsToSend._prism_consent === true || paramsToSend._prism_consent === "true";
    const paramsForWorker = { ...paramsToSend };
    delete (paramsForWorker as Record<string, unknown>)._prism_consent;
    const dataFieldsSent = typeof paramsForWorker === "object" && paramsForWorker !== null
      ? Object.keys(paramsForWorker).filter((k) =>
          ["image_b64", "image_url", "url", "image_base64"].includes(k)
        )
      : [];
    if (privacyRequired && hasSensitivePayload && !consentGiven) {
      logger.info("prism_transaction", {
        phase: "pre_invoke",
        plugin_id,
        user_id: userId,
        user_tier: userTier,
        privacy_data_required: true,
        has_sensitive_payload: true,
        consent_given: false,
        ts: new Date().toISOString(),
      });
      // Allow through for now; client can send _prism_consent: true when user approved.
      // Future: throw HttpsError("permission-denied", "Privacy consent required for this plugin") to block.
    } else {
      logger.info("prism_transaction", {
        phase: "pre_invoke",
        plugin_id,
        user_id: userId,
        user_tier: userTier,
        privacy_data_required: privacyRequired,
        has_sensitive_payload: hasSensitivePayload,
        consent_given: consentGiven,
        ts: new Date().toISOString(),
      });
    }

    // Step 5: Forward the request to the Cloudflare worker.
    // We stamp it with three headers the worker requires:
    //   - Authorization        → proves this came from our router (not from the internet)
    //   - X-SwarmSpace-User-Id → so the worker knows whose quota to check
    //   - X-SwarmSpace-User-Tier → so the worker knows what limits to apply
    const internalToken = SWARMSPACE_INTERNAL_TOKEN.value();
    const workerUrl = `${plugin.workerUrl}/invoke`;

    let workerResponse: Response;
    try {
      workerResponse = await fetch(workerUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${internalToken}`,
          "X-SwarmSpace-User-Id": userId,
          "X-SwarmSpace-User-Tier": userTier,
        },
        body: JSON.stringify(paramsForWorker),
        // 25 second timeout — Firebase functions time out at 60s,
        // this leaves headroom for our own error handling
        signal: AbortSignal.timeout(25_000),
      });
    } catch (err: any) {
      logger.error(`Worker fetch failed for plugin ${plugin_id}:`, err);
      writePluginActivityLog({
        user_id: userId,
        plugin_id,
        plugin_name: plugin.description,
        user_tier: userTier,
        privacy_required: privacyRequired,
        consent_given: consentGiven,
        data_fields_sent: dataFieldsSent,
        result: "error",
        error_message: err?.message ?? "Worker fetch failed",
      });
      throw new HttpsError(
        "unavailable",
        `Plugin ${plugin_id} is temporarily unavailable. Try again shortly.`
      );
    }

    // Step 6: Parse and return the worker's response.
    // We pass it through as-is — quota info, results, everything.
    let workerBody: unknown;
    try {
      workerBody = await workerResponse.json();
    } catch {
      throw new HttpsError("internal", `Plugin ${plugin_id} returned invalid response`);
    }

    // If the worker returned an error (e.g. quota exceeded), surface it cleanly.
    if (!workerResponse.ok) {
      const body = workerBody as Record<string, unknown>;
      const workerError = (body?.error as string) ?? "Plugin error";
      logger.warn(
        `Plugin ${plugin_id} returned ${workerResponse.status}: ${workerError}`
      );
      writePluginActivityLog({
        user_id: userId,
        plugin_id,
        plugin_name: plugin.description,
        user_tier: userTier,
        privacy_required: privacyRequired,
        consent_given: consentGiven,
        data_fields_sent: dataFieldsSent,
        result: "error",
        error_message: workerError,
      });
      // 429 = quota exceeded — this is expected, not a crash
      if (workerResponse.status === 429) {
        throw new HttpsError("resource-exhausted", workerError, {
          plugin_id,
          quota: body?.quota,
        });
      }
      // 403 = tier insufficient (shouldn't happen since we check above, but belt+suspenders)
      if (workerResponse.status === 403) {
        throw new HttpsError("permission-denied", workerError);
      }
      throw new HttpsError("internal", workerError);
    }

    logger.info(`SwarmSpace plugin ${plugin_id} success for user ${userId}`);
    writePluginActivityLog({
      user_id: userId,
      plugin_id,
      plugin_name: plugin.description,
      user_tier: userTier,
      privacy_required: privacyRequired,
      consent_given: consentGiven,
      data_fields_sent: dataFieldsSent,
      result: "success",
    });

    // Return the worker's response body to LUMARA
    return workerBody;
  }
);

// ── Plugin status endpoint ─────────────────────────────────────────────────────
// LUMARA calls this to check if a plugin is available for the current user.
// Lightweight — no quota consumed, no worker called.
export const swarmspacePluginStatus = onCall(
  {},
  async (request) => {
    const { isPremium, user } = await enforceAuth(request);
    const { plugin_id } = request.data ?? {};

    if (!plugin_id || typeof plugin_id !== "string") {
      throw new HttpsError("invalid-argument", "plugin_id is required");
    }

    const plugin = PLUGIN_REGISTRY[plugin_id];
    if (!plugin) {
      return { available: false, reason: "unknown_plugin" };
    }

    const userTier = resolveSwarmSpaceTier(user.plan ?? "free", isPremium);
    const available = canAccessPlugin(userTier, plugin.requiredTier);

    return {
      available,
      plugin_id,
      user_tier: userTier,
      required_tier: plugin.requiredTier,
      reason: available ? null : "tier_insufficient",
      upgrade_url: available ? null : "https://swarmspace.ai/upgrade",
    };
  }
);

// ── Plugin catalog endpoint ────────────────────────────────────────────────────
// Returns full catalog with metadata + availability for the current user.
// Used by the SwarmSpace catalog UI and by the orchestrator for capability routing.
export const swarmspacePluginCatalog = onCall(
  {},
  async (request) => {
    const { isPremium, user } = await enforceAuth(request);
    const userTier = resolveSwarmSpaceTier(user.plan ?? "free", isPremium);

    const plugins = Object.entries(PLUGIN_REGISTRY).map(([pluginId, config]) => ({
      plugin_id: pluginId,
      worker_url: config.workerUrl,
      required_tier: config.requiredTier,
      capabilities: config.capabilities,
      description: config.description,
      example_query: config.exampleQuery,
      available: canAccessPlugin(userTier, config.requiredTier),
      cost_tier: config.costTier ?? config.requiredTier,
      privacy_data_required: config.privacy_data_required === true,
    }));

    return {
      user_tier: userTier,
      plugins,
      upgrade_url: "https://swarmspace.ai/upgrade",
    };
  }
);